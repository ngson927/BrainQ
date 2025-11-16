from django.urls import path
from .views import (
    CreateDeckView,
    EditDeckView,
    DeckDetailView,
    DeckListView,
    CreateFlashcardView,
    FlashcardListView,
    AddFeedbackView,        # <-- POST feedback
    DeckFeedbackListView,   # <-- GET list of feedbacks
    ReminderListCreateView,
    ReminderDetailView
)

urlpatterns = [
    # ----- Deck endpoints -----
    path('decks/create/', CreateDeckView.as_view(), name='deck-create'),
    path('decks/<int:pk>/edit/', EditDeckView.as_view(), name='deck-edit'),
    path('decks/<int:pk>/', DeckDetailView.as_view(), name='deck-detail'),
    path('decks/list/', DeckListView.as_view(), name='deck-list'),

    # ----- Flashcard endpoints -----
    path('flashcards/create/', CreateFlashcardView.as_view(), name='flashcard-create'),
    path('flashcards/list/<int:deck_id>/', FlashcardListView.as_view(), name='flashcard-list'),

    # ----- Feedback endpoints -----
    # Create feedback for a deck
    path('decks/<int:deck_id>/feedback/', AddFeedbackView.as_view(), name='add-feedback'),
    # List feedback for a deck
    path('decks/<int:deck_id>/feedbacks/', DeckFeedbackListView.as_view(), name='deck-feedbacks'),

    # ----- Reminder endpoints -----
    path('reminders/', ReminderListCreateView.as_view(), name='reminder-list-create'),
    path('reminders/<int:pk>/', ReminderDetailView.as_view(), name='reminder-detail'),
]
