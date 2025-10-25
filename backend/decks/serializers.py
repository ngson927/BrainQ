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


# Quiz serializers
from .models import QuizSession, QuizSessionFlashcard

class QuizSessionFlashcardSerializer(serializers.ModelSerializer):
    class Meta:
        model = QuizSessionFlashcard
        fields = ['id', 'flashcard', 'answered', 'correct', 'answer_given', 'answered_at']


class QuizSessionSerializer(serializers.ModelSerializer):
    flashcard_attempts = QuizSessionFlashcardSerializer(many=True, read_only=True)
    accuracy = serializers.SerializerMethodField()

    class Meta:
        model = QuizSession
        fields = [
            'id', 'user', 'deck', 'mode', 'started_at', 'finished_at', 'is_paused',
            'correct_count', 'total_answered', 'current_index', 'order', 'flashcard_attempts', 'accuracy'
        ]
        read_only_fields = ['user', 'started_at', 'finished_at', 'correct_count', 'total_answered', 'current_index', 'order', 'flashcard_attempts', 'accuracy']

    def get_accuracy(self, obj):
        return obj.accuracy()

