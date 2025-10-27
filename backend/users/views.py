import hashlib
import secrets
from django.shortcuts import render
from rest_framework import generics, permissions, status
from django.contrib.auth import get_user_model, authenticate
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import TokenAuthentication
from users.serializers import RegisterSerializer
from .permissions import IsAdmin
from .models import CustomUser


class AdminOnlyView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsAdmin]

    def get(self, request):
        users = CustomUser.objects.all().values(
            'id', 'username', 'email', 'first_name', 'last_name', 'role', 'is_suspended'
        )
        return Response({"users": list(users)}, status=status.HTTP_200_OK)

User = get_user_model()  # This gets your CustomUser model

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def perform_create(self, serializer):
        # Force the role to 'user' for all new registrations
        serializer.save(role='user')


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        username_or_email = request.data.get('username')  # field stays the same
        password = request.data.get('password')

        if not username_or_email or not password:
            return Response(
                {"error": "Username/email and password are required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Try authenticating with username first
        user = authenticate(username=username_or_email, password=password)

        if not user:
            # If username auth fails, try email
            try:
                user_obj = CustomUser.objects.get(email=username_or_email)
                user = authenticate(username=user_obj.username, password=password)
            except CustomUser.DoesNotExist:
                user = None

        if user:
            token, _ = Token.objects.get_or_create(user=user)
            return Response({
                'token': token.key,
                'user_id': user.id,
                'username': user.username,
                'email': user.email,  # ✅ include email here
                'role': user.role
            })

        return Response({"error": "Invalid Credentials"}, status=status.HTTP_400_BAD_REQUEST)



class LogoutView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            # Try to delete the user's token if it exists
            if hasattr(request.user, 'auth_token'):
                request.user.auth_token.delete()
            return Response({"message": "Logged out successfully"}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)




from django.utils import timezone
from django.conf import settings
from django.core.mail import send_mail
from datetime import timedelta
from .models import PasswordResetToken


class RequestPasswordResetView(APIView):
    permission_classes = []  # Allow any user to request

    def post(self, request):
        email = request.data.get("email")
        if not email:
            return Response({"error": "Email is required"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = CustomUser.objects.get(email=email)
        except CustomUser.DoesNotExist:
            # Avoid exposing which emails exist
            return Response({"message": "If the email exists, a reset link has been sent."}, status=status.HTTP_200_OK)

        # Generate secure token
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        expires_at = timezone.now() + timedelta(minutes=15)  # 15 min expiry

        # Invalidate previous tokens
        PasswordResetToken.objects.filter(user=user, used_at__isnull=True).update(used_at=timezone.now())

        # Save new token
        PasswordResetToken.objects.create(user=user, token_hash=token_hash, expires_at=expires_at)

        # Create a reset link (for testing, we’ll return it in the response)
        reset_link = f"http://127.0.0.1:8000/reset-password-confirm/?token={raw_token}"

        # Optional: still send email (prints to console if using console backend)
        send_mail(
            subject="Password Reset Request",
            message=f"Click the link to reset your password (expires in 15 minutes): {reset_link}",
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False
        )

        # Return token & link directly for testing
        return Response({
            "message": "Password reset token created successfully",
            "reset_link": reset_link,
            "token": raw_token  # <-- use this directly in Postman to reset password
        }, status=status.HTTP_200_OK)


class ConfirmPasswordResetView(APIView):
    permission_classes = []  # Allow anyone with a valid token

    def post(self, request):
        token = request.data.get("token")
        new_password = request.data.get("new_password")
        if not token or not new_password:
            return Response({"error": "Token and new password are required"}, status=status.HTTP_400_BAD_REQUEST)

        token_hash = hashlib.sha256(token.encode()).hexdigest()
        try:
            reset_token = PasswordResetToken.objects.get(token_hash=token_hash)
        except PasswordResetToken.DoesNotExist:
            return Response({"error": "Invalid token"}, status=status.HTTP_400_BAD_REQUEST)

        if not reset_token.is_valid():
            return Response({"error": "Token expired or already used"}, status=status.HTTP_400_BAD_REQUEST)

        # Reset password
        user = reset_token.user
        user.set_password(new_password)
        user.save()

        # Mark token as used
        reset_token.used_at = timezone.now()
        reset_token.save()

        return Response({"message": "Password has been reset successfully"}, status=status.HTTP_200_OK)
