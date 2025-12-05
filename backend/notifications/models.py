from django.db import models
from django.conf import settings
from django.utils import timezone
from uuid import uuid4


class Notification(models.Model):

    NOTIF_TYPE_CHOICES = [
        ('deck_shared', 'Deck Shared With You'),
        ('access_revoked', 'Access Revoked'),
        ('deck_rated', 'Deck Rated'),
        ('deck_commented', 'Deck Commented'),
        ('ai_deck_ready', 'AI Deck Ready'),
        ('achievement', 'Badge/Achievement Earned'),
    ]

    DELIVERY_CHANNELS = [
        ('in_app', 'In App'),
        ('push', 'Push'),
        ('both', 'Both'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('sent', 'Sent'),
        ('failed', 'Failed'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid4, editable=False)

    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications'
    )

    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='notifications_sent'
    )

    notif_type = models.CharField(max_length=50, choices=NOTIF_TYPE_CHOICES)
    verb = models.CharField(max_length=255)

    deck = models.ForeignKey(
        'decks.Deck',
        null=True,
        blank=True,
        on_delete=models.CASCADE
    )

    delivery_channel = models.CharField(
        max_length=10,
        choices=DELIVERY_CHANNELS,
        default='in_app',
        db_index=True
    )

    push_status = models.CharField(
        max_length=10,
        choices=STATUS_CHOICES,
        default='pending'
    )

    is_read = models.BooleanField(default=False)

    extra_data = models.JSONField(blank=True, null=True)

    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['recipient', 'is_read']),
            models.Index(fields=['notif_type']),
        ]

    def __str__(self):
        return f"{self.notif_type} → {self.recipient}"
