from django.urls import path
from .views import (
    CreateDeckView,
    EditDeckView,
    DeckDetailView,
    DeckListView,
    CreateFlashcardView,
    FlashcardListView,
    SearchView
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
    path('search/', SearchView.as_view(), name='search')


]
