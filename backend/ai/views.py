from django.utils import timezone
from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from django.shortcuts import get_object_or_404
from django.db import transaction
from rest_framework.exceptions import PermissionDenied

from .models import AIJob, AIAssistantSession
from .serializers import (
    AIJobListSerializer,
    AIJobSerializer,
    AIAssistantSessionSerializer,
    AIAssistantMessageSerializer,
)
from .ai_service import AIGenerationService
from .ai_assistant_service import AIAssistantService



class GenerateDeckAIView(APIView):
    """
    POST /ai/generate/
    Allows user to create a deck via AI:
    - text prompt
    - uploaded file
    - uploaded image
    """
    parser_classes = [MultiPartParser, FormParser]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        input_type = request.data.get("input_type")
        prompt_text = request.data.get("prompt_text")
        input_summary = request.data.get("input_summary", "")
        uploaded_file = request.FILES.get("file")
        uploaded_image = request.FILES.get("image")
        is_public = request.data.get("is_public", "true").lower() == "true"

        # --- Validation ---
        if input_type not in ["prompt", "file", "image"]:
            return Response({"detail": "Invalid input_type"}, status=400)

        if input_type == "prompt" and not prompt_text:
            return Response({"detail": "Missing prompt_text"}, status=400)

        if input_type == "file" and not uploaded_file:
            return Response({"detail": "Missing file upload"}, status=400)

        if input_type == "image" and not uploaded_image:
            return Response({"detail": "Missing image upload"}, status=400)

        try:
            with transaction.atomic():
                # Create AIJob with proper file/image handling
                ai_job = AIJob.objects.create(
                    user=request.user,
                    input_type=input_type,
                    input_summary=input_summary or (prompt_text[:120] if prompt_text else ""),
                    prompt_text=prompt_text if input_type == "prompt" else None,
                    uploaded_file=uploaded_file if input_type == "file" else None,
                    uploaded_image=uploaded_image if input_type == "image" else None,
                    is_public=is_public,
                )

                # Mark job as processing
                ai_job.mark_processing()

                # Run the generation service (synchronous for now)
                deck = AIGenerationService.generate_deck(ai_job)

                # Mark as success
                ai_job.mark_success(result_data={"deck_id": deck.id})

                return Response(
                    {
                        "detail": "Deck generated successfully.",
                        "deck_id": deck.id,
                        "ai_job": AIJobSerializer(ai_job).data,
                    },
                    status=status.HTTP_201_CREATED,
                )

        except Exception as e:
            ai_job.mark_error(str(e))
            return Response(
                {"detail": f"AI generation failed: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class AIJobListView(APIView):
    """
    GET /ai/jobs/
    List all AI jobs for current user
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        jobs = AIJob.objects.filter(user=request.user).order_by('-created_at')
        serializer = AIJobListSerializer(jobs, many=True)
        return Response(serializer.data, status=200)

class AIJobDetailView(APIView):
    """
    GET /ai/jobs/<id>/
    View details for a single AI job
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        job = get_object_or_404(AIJob, pk=pk, user=request.user)
        serializer = AIJobSerializer(job)
        return Response(serializer.data)

# =========================
# AI Assistant Views
# =========================
class AIAssistantStartSessionView(APIView):
    """
    POST /api/ai/assistant/start/
    Starts a new session. Enforces deck ownership for private decks.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        deck_id = request.data.get("deck_id")
        title = request.data.get("title")
        deck = None

        if deck_id:
            from decks.models import Deck
            deck = get_object_or_404(Deck, pk=deck_id)

            # Check ownership or public flag
            if deck.owner != request.user and not getattr(deck, "is_public", False):
                raise PermissionDenied("You do not have access to this deck.")

        session = AIAssistantService.start_session(user=request.user, deck=deck, title=title)
        serializer = AIAssistantSessionSerializer(session)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class AIAssistantSendMessageView(APIView):
    """
    POST /api/ai/assistant/<session_id>/message/
    Sends a user message and returns assistant reply.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        # Ensure user owns this session
        session = get_object_or_404(AIAssistantSession, pk=session_id)
        if session.user != request.user:
            raise PermissionDenied("You cannot send messages to this session.")

        user_message = request.data.get("message")
        if not user_message:
            return Response({"detail": "Message cannot be empty."}, status=400)

        result = AIAssistantService.handle_query(session=session, user_message=user_message)
        return Response(result, status=status.HTTP_200_OK)


class AIAssistantSessionListView(APIView):
    """
    GET /api/ai/assistant/sessions/
    Lists all sessions belonging to the current user.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        sessions = AIAssistantSession.objects.filter(user=request.user).order_by('-created_at')
        serializer = AIAssistantSessionSerializer(sessions, many=True)
        return Response(serializer.data, status=200)


class AIAssistantEndSessionView(APIView):
    """
    POST /api/ai/assistant/<session_id>/end/
    Ends a session. Only the owner can end it.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(AIAssistantSession, pk=session_id)
        if session.user != request.user:
            raise PermissionDenied("You cannot end this session.")

        session = AIAssistantService.end_session(session)
        serializer = AIAssistantSessionSerializer(session)
        return Response(serializer.data, status=status.HTTP_200_OK)