# Django imports
from django.shortcuts import render, get_object_or_404
from django.views import View
from django.db import IntegrityError, transaction
from django.db.models import Q, Case, When, Value, IntegerField
from django.utils import timezone
from django.http import HttpResponseServerError
import logging

# Python standard library
from random import sample, shuffle

# DRF core
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions, serializers
from rest_framework.permissions import IsAuthenticated, AllowAny, IsAuthenticatedOrReadOnly
from rest_framework.authentication import TokenAuthentication
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

from users.models import CustomUser


# App-specific
from .models import *
from .serializers import *
from .permissions import IsOwnerOrReadOnly
from achievements.models import Achievements
from notifications.signals import deck_shared, access_revoked, deck_rated, deck_commented, achievement_earned


import json


## -------------------------
# Create Deck
# -------------------------

class CreateDeckView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = request.data.copy()

        for field in ['flashcards', 'theme']:
            if field in data and isinstance(data[field], str):
                try:
                    data[field] = json.loads(data[field])
                except json.JSONDecodeError:
                    return Response({"detail": f"Invalid JSON for {field}"}, status=400)



        save_as_new_theme = data.pop('save_as_new_theme', False)
        theme_name = data.pop('theme_name', None)

        serializer = DeckSerializer(data=data, context={'request': request})
        if serializer.is_valid():
            try:
                with transaction.atomic():
        
                    deck = serializer.save(owner=request.user)

                    # Handle user-provided theme customizations
                    theme_data = data.get('theme')
                    if theme_data:
                        if save_as_new_theme or not deck.theme:
                            base_name = theme_name or f"{deck.title} Custom Theme"
                            counter = 1
                            unique_name = base_name
                            while DeckTheme.objects.filter(owner=request.user, name=unique_name).exists():
                                counter += 1
                                unique_name = f"{base_name} ({counter})"
                            theme = DeckTheme.objects.create(owner=request.user, name=unique_name)
                            deck.theme = theme
                            deck.save(update_fields=['theme'])
                        else:
                            theme = deck.theme

                        # Save theme customizations
                        theme_serializer = DeckThemeNestedSerializer(theme, data=theme_data, partial=True)
                        theme_serializer.is_valid(raise_exception=True)
                        theme_serializer.save()

                    # Create flashcards if provided
                    flashcards_data = data.get('flashcards', [])
                    for fc_data in flashcards_data:
                        Flashcard.objects.create(
                            deck=deck,
                            question=fc_data['question'],
                            answer=fc_data['answer'],
                            difficulty=fc_data.get('difficulty', 'medium')
                        )

                    # Achievements logic
                    achievements, _ = Achievements.objects.get_or_create(user=request.user)
                    created_decks_count = Deck.objects.filter(owner=request.user).count()
                    achievements.update_study(
                        created_first_deck=True,
                        study_date=timezone.localdate(),
                    )
                    achievements.check_badges(created_decks_count=created_decks_count)
                    achievements.save()

                return Response(DeckSerializer(deck, context={'request': request}).data, status=201)

            except IntegrityError:
                return Response({"detail": "Deck with that title already exists for this user."}, status=400)

        return Response(serializer.errors, status=400)


class EditDeckView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        deck = get_object_or_404(Deck, pk=pk)

        # Check permissions
        can_edit = deck.owner == request.user or DeckShare.objects.filter(
            deck=deck,
            user=request.user,
            permission='edit'
        ).exists()
        if not can_edit:
            return Response({"detail": "Cannot edit this deck."}, status=403)

        if deck.is_archived:
            return Response({"detail": "Cannot edit an archived deck."}, status=403)

        # Copy data to allow modifications
        data = request.data.copy()
        for field in ['flashcards', 'theme']:
            if field in data and isinstance(data[field], str):
                try:
                    data[field] = json.loads(data[field])
                except json.JSONDecodeError:
                    return Response({"detail": f"Invalid JSON for {field}"}, status=400)



        # Restrict non-owner fields
        allowed_fields_for_shared_users = ['title', 'description', 'tags', 'flashcards', 'cover_image', 'card_order']
        if deck.owner != request.user:
            data = {k: v for k, v in data.items() if k in allowed_fields_for_shared_users}

        # Handle cover_image removal
        if 'cover_image' in data and data['cover_image'] is None:
            deck.cover_image.delete(save=False)
            data.pop('cover_image')

        # Update deck via serializer
        deck_serializer = DeckSerializer(deck, data=data, context={'request': request}, partial=True)
        deck_serializer.is_valid(raise_exception=True)
        deck = deck_serializer.save()

        # Update flashcards if provided
        flashcards_data = data.get('flashcards', [])
        existing_ids = [fc.id for fc in deck.flashcards.all()]
        with transaction.atomic():
            for fc_data in flashcards_data:
                fc_id = fc_data.get('id')
                if fc_id and fc_id in existing_ids:
                    # Update existing flashcard
                    fc_instance = Flashcard.objects.get(id=fc_id, deck=deck)
                    fc_serializer = FlashcardSerializer(fc_instance, data=fc_data, partial=True, context={'request': request})
                    fc_serializer.is_valid(raise_exception=True)
                    fc_serializer.save()
                else:
                    # Create new flashcard
                    fc_serializer = FlashcardSerializer(data={**fc_data, "deck": deck.id}, context={'request': request})
                    fc_serializer.is_valid(raise_exception=True)
                    fc_serializer.save()

        return Response(DeckSerializer(deck, context={'request': request}).data, status=200)
