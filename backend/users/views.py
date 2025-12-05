import hashlib
import secrets
import logging
from django.shortcuts import render
from rest_framework import generics, permissions, status
from django.contrib.auth import get_user_model, authenticate
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import TokenAuthentication
from .views_admin import audit_security
from users.serializers import RegisterSerializer
from .permissions import IsAdmin
from .models import CustomUser, PasswordResetToken
from django.utils import timezone
from django.conf import settings
from django.core.mail import send_mail
from datetime import timedelta
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.cache import cache


# ==========================
# LOGGERS
# ==========================
logger = logging.getLogger(__name__)
security_logger = logging.getLogger("security")

# ==========================
# ADMIN-ONLY VIEW
# ==========================
class AdminOnlyView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsAdmin]

    def get(self, request):
        users = CustomUser.objects.all().values(
            'id', 'username', 'email', 'first_name', 'last_name', 'role', 'is_suspended'
        )
        logger.info(f"Admin '{request.user.username}' accessed the AdminOnlyView.")
        return Response({"users": list(users)}, status=status.HTTP_200_OK)


# ==========================
# USER REGISTRATION
# ==========================
User = get_user_model()

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def perform_create(self, serializer):
        serializer.save(role='user')
        logger.info(f"New user registered: '{serializer.instance.username}'")


