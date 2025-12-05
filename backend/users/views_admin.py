import logging
from django.utils import timezone
from django.db.models import Count, Avg, Q, F, ExpressionWrapper, FloatField
from rest_framework import generics, status
from django.utils.dateparse import parse_date, parse_datetime
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import TokenAuthentication
from datetime import timedelta
from rest_framework.authtoken.models import Token


from decks.models import Deck, QuizSession
from users.models import CustomUser, SecurityLog
from users.permissions import IsAdmin
from .serializers_admin import (
    AdminUserSummarySerializer,
    AdminUserDetailSerializer,
    AdminDeckSummarySerializer,
    AdminDeckDetailSerializer
)

logger = logging.getLogger(__name__)
security_logger = logging.getLogger("security")


def audit_security(request, action, details=None, user=None):
    """Create a SecurityLog record (non-blocking)."""
    try:
        ip = request.META.get("REMOTE_ADDR") or request.META.get("HTTP_X_FORWARDED_FOR")
        SecurityLog.objects.create(
            user=user or (request.user if getattr(request, "user", None) and request.user.is_authenticated else None),
            action=action,
            ip_address=ip,
            details=details or {}
        )
    except Exception:
        security_logger.exception("Failed to write SecurityLog for action=%s", action)

# ==============================
# USER MANAGEMENT
# ==============================
class AdminUserListView(generics.ListAPIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsAdmin]
    serializer_class = AdminUserSummarySerializer

    def get_queryset(self):
        # EXCLUDE CURRENT ADMIN FROM LIST
        queryset = CustomUser.objects.exclude(
            id=self.request.user.id
        ).order_by('-date_joined')

        role = self.request.query_params.get('role')
        status_filter = self.request.query_params.get('status')
        search = self.request.query_params.get('search')
        joined_after = self.request.query_params.get('joined_after')
        joined_before = self.request.query_params.get('joined_before')

        # FILTER BY ROLE
        if role:
            queryset = queryset.filter(role=role)

        # FILTER BY STATUS
        if status_filter == "active":
            queryset = queryset.filter(is_active=True, is_suspended=False)
        elif status_filter == "suspended":
            queryset = queryset.filter(is_suspended=True)

        # SEARCH FILTER
        if search:
            queryset = queryset.filter(
                Q(username__icontains=search) |
                Q(email__icontains=search) |
                Q(first_name__icontains=search) |
                Q(last_name__icontains=search)
            )

        # DATE FILTERS (safe)
        if joined_after:
            date = parse_date(joined_after) or parse_datetime(joined_after)
            if date:
                queryset = queryset.filter(date_joined__gte=date)

        if joined_before:
            date = parse_date(joined_before) or parse_datetime(joined_before)
            if date:
                queryset = queryset.filter(date_joined__lte=date)

        logger.info(
            "Admin %s accessed user list",
            self.request.user.username
        )

        return queryset

class AdminUserDetailView(generics.RetrieveUpdateDestroyAPIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsAdmin]
    queryset = CustomUser.objects.all()
    serializer_class = AdminUserDetailSerializer

    # Block self actions
    def _is_self(self, request, user):
        return request.user.id == user.id

    def patch(self, request, *args, **kwargs):
        user = self.get_object()

        # PREVENT ADMIN FROM MODIFYING THEMSELVES
        if self._is_self(request, user):
            return Response(
                {"error": "You cannot modify your own account from the admin panel."},
                status=status.HTTP_403_FORBIDDEN
            )

        suspend = request.data.get("suspend")
        activate = request.data.get("activate")
        new_role = request.data.get("role")

        # SUSPEND USER
        if suspend:
            user.is_suspended = True
            user.is_active = False

            # DELETE ALL TOKENS (force logout everywhere)
            Token.objects.filter(user=user).delete()

            logger.info(
                "Admin %s suspended user %s",
                request.user.username, user.username
            )
            audit_security(request, "suspend_user", {"target_user": user.username})

        # ACTIVATE USER
        elif activate:
            user.is_suspended = False
            user.is_active = True

            logger.info(
                "Admin %s reactivated user %s",
                request.user.username, user.username
            )
            audit_security(request, "activate_user", {"target_user": user.username})

        # CHANGE ROLE
        if new_role:
            if request.user.role == "admin":
                if user.role != new_role:
                    old_role = user.role
                    user.role = new_role

                    logger.info(
                        "Admin %s changed %s role %s -> %s",
                        request.user.username,
                        user.username,
                        old_role,
                        new_role
                    )

                    audit_security(request, "change_role", {
                        "target_user": user.username,
                        "from": old_role,
                        "to": new_role
                    })
            else:
                return Response(
                    {"error": "Only admins can change user roles."},
                    status=status.HTTP_403_FORBIDDEN
                )

        user.save()
        return Response({
            "message": f"User '{user.username}' updated successfully."
        }, status=status.HTTP_200_OK)

    def delete(self, request, *args, **kwargs):
        user = self.get_object()

        # PREVENT ADMIN FROM DELETING THEMSELVES
        if self._is_self(request, user):
            return Response(
                {"error": "You cannot delete your own account from the admin panel."},
                status=status.HTTP_403_FORBIDDEN
            )

        username = user.username

        # DELETE TOKENS FIRST
        Token.objects.filter(user=user).delete()

        user.delete()

        logger.info(
            "Admin %s deleted user %s",
            request.user.username,
            username
        )

        audit_security(request, "delete_user", {"target_user": username})

        return Response(
            {"message": f"User '{username}' deleted successfully."},
            status=status.HTTP_204_NO_CONTENT
        )