# -------------------------
# Customize Deck Theme
# -------------------------
class CustomizeDeckThemeView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, deck_id):
        """
        GET request to prefill the current theme of the deck.
        """
        deck = get_object_or_404(Deck, pk=deck_id)

        if deck.owner != request.user:
            return Response(
                {"detail": "Only the deck owner can access the theme."},
                status=status.HTTP_403_FORBIDDEN
            )

        theme = deck.theme
        if not theme:
            return Response({"detail": "This deck has no theme yet."}, status=status.HTTP_404_NOT_FOUND)

        serializer = DeckThemeNestedSerializer(theme)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def patch(self, request, deck_id):
        """
        PATCH request to update or create a new deck theme.
        """
        deck = get_object_or_404(Deck, pk=deck_id)

        if deck.owner != request.user:
            return Response(
                {"detail": "Only the deck owner can customize the theme."},
                status=status.HTTP_403_FORBIDDEN
            )

        data = request.data.copy()

        save_as_new = data.pop('save_as_new', False)
        new_name = data.pop('name', None)
        reset_to_default = data.pop('reset_to_default', False)
        new_theme_id = data.pop('theme_id', None)

        # ===========================
        # 1. RESET TO SYSTEM DEFAULT
        # ===========================
        if reset_to_default:
            default_theme = DeckTheme.objects.filter(
                is_system_theme=True
            ).first()

            if not default_theme:
                return Response(
                    {"detail": "System default theme not found."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            deck.theme = default_theme
            deck.save(update_fields=['theme'])

            return Response(
                DeckThemeNestedSerializer(default_theme).data,
                status=status.HTTP_200_OK
            )

        # ===========================
        # 2. SWITCH TO EXISTING THEME
        # ===========================
        if new_theme_id:
            theme = get_object_or_404(DeckTheme, pk=new_theme_id)

            # Optional safety check: prevent using someone else's private theme
            if theme.owner and theme.owner != request.user:
                return Response(
                    {"detail": "You cannot assign a theme you do not own."},
                    status=status.HTTP_403_FORBIDDEN
                )

            deck.theme = theme
            deck.save(update_fields=['theme'])
            return Response(
                DeckThemeNestedSerializer(theme).data,
                status=status.HTTP_200_OK
            )

        # ===========================
        # 3. UPDATE / CREATE THEME
        # ===========================
        theme = deck.theme

        if save_as_new or not theme:
            base_name = new_name or f"{deck.title} Custom Theme"
            counter = 1
            unique_name = base_name

            while DeckTheme.objects.filter(owner=request.user, name=unique_name).exists():
                counter += 1
                unique_name = f"{base_name} ({counter})"

            theme = DeckTheme.objects.create(
                owner=request.user,
                name=unique_name
            )
            deck.theme = theme
            deck.save(update_fields=['theme'])

        elif new_name:
            theme.name = new_name
            theme.save(update_fields=['name'])

        serializer = DeckThemeNestedSerializer(theme, data=data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(serializer.data, status=status.HTTP_200_OK)
    
class AvailableThemesView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        themes = DeckTheme.objects.filter(
            Q(owner=request.user) | Q(owner__isnull=True)
        ).order_by('is_system_theme', 'name')

        serializer = DeckThemeNestedSerializer(themes, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)





# -------------------------
# Delete a Deck (and its flashcards)
# -------------------------
class DeleteDeckView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        deck = get_object_or_404(Deck, pk=pk)

        if deck.owner != request.user:
            return Response(
                {"detail": "Cannot delete a deck you don't own."},
                status=status.HTTP_403_FORBIDDEN
            )

        deck.delete()
        return Response(
            {"detail": "Deck and all associated flashcards deleted successfully."},
            status=status.HTTP_204_NO_CONTENT,
        )

class CreateFlashcardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = request.data

        # Check for required 'deck' and 'flashcards' keys
        deck_id = data.get("deck")
        flashcards_data = data.get("flashcards")

        if not deck_id or not flashcards_data:
            return Response(
                {"detail": "Both 'deck' and 'flashcards' fields are required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Ensure flashcards_data is a list
        if not isinstance(flashcards_data, list):
            return Response(
                {"detail": "'flashcards' must be a list of flashcards."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Get the deck object
        deck = get_object_or_404(Deck, pk=deck_id)

        # Check deck ownership
        if deck.owner != request.user:
            return Response(
                {"detail": f"Cannot add flashcards to a deck you don't own (deck {deck.id})."},
                status=status.HTTP_403_FORBIDDEN
            )

        # Prevent adding flashcards to archived decks
        if deck.is_archived:
            return Response(
                {"detail": "Cannot add flashcards to an archived deck."},
                status=status.HTTP_403_FORBIDDEN
            )

        created_flashcards = []

        # Wrap in a transaction so all-or-nothing
        with transaction.atomic():
            for fc_data in flashcards_data:
                serializer = FlashcardSerializer(data={**fc_data, "deck": deck.id})
                if serializer.is_valid():
                    flashcard = Flashcard.objects.create(
                        deck=deck,
                        question=serializer.validated_data['question'],
                        answer=serializer.validated_data['answer']
                    )
                    created_flashcards.append({
                        "id": flashcard.id,
                        "deck": deck.id,
                        "question": flashcard.question,
                        "answer": flashcard.answer
                    })
                else:
                    # Raise validation error and rollback all creations
                    raise serializers.ValidationError(serializer.errors)

        return Response({"flashcards": created_flashcards}, status=status.HTTP_201_CREATED)

# -------------------------
# Delete a Flashcard
# -------------------------
class DeleteFlashcardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        flashcard = get_object_or_404(Flashcard, pk=pk)

        user = request.user
        deck = flashcard.deck

        # Owner or shared user with "edit" permission can delete
        can_delete = deck.owner == user or DeckShare.objects.filter(
            deck=deck, user=user, permission='edit'
        ).exists()

        if not can_delete:
            return Response(
                {"detail": "You do not have permission to delete this flashcard."},
                status=status.HTTP_403_FORBIDDEN
            )

        flashcard.delete()
        return Response(
            {"detail": "Flashcard deleted successfully."},
            status=status.HTTP_204_NO_CONTENT
        )



    
class ToggleArchiveDeckView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsOwnerOrReadOnly]

    def post(self, request, pk):
        deck = get_object_or_404(Deck, pk=pk)

        if deck.owner != request.user:
            return Response(
                {"detail": "Cannot archive/unarchive a deck you don't own."},
                status=status.HTTP_403_FORBIDDEN
            )

        if not deck.is_archived:  # Archiving
            deck.was_public = deck.is_public  # store current public status
            deck.is_public = False  # hide from everyone
            deck.is_archived = True
        else:  # Unarchiving
            if deck.was_public is not None:
                deck.is_public = deck.was_public  # restore previous status
            deck.is_archived = False
            deck.was_public = None  # reset

        deck.save(update_fields=["is_archived", "is_public", "was_public", "updated_at"])
        action = "archived" if deck.is_archived else "unarchived"

        return Response(
            {
                "detail": f"Deck successfully {action}.",
                "is_archived": deck.is_archived,
                "is_public": deck.is_public
            },
            status=status.HTTP_200_OK
        )


# -------------------------
# View Deck Detail
# -------------------------
class DeckDetailView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.AllowAny]

    def get(self, request, pk):
        deck = get_object_or_404(Deck, pk=pk)
        user = request.user if request.user.is_authenticated else None

        # Owner or admin always has full access
        if user and (deck.owner == user or getattr(user, "is_admin", False)):
            serializer = DeckSerializer(deck, context={'request': request})
            return Response(serializer.data)

        # Hide deck if admin_hidden
        if deck.admin_hidden:
            return Response({"detail": "Not authorized"}, status=403)

        # Public decks that are not archived
        if deck.is_public and not deck.is_archived:
            serializer = DeckSerializer(deck, context={'request': request})
            return Response(serializer.data)

        # Shared users
        if user:
            share_entry = deck.shared_with.filter(user=user).first()
            if share_entry:
                serializer = DeckSerializer(deck, context={'request': request})
                return Response(serializer.data)

        # Link access
        share_link = request.query_params.get("share_link")
        if share_link and str(deck.share_link) == share_link:
            serializer = DeckSerializer(deck, context={'request': request})
            return Response(serializer.data)

        return Response({"detail": "Not authorized"}, status=403)



# -------------------------
# List Decks
# -------------------------
class DeckListView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        user = request.user if request.user.is_authenticated else None

        if user:
            decks = Deck.objects.filter(
                Q(owner=user) | 
                ((Q(is_public=True) | Q(shared_with__user=user)) & Q(admin_hidden=False)),
                is_archived=False
            ).select_related('owner').distinct()
        else:
            decks = Deck.objects.filter(
                is_public=True,
                is_archived=False,
                admin_hidden=False
            ).select_related('owner')

        serializer = DeckSerializer(decks, many=True, context={'request': request})
        return Response(serializer.data)


logger = logging.getLogger(__name__)


class DeckSharePageView(View):
    """
    Read-only view for shared decks via unique share_link.
    Displays deck details in read-only format.
    """

    def get(self, request, share_link):
        # Convert share_link to UUID safely
        try:
            share_uuid = uuid.UUID(share_link)
        except ValueError:
            logger.error(f"Invalid UUID format for share link: {share_link}")
            return render(request, "deck_share_denied.html", status=404)

        # Fetch deck
        deck = get_object_or_404(
            Deck.objects.prefetch_related("flashcards", "feedbacks"),
            share_link=share_uuid,
            is_archived=False
        )

        logger.info(
            f"Deck {deck.title}: is_public={deck.is_public}, is_link_shared={deck.is_link_shared}"
        )

        # ONLY allow access if link sharing is enabled
        if not deck.is_link_shared:
            logger.warning(
                f"Blocked disabled share link access attempt: {share_link} from {request.META.get('REMOTE_ADDR')}"
            )
            return render(request, "deck_share_denied.html", status=403)

        # Flashcards
        flashcards = deck.flashcards.all()

        # Tags
        tags = [t.strip() for t in deck.tags.split(',')] if deck.tags else []

        # Feedbacks and average rating
        feedbacks = deck.feedbacks.all()
        avg_rating = round(
            sum(f.rating for f in feedbacks) / feedbacks.count(), 2
        ) if feedbacks.exists() else None

        # Build full share URL
        share_url = request.build_absolute_uri(
            f"/decks/share/{deck.share_link}/"
        )

        context = {
            "deck": deck,
            "flashcards": flashcards,
            "tags": tags,
            "feedbacks": feedbacks,
            "avg_rating": avg_rating,
            "share_url": share_url,
            "app_download_url": "javascript:void(0);",
        }

        # Prevent browser cache from keeping disabled pages alive
        response = render(request, "deck_share.html", context)
        response["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        response["Pragma"] = "no-cache"
        response["Expires"] = "0"
        return response



    
class ShareDeckView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        deck = get_object_or_404(Deck, pk=pk)

        if deck.owner != request.user:
            return Response(
                {"detail": "Cannot share a deck you don't own."},
                status=status.HTTP_403_FORBIDDEN
            )

        recipients = request.data.get("recipients")
        if not recipients or not isinstance(recipients, list):
            return Response(
                {"detail": "Recipients must be a list of {username, permission} objects."},
                status=status.HTTP_400_BAD_REQUEST
            )

        created_shares = []
        errors = []

        with transaction.atomic():
            for r in recipients:
                username = r.get("username")
                permission = r.get("permission", "view")
                if permission not in ["view", "edit"]:
                    errors.append(f"Invalid permission for {username}.")
                    continue

                try:
                    user = CustomUser.objects.get(username=username)
                    share, created = DeckShare.objects.update_or_create(
                        deck=deck,
                        user=user,
                        defaults={"permission": permission}
                    )

                    # -----------------------------
                    # Trigger notification only for new shares
                    # -----------------------------
                    if created:
                        deck_shared.send(
                            sender=self.__class__,
                            recipient=user,          # who gets access
                            actor=request.user,      # who shared
                            deck=deck
                        )

                    created_shares.append({
                        "username": user.username,
                        "permission": share.permission
                    })
                except CustomUser.DoesNotExist:
                    errors.append(f"User {username} not found.")

        response = {"shared": created_shares}
        if errors:
            response["errors"] = errors

        return Response(response, status=status.HTTP_200_OK)


# -------------------------
# Revoke Shared Users
# -------------------------
class RevokeDeckShareView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        deck = get_object_or_404(Deck, pk=pk)

        if deck.owner != request.user:
            return Response(
                {"detail": "Cannot revoke sharing for a deck you don't own."},
                status=status.HTTP_403_FORBIDDEN
            )

        usernames = request.data.get("usernames")
        if not usernames or not isinstance(usernames, list):
            return Response(
                {"detail": "usernames must be a list of strings."},
                status=status.HTTP_400_BAD_REQUEST
            )

        revoked = []

        for username in usernames:
            try:
                user = CustomUser.objects.get(username=username)
                share_qs = DeckShare.objects.filter(deck=deck, user=user)
                if share_qs.exists():
                    share_qs.delete()
                    revoked.append(username)

                    # -----------------------------
                    # Trigger access_revoked notification
                    # -----------------------------
                    access_revoked.send(
                        sender=self.__class__,
                        recipient=user,       # user who lost access
                        actor=request.user,   # who revoked access
                        deck=deck
                    )
            except CustomUser.DoesNotExist:
                continue

        return Response({"revoked": revoked}, status=status.HTTP_200_OK)


# -------------------------
# Toggle Link Sharing (Minimal Response)
# -------------------------
class ToggleDeckLinkView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        deck = get_object_or_404(Deck, pk=pk)

        if deck.owner != request.user:
            return Response(
                {"detail": "Cannot modify link sharing for a deck you don't own."},
                status=status.HTTP_403_FORBIDDEN
            )

        action = request.data.get("action") 
        if action not in ["enable", "disable"]:
            return Response({"detail": "Invalid action. Must be 'enable' or 'disable'."},
                            status=status.HTTP_400_BAD_REQUEST)

        if action == "enable":
            deck.enable_link_sharing()
        else:
            deck.disable_link_sharing()

        minimal_data = {
            "id": deck.id,
            "title": deck.title,
            "owner": deck.owner.username,
            "is_public": deck.is_public,
            "is_link_shared": deck.is_link_shared,
            "share_link": str(deck.share_link) if deck.is_link_shared else None,
        }

        return Response(minimal_data, status=status.HTTP_200_OK)



# -------------------------
# List Users a Deck is Shared With
# -------------------------
class DeckSharesListView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        deck = get_object_or_404(Deck, pk=pk)

        if deck.owner != request.user:
            return Response(
                {"detail": "Cannot view shares for a deck you don't own."},
                status=status.HTTP_403_FORBIDDEN
            )

        shares = deck.shared_with.all()

        data = [
            {
                "username": s.user.username,
                "permission": s.permission,
                "shared_at": s.shared_at
            }
            for s in shares
        ]

        return Response({
            "is_link_shared": deck.is_link_shared,
            "share_link": str(deck.share_link) if deck.share_link else None,
            "shares": data
        }, status=status.HTTP_200_OK)


class FeedbackAccessMixin:
    """
    Access rules:
    - Deck must exist.
    - Owners can always view ratings.
    - Non-owners can only access public decks.
    """

    def get_deck(self, deck_id, user):
        deck = get_object_or_404(Deck, pk=deck_id)

        # Owner always allowed (for viewing)
        if deck.owner == user:
            return deck

        # Non-owner: must be public
        if not deck.is_public:
            return Response(
                {"detail": "Feedback is only available for public decks."},
                status=403
            )

        return deck

    def get_user_feedback(self, deck, user):
        return Feedback.objects.filter(deck=deck, user=user).first()



class AddFeedbackView(FeedbackAccessMixin, APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, deck_id):
        deck = self.get_deck(deck_id, request.user)
        if isinstance(deck, Response):
            return deck

        # Prevent rating your own deck
        if deck.owner == request.user:
            return Response(
                {"detail": "You cannot rate your own deck."},
                status=status.HTTP_403_FORBIDDEN
            )

        existing_feedback = self.get_user_feedback(deck, request.user)

        serializer = FeedbackSerializer(
            data={**request.data, "deck": deck.id}
        )
        serializer.is_valid(raise_exception=True)

        if existing_feedback:
            # Update existing feedback
            rating_before = existing_feedback.rating
            comment_before = existing_feedback.comment

            for field, value in serializer.validated_data.items():
                setattr(existing_feedback, field, value)
            existing_feedback.save()
            feedback = existing_feedback
            created = False

            # -----------------------------
            # Smart notifications for updates
            # -----------------------------
            # If the user added a comment for the first time
            if not comment_before and feedback.comment:
                deck_commented.send(
                    sender=self.__class__,
                    recipient=deck.owner,
                    actor=request.user,
                    deck=deck,
                    comment=feedback.comment
                )

        else:
            # Create new feedback entry
            feedback = serializer.save(user=request.user, deck=deck)
            created = True

            # -----------------------------
            # Smart notifications for new feedback
            # -----------------------------
            if feedback.comment:
                # User submitted both rating + comment → combine notification
                deck_rated.send(
                    sender=self.__class__,
                    recipient=deck.owner,
                    actor=request.user,
                    deck=deck,
                    rating=feedback.rating,
                    extra_data={"comment": feedback.comment}
                )
            else:
                # Rating only → notify rating
                deck_rated.send(
                    sender=self.__class__,
                    recipient=deck.owner,
                    actor=request.user,
                    deck=deck,
                    rating=feedback.rating
                )

        return Response(
            {
                "feedback": FeedbackSerializer(feedback).data,
                "deck": DeckSerializer(deck).data
            },
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
        )



class UserDeckFeedbackView(FeedbackAccessMixin, APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, deck_id):
        deck = self.get_deck(deck_id, request.user)
        if isinstance(deck, Response):
            return deck

        feedback = self.get_user_feedback(deck, request.user)
        if not feedback:
            return Response(status=204)

        return Response(FeedbackSerializer(feedback).data)


class FeedbackDetailView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        return get_object_or_404(Feedback, pk=pk, user=user)

    def patch(self, request, pk):
        feedback = self.get_object(pk, request.user)
        serializer = FeedbackSerializer(
            feedback, data=request.data, partial=True
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        deck = feedback.deck

        return Response(
            {"feedback": serializer.data, "deck": DeckSerializer(deck).data}
        )

    def delete(self, request, pk):
        feedback = self.get_object(pk, request.user)
        deck = feedback.deck
        feedback.delete()

        return Response(
            {"detail": "Feedback deleted.", "deck": DeckSerializer(deck).data},
            status=200
        )


class DeckFeedbackListView(APIView):
    """
    List all feedback for a deck.
    - Owner can always view.
    - Non-owners only if deck is public.
    """
    authentication_classes = [TokenAuthentication]
    permission_classes = [AllowAny]

    def get(self, request, deck_id):
        deck = get_object_or_404(Deck, pk=deck_id)

        # If NOT owner and deck is private
        if (not deck.is_public) and (
            not request.user.is_authenticated or request.user != deck.owner
        ):
            return Response(
                {"detail": "Feedback is only available for public decks."},
                status=403
            )

        feedbacks = (
            Feedback.objects
            .filter(deck=deck)
            .select_related("user")
            .order_by("-created_at")
        )

        return Response(FeedbackSerializer(feedbacks, many=True).data)

class ArchivedDeckListView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        decks = Deck.objects.filter(owner=user, is_archived=True).select_related('owner')
        serializer = DeckSerializer(decks, many=True)
        return Response(serializer.data)



# -------------------------
# List Flashcards for a Deck
# -------------------------

class FlashcardListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, deck_id):
        deck = get_object_or_404(Deck, pk=deck_id)
        user = request.user if request.user.is_authenticated else None

        # Admin or owner can see even if hidden
        if deck.admin_hidden and not (user and (deck.owner == user or getattr(user, "is_admin", False))):
            return Response({"detail": "Not authorized"}, status=403)

        if deck.is_public or (user and deck.owner == user) or (user and getattr(user, "is_admin", False)):

            flashcards = list(
                Flashcard.objects.filter(deck=deck).order_by('-created_at')
            )

            # Shuffle if requested
            shuffle_param = request.query_params.get("shuffle", "false").lower()
            if shuffle_param in ["true", "1", "yes", "on"]:
                shuffle(flashcards)

            serializer = FlashcardSerializer(flashcards, many=True)
            return Response(serializer.data)

        return Response(
            {"detail": "Not authorized to view flashcards for this deck."},
            status=403
        )



# ---------- Helpers ----------
def get_flashcard_options(flashcard, deck):
    all_answers = list(deck.flashcards.exclude(id=flashcard.id).values_list('answer', flat=True))
    if len(all_answers) < 3:
        distractors = (all_answers * 3)[:3]
    else:
        from random import sample
        distractors = sample(all_answers, 3)
    options = distractors + [flashcard.answer]
    from random import shuffle
    shuffle(options)
    return options


def get_next_flashcard_by_mode(session):
    """Fallback deterministic behavior for non-adaptive sessions."""
    if session.current_index < len(session.order):
        return session.order[session.current_index]
    return None






class StartQuizSessionView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, deck_id):
        deck = get_object_or_404(Deck, pk=deck_id)
        mode = request.data.get("mode", "sequential")
        adaptive_mode = bool(request.data.get("adaptive_mode", True))
        srs_enabled = bool(request.data.get("srs_enabled", True))
        time_per_card = request.data.get("time_per_card", None)

        if mode not in ["random", "sequential", "timed"]:
            return Response({"detail": "Invalid mode."}, status=400)

        if deck.owner != request.user and not deck.is_public:
            return Response({"detail": "Not authorized."}, status=403)

        session = QuizSession.objects.create(
            user=request.user,
            deck=deck,
            mode=mode,
            adaptive_mode=adaptive_mode,
            srs_enabled=srs_enabled,
            time_per_card=time_per_card if mode == "timed" else None,
        )

        # Pre-create performance entries for all flashcards
        for fc in deck.flashcards.all():
            FlashcardPerformance.objects.get_or_create(user=request.user, flashcard=fc)

        # ---------------- Adaptive first card selection ----------------
        if session.adaptive_mode:
            first_id = session.select_next_flashcard()
            if first_id:
                session.order = [first_id]
                session.current_index = 0
                session.save()
                QuizSessionFlashcard.objects.get_or_create(session=session, flashcard_id=first_id)
        else:
            # Non-adaptive → full order
            session.initialize_order()
            for fid in session.order:
                QuizSessionFlashcard.objects.get_or_create(session=session, flashcard_id=fid)

        # Return first flashcard data
        first_id = session.get_current_flashcard_id()
        if first_id:
            fc = Flashcard.objects.get(id=first_id)
            question = fc.question
            options = get_flashcard_options(fc, deck)
        else:
            question, options = None, []

        serializer = QuizSessionSerializer(session)
        return Response(
            {"session": serializer.data, "question": question, "options": options},
            status=201,
        )


# ============================================
# Answer Flashcard (Adaptive + SRS)
# ============================================

class QuizSessionAnswerView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)

        # 🔒 NEW: Block answering while paused
        if session.is_paused:
            return Response({"detail": "Session is paused. Resume before answering."}, status=400)

        if session.finished_at:
            return Response({"detail": "Session already finished."}, status=400)

        current_id = session.get_current_flashcard_id()
        if current_id is None:
            return Response({"detail": "No more flashcards."}, status=400)

        attempt, _ = QuizSessionFlashcard.objects.get_or_create(
            session=session,
            flashcard_id=current_id
        )
        flashcard = attempt.flashcard

        selected_answer = request.data.get("answer", "").strip()
        correct = bool(selected_answer == str(flashcard.answer))

        rt_raw = request.data.get("response_time")
        try:
            response_time = float(rt_raw) if rt_raw is not None else None
        except (ValueError, TypeError):
            response_time = None

        # Record attempt (adaptive/SRS)
        attempt.record_attempt(correct=correct, answer_text=selected_answer, response_time=response_time)

        session.total_answered += 1
        if correct:
            session.correct_count += 1
        session.increment_index()
        session.save()

        next_id = session.get_current_flashcard_id()
        if next_id:
            QuizSessionFlashcard.objects.get_or_create(session=session, flashcard_id=next_id)
            fc = Flashcard.objects.get(id=next_id)
            next_question = fc.question
            next_options = get_flashcard_options(fc, session.deck)
        else:
            from django.utils import timezone
            session.finished_at = timezone.now()
            session.save()
            next_question, next_options = None, []

        feedback = "Correct!" if correct else f"Incorrect. Correct answer: {flashcard.answer}"

        return Response({
            "correct": correct,
            "feedback": feedback,
            "accuracy": session.accuracy(),
            "next_question": next_question,
            "next_options": next_options,
            "time_per_card": session.time_per_card,
        })


class FinishQuizSessionView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)
        session.finished_at = timezone.now()
        session.save()

        # Update achievements
        achievements, _ = Achievements.objects.get_or_create(user=request.user)
        perfect_quiz = (session.total_answered > 0 and session.correct_count == session.total_answered)
        deck_id = getattr(session.deck, "id", None)

        # This should update streaks, badges, etc.
        achievements.update_study(
            study_date=timezone.localdate(),
            perfect_quiz=perfect_quiz,
            deck_id=deck_id
        )

        # -----------------------------
        # Trigger notifications for new achievements
        # -----------------------------
        new_badges = achievements.get_new_badges()
        for badge in new_badges:
            achievement_earned.send(
                sender=self.__class__,
                recipient=request.user,
                achievement=badge
            )

        # Return session summary
        return Response({
            "detail": "Session finished.",
            "streak": {
                "current_streak": achievements.current_streak,
                "best_streak": achievements.best_streak,
                "total_study_days": achievements.total_study_days,
                "consecutive_perfect_quizzes": achievements.consecutive_perfect_quizzes,
                "badges": achievements.badges
            }
        })


class QuizSessionResultsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

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
# Pause / Resume
# -------------------------
class PauseQuizSessionView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)
        session.is_paused = True
        session.save()
        return Response({'detail': 'Session paused.'})


class ResumeQuizSessionView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)
        session.is_paused = False
        session.save()

        # Return current flashcard
        flashcard_id = session.get_current_flashcard_id()
        question, options = None, []
        if flashcard_id:
            flashcard = Flashcard.objects.get(id=flashcard_id)
            question = flashcard.question
            options = get_flashcard_options(flashcard, session.deck)

        return Response({'detail': 'Session resumed.', 'question': question, 'options': options})


# -------------------------
# Skip flashcard
# -------------------------
class SkipQuizFlashcardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)

        if session.is_paused:
            return Response({'detail': 'Session is paused. Resume before skipping.'}, status=400)

        if session.finished_at:
            return Response({'detail': 'Session finished.'}, status=400)

        flashcard_id = session.get_current_flashcard_id()
        if not flashcard_id:
            return Response({'detail': 'No more flashcards.'}, status=400)

        # Dynamically create attempt if needed
        attempt, _ = QuizSessionFlashcard.objects.get_or_create(
            session=session,
            flashcard_id=flashcard_id
        )

        # Mark as skipped (no SRS update)
        attempt.answered = True
        attempt.correct = False
        attempt.answer_given = ''
        attempt.answered_at = timezone.now()
        attempt.save()

        session.total_answered += 1
        session.increment_index()

        next_flashcard_id = session.get_current_flashcard_id()
        if not next_flashcard_id:
            session.finished_at = timezone.now()
            session.save()
            return Response({
                'detail': 'Flashcard skipped.',
                'next_question': None,
                'next_options': []
            })

        next_flashcard = Flashcard.objects.get(id=next_flashcard_id)
        next_question = next_flashcard.question
        next_options = get_flashcard_options(next_flashcard, session.deck)

        return Response({
            'detail': 'Flashcard skipped.',
            'next_question': next_question,
            'next_options': next_options
        })




