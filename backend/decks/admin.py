from django.contrib import admin
from .models import Deck

@admin.register(Deck)
class DeckAdmin(admin.ModelAdmin):
    list_display = ('title', 'owner', 'is_public', 'created_at', 'updated_at')
    search_fields = ('title', 'owner__username')
    list_filter = ('is_public', 'created_at')
