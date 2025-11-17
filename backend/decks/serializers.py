from rest_framework import serializers
from .models import Flashcard, Deck, Feedback
from django.contrib.auth import get_user_model

User = get_user_model()

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
# Deck Serializer (WITH SHARING FEATURE FIX)
# -------------------------
class DeckSerializer(serializers.ModelSerializer):
    owner = serializers.ReadOnlyField(source='owner.username')
    flashcards = FlashcardSerializer(many=True, read_only=True)
    feedbacks = FeedbackSerializer(many=True, read_only=True)
    average_rating = serializers.SerializerMethodField()

    # Fixed: shared_with field
    shared_with = serializers.SlugRelatedField(
        many=True,
        slug_field='username',
        queryset=User.objects.none()  # <-- must not be None
    )

    class Meta:
        model = Deck
        fields = [
            'id', 'owner', 'title', 'description', 'is_public',
            'theme', 'color', 'font_size', 'card_order', 'text_color',
            'shared_with',
            'created_at', 'updated_at', 
            'flashcards', 'feedbacks', 'average_rating'
        ]
        read_only_fields = ['id', 'owner', 'created_at', 'updated_at']

    # Dynamically provide queryset
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['shared_with'].queryset = User.objects.all()

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

    # PREVENT NON-OWNERS FROM MODIFYING shared_with
    def validate(self, data):
        request = self.context.get("request")
        deck = self.instance  

        # Only owner can change shared_with
        if deck and "shared_with" in data:
            if request.user != deck.owner:
                raise serializers.ValidationError(
                    {"shared_with": "Only the deck owner can modify shared users."}
                )
        return data

    def get_average_rating(self, obj):
        feedbacks = obj.feedbacks.all()
        if feedbacks.exists():
            avg = sum(f.rating for f in feedbacks) / feedbacks.count()
            return round(avg, 2)
        return None