class AdminBulkUserActionView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsAdmin]

    def post(self, request):
        user_ids = request.data.get("user_ids", [])
        action = request.data.get("action")

        if not user_ids or not action:
            return Response(
                {"error": "Missing user_ids or action"},
                status=status.HTTP_400_BAD_REQUEST
            )

        # REMOVE CURRENT ADMIN FROM TARGET LIST
        filtered_ids = [uid for uid in user_ids if str(uid) != str(request.user.id)]

        if not filtered_ids:
            return Response(
                {"error": "You cannot perform bulk actions on yourself."},
                status=status.HTTP_403_FORBIDDEN
            )

        users = CustomUser.objects.filter(id__in=filtered_ids)
        count = users.count()

        if count == 0:
            return Response(
                {"error": "No valid users found for this action."},
                status=status.HTTP_404_NOT_FOUND
            )

        # SUSPEND USERS
        if action == "suspend":
            users.update(is_suspended=True, is_active=False)

            # Delete tokens to force logout
            Token.objects.filter(user__in=users).delete()

        # ACTIVATE USERS
        elif action == "activate":
            users.update(is_suspended=False, is_active=True)

        # DELETE USERS
        elif action == "delete":
            Token.objects.filter(user__in=users).delete()
            users.delete()

        else:
            return Response(
                {"error": "Invalid action"},
                status=status.HTTP_400_BAD_REQUEST
            )

        logger.info(
            "Admin %s bulk %s %d users (self excluded)",
            request.user.username,
            action,
            count
        )

        audit_security(request, "bulk_user_action", {
            "admin": request.user.username,
            "action": action,
            "count": count
        })

        return Response(
            {"message": f"Bulk '{action}' applied to {count} users."},
            status=status.HTTP_200_OK
        )

# ==============================
# DASHBOARD / ANALYTICS
# ==============================
class AdminDashboardStatsView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsAdmin]

    def get_date_range(self, request):
        now = timezone.now()
        range_param = request.query_params.get("range")
        start = request.query_params.get("start")
        end = request.query_params.get("end")

        # Explicit start/end
        if start and end:
            try:
                start_dt = timezone.datetime.fromisoformat(start)
                end_dt = timezone.datetime.fromisoformat(end)
                return start_dt, end_dt
            except:
                pass

        # Numeric range in days
        if range_param:
            if range_param.isdigit():  # e.g., "5", "30", "60"
                days = int(range_param)
                return now - timedelta(days=days), now
            elif range_param == "7d":
                return now - timedelta(days=7), now
            elif range_param == "30d":
                return now - timedelta(days=30), now
            elif range_param == "this_month":
                start_dt = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
                return start_dt, now

        # Default last 7 days
        return now - timedelta(days=7), now

    def get(self, request):
        start_date, end_date = self.get_date_range(request)

        # Users within range
        total_users = CustomUser.objects.count()
        active_users = CustomUser.objects.filter(is_active=True).count()
        suspended_users = CustomUser.objects.filter(is_suspended=True).count()
        recent_users = CustomUser.objects.filter(
            date_joined__range=[start_date, end_date]
        ).order_by('-date_joined')[:5].values('username','email','date_joined')

        # Most active users (sessions in range)
        most_active_users = (
            QuizSession.objects.filter(started_at__range=[start_date, end_date])
            .values("user__username", "user__email")
            .annotate(session_count=Count("id"))
            .order_by("-session_count")[:5]
        )

        # Decks in range
        total_decks = Deck.objects.count()
        public_decks = Deck.objects.filter(is_public=True).count()
        private_decks = Deck.objects.filter(is_public=False).count()
        archived_decks = Deck.objects.filter(is_archived=True).count()
        flagged_decks = Deck.objects.filter(is_flagged=True).count()

        new_decks = Deck.objects.filter(created_at__range=[start_date, end_date]).count()
        average_decks_per_user = round(total_decks / max(1, CustomUser.objects.filter(is_active=True).count()), 2)

        top_creators = (
            Deck.objects.filter(created_at__range=[start_date, end_date])
            .values("owner__username")
            .annotate(deck_count=Count("id"))
            .order_by("-deck_count")[:5]
        )

        # Quiz analytics within range
        total_sessions = QuizSession.objects.filter(started_at__range=[start_date, end_date]).count()
        completed_sessions = QuizSession.objects.filter(finished_at__range=[start_date, end_date]).count()
        avg_accuracy = QuizSession.objects.filter(started_at__range=[start_date, end_date], total_answered__gt=0).aggregate(
            avg_accuracy=Avg(ExpressionWrapper(F("correct_count") * 100.0 / F("total_answered"), output_field=FloatField()))
        ).get("avg_accuracy") or 0.0

        popular_decks = (
            QuizSession.objects.filter(started_at__range=[start_date, end_date])
            .values("deck__id","deck__title","deck__owner__username")
            .annotate(usage_count=Count("id"))
            .order_by("-usage_count")[:5]
        )

        most_completed_decks = (
            QuizSession.objects.filter(finished_at__range=[start_date, end_date])
            .values("deck__id","deck__title","deck__owner__username")
            .annotate(completion_count=Count("id"))
            .order_by("-completion_count")[:5]
        )

        logger.info("Admin %s viewed dashboard stats", request.user.username)
        audit_security(request, "view_admin_dashboard", {"start": str(start_date), "end": str(end_date)})

        return Response({
            "date_range_used": {"start": start_date, "end": end_date, "query": request.query_params.dict()},
            "users": {"total": total_users, "active": active_users, "suspended": suspended_users, "recent": list(recent_users), "most_active": list(most_active_users)},
            "decks": {"total": total_decks, "public": public_decks, "private": private_decks, "archived": archived_decks, "flagged": flagged_decks, "new_in_range": new_decks, "average_per_user": average_decks_per_user, "top_creators": list(top_creators)},
            "quiz": {"total_sessions": total_sessions, "completed_sessions": completed_sessions, "avg_accuracy": round(avg_accuracy,2), "popular_decks": list(popular_decks), "most_completed_decks": list(most_completed_decks)},
            "server_time": timezone.now(),
        })
    
