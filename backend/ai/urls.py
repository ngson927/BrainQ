from django.urls import path
from .views import*


urlpatterns = [
    # ==== AI Deck Generation / Jobs ====
    path('generate/', GenerateDeckAIView.as_view(), name='ai-generate'),
    path('jobs/', AIJobListView.as_view(), name='ai-job-list'),
    path('jobs/<int:pk>/', AIJobDetailView.as_view(), name='ai-job-detail'),

    # ==== AI Assistant ====
    path('assistant/start/', AIAssistantStartSessionView.as_view(), name='ai-assistant-start'),
    path('assistant/<int:session_id>/message/', AIAssistantSendMessageView.as_view(), name='ai-assistant-message'),
    path('assistant/sessions/', AIAssistantSessionListView.as_view(), name='ai-assistant-sessions'),
    path('assistant/<int:session_id>/end/', AIAssistantEndSessionView.as_view(), name='ai-assistant-end'),
]
