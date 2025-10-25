from rest_framework import serializers
from .models import Flashcard
from .models import Deck

class FlashcardSerializer(serializers.ModelSerializer):
    class Meta:
        model = Flashcard
        fields = ['id', 'deck', 'question', 'answer', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def validate_question(self, value):
        if not value.strip():
            raise serializers.ValidationError("Question must not be empty.")
        return value

    def validate_answer(self, value):
        if not value.strip():
            raise serializers.ValidationError("Answer must not be empty.")
        return value



class DeckSerializer(serializers.ModelSerializer):
    owner = serializers.ReadOnlyField(source='owner.username')
    flashcards = FlashcardSerializer(many=True, read_only=True)  # show flashcards with deck

    class Meta:
        model = Deck
        fields = [
            'id', 'owner', 'title', 'description', 'is_public',
            'created_at', 'updated_at', 'flashcards'
        ]
        read_only_fields = ['id', 'owner', 'created_at', 'updated_at']

    def validate_title(self, value):
        if not value.strip():
            raise serializers.ValidationError("Title must not be empty.")
        return value

