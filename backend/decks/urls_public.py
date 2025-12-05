from django.urls import path
from .views import DeckSharePageView

urlpatterns = [
    # Public-facing shared deck link
    path('share/<str:share_link>/', DeckSharePageView.as_view(), name='deck-share-link'),
]