# -------------------------
# Change Quiz Mode
# -------------------------
class ChangeQuizModeView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        session = get_object_or_404(QuizSession, pk=session_id, user=request.user)
        new_mode = request.data.get('mode')
        if new_mode not in ['random', 'sequential', 'timed']:
            return Response({'detail': 'Invalid mode.'}, status=400)

        session.mode = new_mode
        session.initialize_order()
        session.save()

        # Return current flashcard
        flashcard_id = session.get_current_flashcard_id()
        question, options = None, []
        if flashcard_id:
            flashcard = Flashcard.objects.get(id=flashcard_id)
            question = flashcard.question
            options = get_flashcard_options(flashcard, session.deck)

        return Response({'detail': f'Mode changed to {new_mode}.', 'question': question, 'options': options})
    

class SearchView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get(self, request):
        query = request.query_params.get("q", "").strip()
        if not query:
            return Response({"detail": "Please provide a search term using ?q=keyword"}, status=400)

        query_lower = query.lower()
        user = request.user if request.user.is_authenticated else None

        decks = Deck.objects.filter(
            Q(title__icontains=query) |
            Q(description__icontains=query) |
            Q(tags__icontains=query_lower),
            is_archived=False
        )

        if user:
            # Owner sees all their decks, hidden or not
            decks = decks.filter(
                Q(owner=user) |
                ((Q(is_public=True)) & Q(admin_hidden=False))
            )
        else:
            # Non-authenticated users see only public & non-hidden decks
            decks = decks.filter(is_public=True, admin_hidden=False)

        flashcards = Flashcard.objects.filter(
            Q(question__icontains=query) | Q(answer__icontains=query),
            deck__is_archived=False
        )

        if user:
            flashcards = flashcards.filter(
                Q(deck__owner=user) | 
                (Q(deck__is_public=True) & Q(deck__admin_hidden=False))
            )
        else:
            flashcards = flashcards.filter(deck__is_public=True, deck__admin_hidden=False)

        # Serialize
        deck_data = DeckSerializer(decks, many=True).data
        flashcard_data = FlashcardSerializer(flashcards, many=True).data

        return Response({
            "query": query,
            "decks_found": deck_data,
            "flashcards_found": flashcard_data
        })
