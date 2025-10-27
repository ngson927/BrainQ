from django.urls import path
from .views import (
    CreateDeckView,
    DeleteFlashcardView,
    EditDeckView,
    DeckDetailView,
    DeckListView,
    CreateFlashcardView,
    FlashcardListView,
    SearchView,
    StartQuizSessionView,
    QuizSessionAnswerView,
    PauseQuizSessionView,
    ResumeQuizSessionView,
    SkipQuizFlashcardView,
    ChangeQuizModeView,
    FinishQuizSessionView,
    QuizSessionResultsView

)

urlpatterns = [
    # ----- Deck endpoints -----
    path('decks/create/', CreateDeckView.as_view(), name='deck-create'),
    path('decks/<int:pk>/edit/', EditDeckView.as_view(), name='deck-edit'),
    path('flashcards/<int:pk>/delete/', DeleteFlashcardView.as_view(), name='flashcard-delete'),

    path('decks/<int:pk>/', DeckDetailView.as_view(), name='deck-detail'),
    path('decks/list/', DeckListView.as_view(), name='deck-list'),

    # ----- Flashcard endpoints -----
    path('flashcards/create/', CreateFlashcardView.as_view(), name='flashcard-create'),
    path('flashcards/list/<int:deck_id>/', FlashcardListView.as_view(), name='flashcard-list'),
    path('search/', SearchView.as_view(), name='search')


    # ----- Quiz session endpoints -----
    ,path('quiz/start/<int:deck_id>/', StartQuizSessionView.as_view(), name='quiz-start')
    ,path('quiz/answer/<int:session_id>/', QuizSessionAnswerView.as_view(), name='quiz-answer')
    ,path('quiz/pause/<int:session_id>/', PauseQuizSessionView.as_view(), name='quiz-pause')
    ,path('quiz/resume/<int:session_id>/', ResumeQuizSessionView.as_view(), name='quiz-resume')
    ,path('quiz/skip/<int:session_id>/', SkipQuizFlashcardView.as_view(), name='quiz-skip')
    ,path('quiz/change_mode/<int:session_id>/', ChangeQuizModeView.as_view(), name='quiz-change-mode')
    ,path('quiz/finish/<int:session_id>/', FinishQuizSessionView.as_view(), name='quiz-finish')
    ,path('quiz/results/<int:session_id>/', QuizSessionResultsView.as_view(), name='quiz-results')

]