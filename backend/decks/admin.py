from django.contrib import admin
from .models import Deck, QuizSession, QuizSessionFlashcard

@admin.register(Deck)
class DeckAdmin(admin.ModelAdmin):
    list_display = ('title', 'owner', 'is_public', 'created_at', 'updated_at')
    search_fields = ('title', 'owner__username')
    list_filter = ('is_public', 'created_at')


@admin.register(QuizSession)
class QuizSessionAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'deck', 'mode', 'started_at', 'finished_at', 'is_paused', 'correct_count', 'total_answered')
    list_filter = ('mode', 'is_paused', 'started_at', 'finished_at')
    search_fields = ('user__username', 'deck__title')


@admin.register(QuizSessionFlashcard)
class QuizSessionFlashcardAdmin(admin.ModelAdmin):
    list_display = ('id', 'session', 'flashcard', 'answered', 'correct', 'answered_at')
    list_filter = ('answered', 'correct', 'answered_at')