# ==========================
# LOGIN VIEW
# ==========================
class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        username_or_email = request.data.get('username')
        password = request.data.get('password')
        device_timezone = request.data.get("timezone")

        if not username_or_email or not password:
            return Response(
                {"error": "Username/email and password are required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Identify user by email or username
        try:
            if '@' in username_or_email:
                user_obj = CustomUser.objects.get(email=username_or_email)
            else:
                user_obj = CustomUser.objects.get(username=username_or_email)
        except CustomUser.DoesNotExist:
            user_obj = None

        # BLOCK SUSPENDED + INACTIVE USERS
        if user_obj:
            if user_obj.is_suspended:
                security_logger.warning(
                    f"🚨 Suspended user '{user_obj.username}' tried to log in."
                )
                return Response(
                    {"error": "Your account has been suspended. Please contact support."},
                    status=status.HTTP_403_FORBIDDEN
                )

            if not user_obj.is_active:
                security_logger.warning(
                    f"Inactive user '{user_obj.username}' tried to log in."
                )
                return Response(
                    {"error": "Your account is inactive."},
                    status=status.HTTP_403_FORBIDDEN
                )

        # Authenticate
        user = authenticate(
            username=user_obj.username if user_obj else username_or_email,
            password=password
        )

        if user:

            # Extra protection in case user was suspended AFTER identification
            if getattr(user, "is_suspended", False):
                return Response(
                    {"error": "Your account has been suspended."},
                    status=status.HTTP_403_FORBIDDEN
                )

            if device_timezone:
                user.timezone = device_timezone
                user.save(update_fields=["timezone"])

            Token.objects.filter(user=user).delete()

            token = Token.objects.create(user=user)

            logger.info(f"User '{user.username}' logged in successfully.")
            audit_security(request, "login_success", {"user": user.username})

            return Response({
                'token': token.key,
                'user_id': user.id,
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'role': user.role,
                'timezone': user.timezone,
                'is_suspended': user.is_suspended,
                'is_active': user.is_active,
            })

        # Invalid credentials
        security_logger.warning(
            f"Failed login attempt for '{username_or_email}'"
        )
        audit_security(request, "login_failed", {"attempt": username_or_email})
        return Response({"error": "Invalid credentials"}, status=status.HTTP_400_BAD_REQUEST)



# ==========================
# LOGOUT VIEW
# ==========================
class LogoutView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            if hasattr(request.user, 'auth_token'):
                request.user.auth_token.delete()
            logger.info(f"User '{request.user.username}' logged out.")
            return Response({"message": "Logged out successfully"}, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"Logout error: {str(e)}")
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)


# ==========================
# UPDATE TIMEZONE
# ==========================
class UpdateTimezoneView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        new_timezone = request.data.get("timezone")

        if not new_timezone:
            return Response({"error": "timezone is required"}, status=400)

        request.user.timezone = new_timezone
        request.user.save(update_fields=["timezone"])

        logger.info(f"User '{request.user.username}' changed timezone to {new_timezone}")

        return Response({"message": "Timezone updated", "timezone": new_timezone})


# ==========================
# PASSWORD RESET REQUEST
# ==========================
class RequestPasswordResetView(APIView):
    permission_classes = []

    def post(self, request):
        email = request.data.get("email")
        if not email:
            return Response({"error": "Email is required"}, status=400)

        try:
            user = CustomUser.objects.get(email=email)
        except CustomUser.DoesNotExist:
            logger.info(f"Password reset requested for non-existing email {email}")
            return Response({"message": "If the email exists, a reset email was sent."})

        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        expires_at = timezone.now() + timedelta(minutes=15)

        PasswordResetToken.objects.filter(user=user, used_at__isnull=True).update(used_at=timezone.now())
        PasswordResetToken.objects.create(user=user, token_hash=token_hash, expires_at=expires_at)

        reset_link = f"http://127.0.0.1:8000/reset-password-confirm/?token={raw_token}"

        send_mail(
            subject="Password Reset Request",
            message=f"Click to reset your password (expires in 15 mins): {reset_link}",
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False
        )

        logger.info(f"Password reset email sent to {user.email}")
        return Response({"message": "Reset link sent", "token": raw_token})


# ==========================
# PASSWORD RESET CONFIRM
# ==========================
class ConfirmPasswordResetView(APIView):
    permission_classes = []

    def post(self, request):
        token = request.data.get("token")
        new_password = request.data.get("new_password")

        if not token or not new_password:
            return Response({"error": "Token and new password are required"}, status=400)

        token_hash = hashlib.sha256(token.encode()).hexdigest()

        try:
            reset_token = PasswordResetToken.objects.get(token_hash=token_hash)
        except PasswordResetToken.DoesNotExist:
            return Response({"error": "Invalid token"}, status=400)

        if not reset_token.is_valid():
            return Response({"error": "Token expired or used"}, status=400)

        user = reset_token.user

        # Django password strength validation
        try:
            validate_password(new_password, user=user)
        except ValidationError as e:
            return Response({"error": list(e.messages)}, status=400)

        # Set hashed password
        user.set_password(new_password)
        user.save()

        # Invalidate ALL tokens → force relogin on all devices
        Token.objects.filter(user=user).delete()

        reset_token.used_at = timezone.now()
        reset_token.save()

        logger.warning(f"Password reset for {user.username}")
        audit_security(request, "password_reset", {"user_id": user.id})

        return Response({"message": "Password reset successfully. Please log in again."})


# ==========================
# UPDATE PROFILE
# ==========================
class UpdateProfileView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    RATE_LIMIT_KEY = "pwd_attempts_user_{id}"
    MAX_ATTEMPTS = 5
    BLOCK_TIME = 15 * 60 

    def patch(self, request):
        user = request.user
        data = request.data

        allowed_fields = ["username", "email", "first_name", "last_name"]
        update_data = {k: v for k, v in data.items() if k in allowed_fields}

        # ========= DUPLICATE CHECKS =========
        if "username" in update_data:
            if CustomUser.objects.filter(username=update_data["username"]).exclude(id=user.id).exists():
                return Response({"error": "Username already in use"}, status=400)

        if "email" in update_data:
            if CustomUser.objects.filter(email=update_data["email"]).exclude(id=user.id).exists():
                return Response({"error": "Email already in use"}, status=400)

        # ========= PASSWORD CHANGE =========
        current_password = data.get("current_password")
        new_password = data.get("new_password")
        confirm_password = data.get("confirm_password")

        cache_key = self.RATE_LIMIT_KEY.format(id=user.id)
        attempts = cache.get(cache_key, 0)

        if attempts >= self.MAX_ATTEMPTS:
            return Response(
                {"error": "Too many password change attempts. Try again later."},
                status=429
            )

        password_changed = False

        if any([current_password, new_password, confirm_password]):

            if not all([current_password, new_password, confirm_password]):
                return Response(
                    {"error": "To change password, provide current_password, new_password, and confirm_password"},
                    status=400
                )

            if not user.check_password(current_password):
                cache.set(cache_key, attempts + 1, timeout=self.BLOCK_TIME)
                audit_security(request, "password_change_failed", {"reason": "wrong_current_password"})
                return Response({"error": "Current password is incorrect"}, status=403)

            if new_password != confirm_password:
                cache.set(cache_key, attempts + 1, timeout=self.BLOCK_TIME)
                return Response({"error": "New passwords do not match"}, status=400)

            # PASSWORD STRENGTH VALIDATION (Django built-in)
            try:
                validate_password(new_password, user=user)
            except ValidationError as e:
                return Response({"error": list(e.messages)}, status=400)

            # HASH & SAVE
            user.set_password(new_password)
            password_changed = True

            # Reset attempt counter on success
            cache.delete(cache_key)

            logger.warning(f"User '{user.username}' changed their password")
            audit_security(request, "password_changed", {"user_id": user.id})

        # ========= UPDATE OTHER FIELDS =========
        for field, value in update_data.items():
            setattr(user, field, value)

        if update_data or password_changed:
            user.save()

        if not update_data and not password_changed:
            return Response({"error": "No valid fields provided"}, status=400)

        logger.info(f"User '{user.username}' updated profile fields: {list(update_data.keys())}")

        # AUTO LOGOUT ON PASSWORD CHANGE
        if password_changed:
            from rest_framework.authtoken.models import Token
            Token.objects.filter(user=user).delete()

            return Response(
                {"message": "Password changed successfully. Please log in again."},
                status=200
            )

        audit_security(request, "update_profile", {
            "fields": list(update_data.keys()),
            "password_changed": password_changed
        })

        return Response({
            "message": "Profile updated successfully",
            "user": {
                "username": user.username,
                "email": user.email,
                "first_name": user.first_name,
                "last_name": user.last_name,
            }
        }, status=200)


# ==========================
# DELETE  ACCOUNT
# ==========================
class DeleteAccountView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        password = request.data.get("password")

        if not password:
            return Response(
                {"error": "Password is required to delete your account"},
                status=400
            )

        if not user.check_password(password):
            audit_security(request, "delete_account_failed", {"reason": "wrong_password"})
            return Response({"error": "Incorrect password"}, status=403)

        # =========================
        # Admin safety checks
        # =========================
        if user.role == "admin":
            # Count remaining active admins
            active_admins = CustomUser.objects.filter(role="admin", is_active=True).exclude(id=user.id).count()
            if active_admins == 0:
                return Response(
                    {"error": "You cannot delete your account. At least one admin must remain."},
                    status=403
                )

        username = user.username
        user_id = user.id

        # Delete auth token first
        Token.objects.filter(user=user).delete()

        # HARD DELETE
        user.delete()

        logger.warning(f"User '{username}' HARD DELETED their account")
        audit_security(request, "account_deleted", {"user_id": user_id, "username": username})

        return Response({"message": "Your account has been permanently deleted"}, status=200)
