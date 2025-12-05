from rest_framework import serializers
from .models import AIAssistantMessage, AIAssistantSession, AIJob
from decks.models import Deck
from decks.serializers import DeckSerializer, FlashcardNestedSerializer


# =========================
# Full AIJob Serializer
# =========================
class AIJobSerializer(serializers.ModelSerializer):
    deck = DeckSerializer(read_only=True)
    user = serializers.ReadOnlyField(source='user.username')
    uploaded_file_url = serializers.SerializerMethodField()
    uploaded_image_url = serializers.SerializerMethodField()
    is_public = serializers.BooleanField(required=False, default=False)

    def get_uploaded_file_url(self, obj):
        request = self.context.get('request')
        if obj.uploaded_file:
            return request.build_absolute_uri(obj.uploaded_file.url) if request else obj.uploaded_file.url
        return None

    def get_uploaded_image_url(self, obj):
        request = self.context.get('request')
        if obj.uploaded_image:
            return request.build_absolute_uri(obj.uploaded_image.url) if request else obj.uploaded_image.url
        return None

    class Meta:
        model = AIJob
        fields = [
            'id', 'user', 'deck',
            'input_type', 'input_summary', 'prompt_text',
            'uploaded_file_url', 'uploaded_image_url',
            'status', 'result_data', 'result_count',
            'api_cost', 'generation_time_ms', 'error_message',
            'is_public',     
            'created_at', 'finished_at'
        ]
        read_only_fields = fields



class AIJobListSerializer(serializers.ModelSerializer):
    deck_id = serializers.IntegerField(source='deck.id', read_only=True)
    deck_title = serializers.CharField(source='deck.title', read_only=True)
    user = serializers.ReadOnlyField(source='user.username')

    class Meta:
        model = AIJob
        fields = ['id', 'user', 'deck_id', 'deck_title', 'input_type', 'status', 'created_at', 'finished_at']
        read_only_fields = fields


# =========================
# Input Serializer for Deck Generation
# =========================
class AIDeckGenerationSerializer(serializers.Serializer):
    """
    Input serializer for AI-powered deck creation.
    The user provides either a text prompt, a file, or an image.
    """
    input_type = serializers.ChoiceField(choices=AIJob.INPUT_TYPES)
    prompt_text = serializers.CharField(required=False, allow_blank=True)
    file = serializers.FileField(required=False)
    image = serializers.ImageField(required=False)
    input_summary = serializers.CharField(required=False, allow_blank=True)
    is_public = serializers.BooleanField(required=False, default=False)

    def validate(self, data):
        input_type = data.get("input_type")
        prompt_text = data.get("prompt_text")
        file = data.get("file")
        image = data.get("image")

        if input_type == "prompt" and not prompt_text:
            raise serializers.ValidationError({"prompt_text": "Prompt text is required for this input type."})
        if input_type == "file" and not file:
            raise serializers.ValidationError({"file": "A file must be uploaded for this input type."})
        if input_type == "image" and not image:
            raise serializers.ValidationError({"image": "An image must be uploaded for this input type."})

        return data


# =========================
# Optional Deck Result Serializer
# =========================
class AIDeckResultSerializer(serializers.ModelSerializer):
    """Serializer to represent a generated deck with flashcards."""
    flashcards = FlashcardNestedSerializer(many=True, read_only=True)

    class Meta:
        model = Deck
        fields = ['id', 'title', 'description', 'tags', 'created_at', 'flashcards']


# =========================
# AI Assistant Serializers
# =========================

class AIAssistantMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = AIAssistantMessage
        fields = ['id', 'role', 'content', 'created_at']


class AIAssistantSessionSerializer(serializers.ModelSerializer):
    messages = AIAssistantMessageSerializer(many=True, read_only=True)
    user = serializers.ReadOnlyField(source='user.username')
    deck = serializers.SerializerMethodField()

    class Meta:
        model = AIAssistantSession
        fields = ['id', 'user', 'deck', 'title', 'is_active', 'created_at', 'ended_at', 'messages']
        read_only_fields = ['user', 'created_at', 'ended_at', 'messages']

    def get_deck(self, obj):
        """
        Only return deck summary info instead of full flashcards, keeping payload lighter.
        """
        if not obj.deck:
            return None
        return {
            "id": obj.deck.id,
            "owner": obj.deck.owner.username,
            "title": obj.deck.title,
            "description": obj.deck.description,
            "tags": obj.deck.tags.split(",") if obj.deck.tags else [],
            "is_public": obj.deck.is_public,
            "created_at": obj.deck.created_at,
            "updated_at": obj.deck.updated_at,
        }