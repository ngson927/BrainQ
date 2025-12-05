from django.urls import path
from .views import StreakDetailView, UpdateStreakView, ResetStreakView, RecoverStreakView

urlpatterns = [
    path("", StreakDetailView.as_view(), name="streak-detail"),
    path("update/", UpdateStreakView.as_view(), name="streak-update"),
    path("reset/", ResetStreakView.as_view(), name="streak-reset"),
    path("recover/", RecoverStreakView.as_view(), name="streak-recover"),
]
