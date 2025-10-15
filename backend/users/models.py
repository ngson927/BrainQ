from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin


class CustomUser(AbstractBaseUser, PermissionsMixin):
    id = models.BigAutoField(primary_key=True)
    username = models.CharField(max_length=50, unique=True)
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=255)
    role = models.CharField(max_length=10, default='user')
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)
    
    USERNAME_FIELD = 'username'
    REQUIRED_FIELDS = ['email']

    class Meta:
        db_table = 'users'



# users/models.py

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
