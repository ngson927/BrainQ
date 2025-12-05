from django.dispatch import Signal

deck_shared = Signal()
access_revoked = Signal()
deck_rated = Signal()
deck_commented = Signal()
ai_deck_ready = Signal()
achievement_earned = Signal()