# ==============================
# DECK MANAGEMENT
# ==============================
class AdminDeckListView(generics.ListAPIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsAdmin]
    serializer_class = AdminDeckSummarySerializer

    def get_queryset(self):
        queryset = Deck.objects.all().order_by('-created_at')
        search = self.request.query_params.get('search')
        is_public = self.request.query_params.get('is_public')
        flagged = self.request.query_params.get('flagged')
        owner = self.request.query_params.get('owner')
        created_after = self.request.query_params.get('created_after')
        created_before = self.request.query_params.get('created_before')

        if search:
            queryset = queryset.filter(Q(title__icontains=search) | Q(description__icontains=search))
        if is_public is not None:
            queryset = queryset.filter(is_public=is_public.lower() in ['true','1'])
        if flagged is not None:
            queryset = queryset.filter(is_flagged=flagged.lower() in ['true','1'])
        if owner:
            queryset = queryset.filter(owner__username__icontains=owner)
        if created_after:
            queryset = queryset.filter(created_at__gte=created_after)
        if created_before:
            queryset = queryset.filter(created_at__lte=created_before)

        logger.info("Admin %s accessed deck list", self.request.user.username)
        return queryset


class AdminDeckDetailView(generics.RetrieveUpdateDestroyAPIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsAdmin]
    queryset = Deck.objects.all()
    serializer_class = AdminDeckDetailSerializer

    def patch(self, request, *args, **kwargs):
        deck = self.get_object()
        # Only moderation fields are editable
        for field in ['is_archived', 'is_flagged', 'flag_reason', 'admin_hidden', 'admin_note']:
            if field in request.data:
                setattr(deck, field, request.data[field] if field != 'admin_hidden' else bool(request.data[field]))

        deck.save()
        logger.info("Admin %s updated deck %s", request.user.username, deck.title)
        audit_security(request, "update_deck", {"deck_id": deck.id, "changes": request.data})
        return Response({"message": f"Deck '{deck.title}' updated successfully."})

    def delete(self, request, *args, **kwargs):
        deck = self.get_object()
        if not deck.is_public:
            return Response({"error": "Cannot delete private decks."}, status=status.HTTP_403_FORBIDDEN)

        title = deck.title
        deck.delete()
        logger.info("Admin %s deleted deck %s", request.user.username, title)
        audit_security(request, "delete_deck", {"deck_title": title})
        return Response({"message": f"Deck '{title}' deleted successfully."}, status=status.HTTP_204_NO_CONTENT)


class AdminBulkDeckActionView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsAdmin]

    def post(self, request):
        deck_ids = request.data.get("deck_ids", [])
        action = request.data.get("action")
        if not deck_ids or not action:
            return Response({"error": "Missing deck_ids or action"}, status=400)

        decks = Deck.objects.filter(id__in=deck_ids)
        count = 0

        if action in ["archive", "unarchive", "hide", "unhide"]:
            updates = {}
            if action == "archive":
                updates['is_archived'] = True
            elif action == "unarchive":
                updates['is_archived'] = False
            elif action == "hide":
                updates['admin_hidden'] = True
            elif action == "unhide":
                updates['admin_hidden'] = False
            count = decks.update(**updates)

        elif action == "delete":
            # Only delete public decks
            public_decks = decks.filter(is_public=True)
            count = public_decks.count()
            public_decks.delete()

        else:
            return Response({"error": "Invalid action"}, status=400)

        logger.info("Admin %s bulk %s %d decks", request.user.username, action, count)
        audit_security(request, "bulk_deck_action", {"action": action, "count": count})
        return Response({"message": f"Bulk '{action}' applied to {count} decks."})

