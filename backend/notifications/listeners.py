
from django.dispatch import receiver
import logging

from .signals import (
    deck_shared,
    access_revoked,
    deck_rated,
    deck_commented,
    ai_deck_ready,
    achievement_earned,
)
from .utils import create_notification

logger = logging.getLogger(__name__)

def safe_create_notification(**kwargs):
    try:
        return create_notification(**kwargs)
    except Exception as e:
        logger.exception("Failed to create notification: %s", e)
        return None


@receiver(deck_shared)
def handle_deck_shared(sender, recipient, actor, deck, **kwargs):
    safe_create_notification(
        recipient=recipient,
        actor=actor,
        notif_type="deck_shared",
        verb=f"{actor.username} shared a deck with you",
        deck=deck,
        channels=("in_app", "push")
    )


@receiver(access_revoked)
def handle_access_revoked(sender, recipient, actor, deck, **kwargs):
    safe_create_notification(
        recipient=recipient,
        actor=actor,
        notif_type="access_revoked",
        verb=f"Your access to '{deck.title}' was revoked",
        deck=deck,
        channels=("in_app", "push")
    )


@receiver(deck_rated)
def handle_deck_rated(sender, recipient, actor, deck, rating, **kwargs):
    safe_create_notification(
        recipient=recipient,
        actor=actor,
        notif_type="deck_rated",
        verb=f"{actor.username} rated your deck '{deck.title}' ({rating}⭐)",
        deck=deck,
        channels=("in_app",)
    )


@receiver(deck_commented)
def handle_deck_commented(sender, recipient, actor, deck, comment, **kwargs):
    safe_create_notification(
        recipient=recipient,
        actor=actor,
        notif_type="deck_commented",
        verb=f"{actor.username} commented on '{deck.title}'",
        deck=deck,
        channels=("in_app",)
    )


@receiver(ai_deck_ready)
def handle_ai_deck_ready(sender, recipient, deck, **kwargs):
    logger.info(f"ai_deck_ready fired for user {recipient.id}, deck {deck.id}")
    safe_create_notification(
        recipient=recipient,
        notif_type="ai_deck_ready",
        verb=f"Your AI-generated deck '{deck.title}' is ready!",
        deck=deck,
        channels=("in_app", "push")
    )


@receiver(achievement_earned)
def handle_achievement_earned(sender, recipient, achievement, **kwargs):
    safe_create_notification(
        recipient=recipient,
        notif_type="achievement",
        verb=f"You earned a new achievement: {achievement.name} 🏆",
        channels=("in_app", "push"),
        extra_data={
            "achievement_id": str(achievement.id)
        }
    )
