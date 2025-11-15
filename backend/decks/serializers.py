from rest_framework import serializers
from .models import Flashcard, Deck, Feedback  # <-- added Feedback


# -------------------------
# Flashcard Serializer
# -------------------------
class FlashcardSerializer(serializers.ModelSerializer):
    class Meta:
        model = Flashcard
        fields = ['id', 'deck', 'question', 'answer', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'user']
    
    def validate_question(self, value):
        if not value.strip():
            raise serializers.ValidationError("Question must not be empty.")
        return value

    def validate_answer(self, value):
        if not value.strip():
            raise serializers.ValidationError("Answer must not be empty.")
        return value


# -------------------------
# Feedback Serializer
# -------------------------
class FeedbackSerializer(serializers.ModelSerializer):
    user = serializers.StringRelatedField(read_only=True)

    class Meta:
        model = Feedback
        fields = ['id', 'deck', 'user', 'rating', 'comment', 'created_at']
        read_only_fields = ['id', 'user', 'created_at']

    def validate_rating(self, value):
        if not (1 <= value <= 5):
            raise serializers.ValidationError("Rating must be between 1 and 5.")
        return value


# -------------------------
# Deck Serializer (UPDATED WITH CUSTOMIZATION FIELDS)
# -------------------------
class DeckSerializer(serializers.ModelSerializer):
    owner = serializers.ReadOnlyField(source='owner.username')
    flashcards = FlashcardSerializer(many=True, read_only=True)
    feedbacks = FeedbackSerializer(many=True, read_only=True)
    average_rating = serializers.SerializerMethodField()

    class Meta:
        model = Deck
        fields = [
            'id', 'owner', 'title', 'description', 'is_public',
            'theme', 'color', 'font_size', 'card_order','text_color',  # <-- NEW FIELDS
            'created_at', 'updated_at', 
            'flashcards', 'feedbacks', 'average_rating'
        ]
        read_only_fields = ['id', 'owner', 'created_at', 'updated_at']

    # VALIDATIONS FOR CUSTOMIZATION
    def validate_font_size(self, value):
        if value < 10 or value > 40:
            raise serializers.ValidationError("Font size must be between 10 and 40.")
        return value

    def validate_card_order(self, value):
        allowed = ['asc', 'desc', 'random']
        if value not in allowed:
            raise serializers.ValidationError(f"Card order must be one of: {allowed}")
        return value

    def get_average_rating(self, obj):
        feedbacks = obj.feedbacks.all()
        if feedbacks.exists():
            avg = sum(f.rating for f in feedbacks) / feedbacks.count()
            return round(avg, 2)
        return None
