from django.db import models
from django.conf import settings
import random


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


# Quiz session models
class QuizSession(models.Model):
    MODE_CHOICES = [
        ("random", "Random"),
        ("sequential", "Sequential"),
    ]
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    deck = models.ForeignKey(Deck, on_delete=models.CASCADE)
    mode = models.CharField(max_length=20, choices=MODE_CHOICES)
    started_at = models.DateTimeField(auto_now_add=True)
    finished_at = models.DateTimeField(null=True, blank=True)
    is_paused = models.BooleanField(default=False)
    correct_count = models.PositiveIntegerField(default=0)
    total_answered = models.PositiveIntegerField(default=0)
    current_index = models.PositiveIntegerField(default=0)
    order = models.JSONField(default=list)  # List of flashcard IDs in quiz order

    def initialize_order(self):
        if self.mode == 'random':
            flashcards = list(self.deck.flashcards.values_list('id', flat=True))
            random.shuffle(flashcards)
        else:  # sequential and default
            flashcards = list(self.deck.flashcards.order_by('created_at').values_list('id', flat=True))
        self.order = flashcards
        self.current_index = 0
        self.save()

    def get_current_flashcard_id(self):
        if self.current_index < len(self.order):
            return self.order[self.current_index]
        return None

    def increment_index(self):
        self.current_index += 1
        if self.current_index >= len(self.order):
            self.current_index = 0  # Loop back to start
        self.save()

    def accuracy(self):
        if self.total_answered == 0:
            return 0.0
        return self.correct_count / self.total_answered

class QuizSessionFlashcard(models.Model):
    session = models.ForeignKey(QuizSession, on_delete=models.CASCADE, related_name='flashcard_attempts')
    flashcard = models.ForeignKey(Flashcard, on_delete=models.CASCADE)
    answered = models.BooleanField(default=False)
    correct = models.BooleanField(default=False)
    answer_given = models.TextField(blank=True)
    answered_at = models.DateTimeField(null=True, blank=True)

