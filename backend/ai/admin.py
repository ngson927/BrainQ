from django.contrib import admin
from .models import AIJob

@admin.register(AIJob)
class AIJobAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'input_type', 'status', 'created_at', 'finished_at')
    list_filter = ('status', 'input_type')
    search_fields = ('user__username', 'prompt_text')
