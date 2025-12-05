from django.db.models.signals import post_save
from django.dispatch import receiver
from django.conf import settings
from .models import Achievements

@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_user_streak(sender, instance, created, **kwargs):
    """Automatically create a streak when a new user registers."""
    if created:
        Achievements.objects.get_or_create(user=instance)
