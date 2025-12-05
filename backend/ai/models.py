from django.db import models
from django.utils import timezone
from users.models import CustomUser
from decks.models import Deck

class AIJob(models.Model):
    INPUT_TYPES = [
        ('prompt', 'Prompt Text'),
        ('file', 'Uploaded File'),
        ('image', 'Image Upload'),
        ('scan', 'Document Scan'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('success', 'Success'),
        ('error', 'Error'),
    ]

    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='ai_jobs')
    deck = models.ForeignKey(Deck, on_delete=models.SET_NULL, null=True, blank=True, related_name='ai_jobs')

    input_type = models.CharField(max_length=20, choices=INPUT_TYPES)
    input_summary = models.TextField(blank=True, null=True)
    prompt_text = models.TextField(blank=True, null=True)

    uploaded_file = models.FileField(upload_to='ai_inputs/files/', null=True, blank=True)
    uploaded_image = models.ImageField(upload_to='ai_inputs/images/', null=True, blank=True)

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')

    result_data = models.JSONField(blank=True, null=True)
    is_public = models.BooleanField(default=False)

    result_count = models.PositiveIntegerField(default=0)
    requested_count = models.PositiveIntegerField(null=True, blank=True)

    api_cost = models.DecimalField(max_digits=10, decimal_places=4, null=True, blank=True)
    generation_time_ms = models.PositiveIntegerField(null=True, blank=True)
    error_message = models.TextField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    finished_at = models.DateTimeField(null=True, blank=True)

    # -----------------------
    # Job State Helpers
    # -----------------------
    def mark_processing(self):
        self.status = 'processing'
        self.save(update_fields=['status'])

    def mark_success(self, result_data, cost=None, gen_time=None):
        self.status = 'success'
        self.result_data = result_data
        self.result_count = len(result_data.get('flashcards', [])) if isinstance(result_data, dict) else 0
        self.api_cost = cost
        self.generation_time_ms = gen_time
        self.finished_at = timezone.now()
        self.save()

    def mark_error(self, message):
        self.status = 'error'
        self.error_message = message
        self.finished_at = timezone.now()
        self.save()

    def __str__(self):
        return f"AIJob({self.id}) - {self.user.username} - {self.status}"

    class Meta:
        db_table = 'ai_job'
        ordering = ['-created_at']



class AIAssistantSession(models.Model):
    """
    Represents a conversational session between a user and the AI study assistant.
    Can be tied to a deck or general (no deck).
    """
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name="ai_assistant_sessions")
    deck = models.ForeignKey(Deck, on_delete=models.SET_NULL, null=True, blank=True, related_name="ai_assistant_sessions")

    title = models.CharField(max_length=255, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    ended_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"AI Session ({self.user.username}) - {self.title or 'General'}"


class AIAssistantMessage(models.Model):
    """
    Messages (both user + AI) in a chat session.
    """
    ROLE_CHOICES = (("user", "User"), ("assistant", "Assistant"))

    session = models.ForeignKey(AIAssistantSession, related_name="messages", on_delete=models.CASCADE)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"[{self.role}] {self.content[:40]}"
