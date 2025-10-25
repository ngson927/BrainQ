from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.authentication import TokenAuthentication
from django.shortcuts import get_object_or_404
from django.db import IntegrityError, transaction
from django.db.models import Q
from .models import Deck, Flashcard
from .serializers import DeckSerializer, FlashcardSerializer
from .permissions import IsOwnerOrReadOnly

# -------------------------
# Create Deck
# -------------------------
class CreateDeckView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = DeckSerializer(data=request.data)
        if serializer.is_valid():
            try:
                with transaction.atomic():
                    serializer.save(owner=request.user)
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            except IntegrityError:
                return Response(
                    {"detail": "Deck with that title already exists for this user."},
                    status=status.HTTP_400_BAD_REQUEST
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# -------------------------
# Edit Deck
# -------------------------
class EditDeckView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsOwnerOrReadOnly]

    def patch(self, request, pk):
        deck = get_object_or_404(Deck, pk=pk)
        if deck.owner != request.user:
            return Response({"detail": "Cannot edit a deck you don't own."}, status=status.HTTP_403_FORBIDDEN)
        serializer = DeckSerializer(deck, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# -------------------------
# View Deck Detail
# -------------------------
class DeckDetailView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, pk):
        deck = get_object_or_404(Deck, pk=pk)
        if deck.is_public or (request.user.is_authenticated and deck.owner == request.user):
            serializer = DeckSerializer(deck)
            return Response(serializer.data)
        return Response({"detail": "Not authorized"}, status=status.HTTP_403_FORBIDDEN)


# -------------------------
# List Decks (user + public)
# -------------------------
class DeckListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        user = request.user if request.user.is_authenticated else None
        if user:
            decks = Deck.objects.filter(Q(owner=user) | Q(is_public=True)).select_related('owner')
        else:
            decks = Deck.objects.filter(is_public=True).select_related('owner')
        serializer = DeckSerializer(decks.distinct(), many=True)
        return Response(serializer.data)


# -------------------------
# Quiz Session API
# -------------------------
from .models import QuizSession, QuizSessionFlashcard
from .serializers import QuizSessionSerializer, QuizSessionFlashcardSerializer
from django.utils import timezone

class StartQuizSessionView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, deck_id):
        mode = request.data.get('mode')
        if mode not in ['random', 'sequential']:
            return Response({'detail': 'Invalid mode.'}, status=400)
        deck = get_object_or_404(Deck, pk=deck_id)
        if deck.owner != request.user and not deck.is_public:
            return Response({'detail': 'Not authorized.'}, status=403)
        session = QuizSession.objects.create(user=request.user, deck=deck, mode=mode)
        session.initialize_order()
        for fid in session.order:
            QuizSessionFlashcard.objects.create(session=session, flashcard_id=fid)
        serializer = QuizSessionSerializer(session)
        # Get the first flashcard's question
        question = None
        if session.order:
            first_flashcard = Flashcard.objects.get(id=session.order[0])
            question = first_flashcard.question
        return Response({
            'session': serializer.data,
            'question': question
        }, status=201)

class QuizSessionAnswerView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)
        if session.finished_at:
            return Response({'detail': 'Session already finished.'}, status=400)
        flashcard_id = session.get_current_flashcard_id()
        if flashcard_id is None:
            return Response({'detail': 'No more flashcards.'}, status=400)
        answer = request.data.get('answer', '').strip()
        attempt = get_object_or_404(QuizSessionFlashcard, session=session, flashcard_id=flashcard_id)
        # Always allow answering, even if previously answered
        correct = (answer.lower() == attempt.flashcard.answer.lower())
        attempt.answered = True
        attempt.correct = correct
        attempt.answer_given = answer
        attempt.answered_at = timezone.now()
        attempt.save()
        session.total_answered += 1
        if correct:
            session.correct_count += 1
        session.increment_index()
        session.save()
        feedback = 'Correct!' if correct else f'Incorrect. Correct answer: {attempt.flashcard.answer}'
        # Get the next flashcard's question
        next_question = None
        next_flashcard_id = session.get_current_flashcard_id()
        if next_flashcard_id is not None:
            next_flashcard = Flashcard.objects.get(id=next_flashcard_id)
            next_question = next_flashcard.question
        return Response({
            'correct': correct,
            'feedback': feedback,
            'accuracy': session.accuracy(),
            'next_question': next_question
        })

class PauseQuizSessionView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)
        session.is_paused = True
        session.save()
        return Response({'detail': 'Session paused.'})

