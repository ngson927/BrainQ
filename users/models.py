from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


class CustomUser(AbstractUser):
    ROLE_CHOICES = (
        ('user', 'User'),
        ('admin', 'Admin'),
    )
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='user')
    is_suspended = models.BooleanField(default=False)

    def __str__(self):
        return self.username



# users/models.py
from django.db import models
from django.contrib.auth import get_user_model
import secrets
import hashlib

User = get_user_model()

class PasswordResetToken(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    token_hash = models.CharField(max_length=64, unique=True)  # store SHA256 hash
    expires_at = models.DateTimeField()
    used_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def is_valid(self):
        """Check if token is still valid and unused."""
        return self.used_at is None and timezone.now() <= self.expires_at

    def __str__(self):
        return f"PasswordResetToken(user={self.user.username}, valid={self.is_valid()})"
