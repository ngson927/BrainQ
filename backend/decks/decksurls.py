from django.urls import path
from .views import *

urlpatterns = [

    # ----------------------
    # Decks
    # ----------------------
    path('decks/', DeckListView.as_view(), name='deck-list'),
    path('decks/archived/', ArchivedDeckListView.as_view(), name='deck-archived-list'),
    path('decks/create/', CreateDeckView.as_view(), name='deck-create'),
    path('decks/<int:pk>/', DeckDetailView.as_view(), name='deck-detail'),
    path('decks/<int:pk>/edit/', EditDeckView.as_view(), name='deck-edit'),
    path('decks/<int:pk>/delete/', DeleteDeckView.as_view(), name='deck-delete'),
    path('decks/<int:pk>/archive/', ToggleArchiveDeckView.as_view(), name='deck-toggle-archive'),
    path('decks/<int:deck_id>/customize-theme/', CustomizeDeckThemeView.as_view(), name='deck-customize-theme'),
    path('themes/available/', AvailableThemesView.as_view(), name='available-themes'),

    # ----------------------
    # Flashcards
    # ----------------------
    path('decks/<int:deck_id>/flashcards/', FlashcardListView.as_view(), name='flashcard-list'),
    path('flashcards/create/', CreateFlashcardView.as_view(), name='flashcard-create'),
    path('flashcards/<int:pk>/delete/', DeleteFlashcardView.as_view(), name='flashcard-delete'),
    
    # ----------------------
    # Deck Sharing
    # ----------------------
    path('decks/<int:pk>/share/', ShareDeckView.as_view(), name='deck-share'),
    path('decks/<int:pk>/share/revoke/', RevokeDeckShareView.as_view(), name='deck-share-revoke'),
    path('decks/<int:pk>/share/toggle_link/', ToggleDeckLinkView.as_view(), name='deck-share-toggle-link'),
    path('decks/<int:pk>/share/list/', DeckSharesListView.as_view(), name='deck-share-list'),

    # ----------------------
    # Feedback
    # ----------------------
    path('feedback/add/<int:deck_id>/', AddFeedbackView.as_view(), name='add-feedback'),
    path('feedback/<int:pk>/', FeedbackDetailView.as_view(), name='feedback-detail'),
    path('feedback/user/<int:deck_id>/', UserDeckFeedbackView.as_view(), name='user-deck-feedback'),
    path('feedback/list/<int:deck_id>/', DeckFeedbackListView.as_view(), name='deck-feedback-list'),



    # ----------------------
    # Search
    # ----------------------
    path('search/', SearchView.as_view(), name='search'),



    # ----------------------
    # Quiz Sessions
    # ----------------------
    path('quiz/start/<int:deck_id>/', StartQuizSessionView.as_view(), name='quiz-start'),
    path('quiz/answer/<int:session_id>/', QuizSessionAnswerView.as_view(), name='quiz-answer'),
    path('quiz/pause/<int:session_id>/', PauseQuizSessionView.as_view(), name='quiz-pause'),
    path('quiz/resume/<int:session_id>/', ResumeQuizSessionView.as_view(), name='quiz-resume'),
    path('quiz/skip/<int:session_id>/', SkipQuizFlashcardView.as_view(), name='quiz-skip'),
    path('quiz/change_mode/<int:session_id>/', ChangeQuizModeView.as_view(), name='quiz-change-mode'),
    path('quiz/finish/<int:session_id>/', FinishQuizSessionView.as_view(), name='quiz-finish'),
    path('quiz/results/<int:session_id>/', QuizSessionResultsView.as_view(), name='quiz-results'),
]