class ResumeQuizSessionView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)
        session.is_paused = False
        session.save()
        # Return the current flashcard's question
        question = None
        flashcard_id = session.get_current_flashcard_id()
        if flashcard_id is not None:
            flashcard = Flashcard.objects.get(id=flashcard_id)
            question = flashcard.question
        return Response({'detail': 'Session resumed.', 'question': question})

class SkipQuizFlashcardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)
        if session.finished_at:
            return Response({'detail': 'Session finished.'}, status=400)
        flashcard_id = session.get_current_flashcard_id()
        if flashcard_id is None:
            return Response({'detail': 'No more flashcards.'}, status=400)
        attempt = get_object_or_404(QuizSessionFlashcard, session=session, flashcard_id=flashcard_id)
        # Always allow skipping, even if previously answered
        attempt.answered = True
        attempt.correct = False
        attempt.answer_given = ''
        attempt.answered_at = timezone.now()
        attempt.save()
        session.total_answered += 1
        session.increment_index()
        session.save()
        # Return the next flashcard's question
        next_question = None
        next_flashcard_id = session.get_current_flashcard_id()
        if next_flashcard_id is not None:
            next_flashcard = Flashcard.objects.get(id=next_flashcard_id)
            next_question = next_flashcard.question
        return Response({'detail': 'Flashcard skipped.', 'next_question': next_question})

class ChangeQuizModeView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)
        new_mode = request.data.get('mode')
        if new_mode not in ['random', 'sequential']:
            return Response({'detail': 'Invalid mode.'}, status=400)
        session.mode = new_mode
        session.initialize_order()
        session.save()
        # Return the current flashcard's question after mode change
        question = None
        flashcard_id = session.get_current_flashcard_id()
        if flashcard_id is not None:
            flashcard = Flashcard.objects.get(id=flashcard_id)
            question = flashcard.question
        return Response({'detail': f'Mode changed to {new_mode}.', 'question': question})

class FinishQuizSessionView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)
        session.finished_at = timezone.now()
        session.save()
        return Response({'detail': 'Session finished.'})

class QuizSessionResultsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)
        serializer = QuizSessionSerializer(session)
        return Response({
            'correct_count': session.correct_count,
            'total_answered': session.total_answered,
            'accuracy': session.accuracy(),
            'results': serializer.data
        })


# -------------------------
# Create a Flashcard
# -------------------------
class CreateFlashcardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = FlashcardSerializer(data=request.data)
        if serializer.is_valid():
            deck_id = serializer.validated_data['deck'].id
            # Explicitly use the Flashcard model to get the deck
            deck = get_object_or_404(Deck, pk=deck_id)
            
            if deck.owner != request.user:
                return Response(
                    {"detail": "Cannot add flashcards to a deck you don't own."},
                    status=status.HTTP_403_FORBIDDEN
                )
            
            # Explicitly save using the Flashcard model
            flashcard = Flashcard.objects.create(
                deck=deck,
                question=serializer.validated_data['question'],
                answer=serializer.validated_data['answer']
            )
            output_serializer = FlashcardSerializer(flashcard)
            return Response(output_serializer.data, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# -------------------------
# List Flashcards for a Deck
# -------------------------
class FlashcardListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, deck_id):
        # Explicitly use Flashcard model
        deck = get_object_or_404(Deck, pk=deck_id)
        
        if deck.is_public or (request.user.is_authenticated and deck.owner == request.user):
            flashcards = Flashcard.objects.filter(deck=deck).order_by('-updated_at')
            serializer = FlashcardSerializer(flashcards, many=True)
            return Response(serializer.data)
        
        return Response(
            {"detail": "Not authorized to view flashcards for this deck."},
            status=status.HTTP_403_FORBIDDEN
        )

# -------------------------
# Search Decks and Flashcards
# -------------------------
class SearchView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        query = request.query_params.get("q", "")
        if not query:
            return Response({"detail": "Please provide a search term using ?q=keyword"}, status=status.HTTP_400_BAD_REQUEST)

        # Search decks and flashcards (case-insensitive)
        decks = Deck.objects.filter(Q(title__icontains=query) | Q(description__icontains=query))
        flashcards = Flashcard.objects.filter(Q(question__icontains=query) | Q(answer__icontains=query))

        deck_data = DeckSerializer(decks, many=True).data
        flashcard_data = FlashcardSerializer(flashcards, many=True).data

        return Response({
            "query": query,
            "decks_found": deck_data,
            "flashcards_found": flashcard_data
        })
