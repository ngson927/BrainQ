from django.db import models
from django.conf import settings


class Deck(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="decks"
    )
    title = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    is_public = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("owner", "title")
        ordering = ["-updated_at"]

    def __str__(self):
        return f"{self.title} ({self.owner})"


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

