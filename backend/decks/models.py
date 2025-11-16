from django.db import models
from django.conf import settings


# -------------------------
# Deck Model
# -------------------------
class Deck(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="decks"
    )
    title = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    is_public = models.BooleanField(default=False)

    # -------------------------
    # CUSTOMIZATION FIELDS
    # -------------------------
        # ---------------- Customization fields ----------------
    theme = models.CharField(max_length=50, blank=True, default="default")  # e.g., dark/light
    color = models.CharField(max_length=7, blank=True, default="#ffffff")    # hex color
    font_size = models.PositiveIntegerField(default=14)                      # px
    card_order = models.CharField(max_length=10, default="asc")              # asc/desc/random
    text_color = models.CharField(max_length=20, blank=True, null=True)  # e.g., "#000000"


    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("owner", "title")
        ordering = ["-updated_at"]

    def __str__(self):
        return f"{self.title} ({self.owner})"


# -------------------------
# Flashcard Model
# -------------------------
class Flashcard(models.Model):
    deck = models.ForeignKey(
        Deck,
        on_delete=models.CASCADE,
        related_name="flashcards"
    )
    question = models.TextField()
    answer = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]

    def __str__(self):
        return f"Flashcard for {self.deck.title}: {self.question[:50]}"


# -------------------------
# Feedback Model
# -------------------------
class Feedback(models.Model):
    deck = models.ForeignKey(
        Deck,
        on_delete=models.CASCADE,
        related_name='feedbacks'
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='feedbacks'
    )
    rating = models.IntegerField()
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('deck', 'user')
        ordering = ['-created_at']


# -------------------------
# Reminder Model
# -------------------------
class Reminder(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='reminders')
    message = models.CharField(max_length=255)
    remind_at = models.DateTimeField()
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Reminder for {self.user} at {self.remind_at}: {self.message}"

    def __str__(self):
        return f"{self.user.username} -> {self.deck.title} ({self.rating}★)"
