from rest_framework import serializers
from .models import *

# -------------------------
# Flashcard Serializers
# -------------------------
class FlashcardSerializer(serializers.ModelSerializer):
    class Meta:
        model = Flashcard
        fields = ['id', 'deck', 'question', 'answer', 'difficulty', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def validate_question(self, value):
        if not value.strip():
            raise serializers.ValidationError("Question must not be empty.")
        return value

    def validate_answer(self, value):
        if not value.strip():
            raise serializers.ValidationError("Answer must not be empty.")
        return value


class FlashcardNestedSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField(required=False)
    deck_theme = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = Flashcard
        fields = ['id', 'question', 'answer', 'difficulty', 'deck_theme']

    def get_deck_theme(self, obj):
        theme = obj.deck.theme
        if not theme:
            return None
        return {
            'id': theme.id,
            'name': theme.name,
            'background_color': theme.background_color,
            'text_color': theme.text_color,
            'accent_color': theme.accent_color,
            'font_family': theme.font_family,
            'font_size': theme.font_size,
            'layout_style': theme.layout_style,
            'border_radius': theme.border_radius,
            'card_spacing': theme.card_spacing,
            'preview_image': theme.preview_image.url if theme.preview_image else None,
        }

    def validate_question(self, value):
        if not value.strip():
            raise serializers.ValidationError("Question must not be empty.")
        return value

    def validate_answer(self, value):
        if not value.strip():
            raise serializers.ValidationError("Answer must not be empty.")
        return value


class DeckShareSerializer(serializers.ModelSerializer):
    username = serializers.ReadOnlyField(source='user.username')

    class Meta:
        model = DeckShare
        fields = ['user', 'username', 'permission', 'shared_at']
        read_only_fields = ['shared_at']

class DeckThemeNestedSerializer(serializers.ModelSerializer):
    is_system_default = serializers.SerializerMethodField()

    accent_color = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    font_family = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    font_size = serializers.IntegerField(required=False, allow_null=True)
    layout_style = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    border_radius = serializers.IntegerField(required=False, allow_null=True)
    card_spacing = serializers.IntegerField(required=False, allow_null=True)
    preview_image = serializers.ImageField(required=False, allow_null=True)

    class Meta:
        model = DeckTheme
        fields = [
            'id', 'name', 'description', 'background_color', 'text_color',
            'accent_color', 'font_family', 'font_size', 'layout_style',
            'border_radius', 'card_spacing', 'preview_image',
            'is_system_default'
        ]
        read_only_fields = ['id', 'is_system_default']

    def get_is_system_default(self, obj):
        return obj.owner is None and getattr(obj, 'is_system_theme', False)

    def update(self, instance, validated_data):

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance


class DeckSerializer(serializers.ModelSerializer):
    owner = serializers.ReadOnlyField(source='owner.username')
    owner_id = serializers.ReadOnlyField(source='owner.id')
    flashcards = FlashcardNestedSerializer(many=True, required=False)
    tags = serializers.CharField(required=False, allow_blank=True)
    cover_image = serializers.ImageField(required=False, allow_null=True)
    admin_hidden = serializers.BooleanField(read_only=True)
    admin_note = serializers.CharField(read_only=True, allow_blank=True)
    flag_reason = serializers.CharField(read_only=True, allow_blank=True)
    is_flagged = serializers.BooleanField(read_only=True)


    # DeckTheme nested
    theme = DeckThemeNestedSerializer(read_only=True)
    theme_id = serializers.PrimaryKeyRelatedField(
        queryset=DeckTheme.objects.all(),
        source='theme',
        write_only=True,
        required=False
    )

    # Sharing fields
    is_link_shared = serializers.BooleanField(read_only=True)
    share_link = serializers.SerializerMethodField()
    shared_users = DeckShareSerializer(source='shared_with', many=True, read_only=True)
    can_edit = serializers.SerializerMethodField()
    access_level = serializers.SerializerMethodField()
    average_rating = serializers.SerializerMethodField()

    class Meta:
        model = Deck
        fields = [
            'id', 'owner', 'owner_id', 'title', 'description', 'tags',
            'is_public', 'is_archived', 'was_public',
            'theme', 'theme_id', 'card_order', 'cover_image',
            'is_link_shared', 'share_link', 'shared_users', 'can_edit', 'access_level',
            'admin_hidden', 'admin_note', 'is_flagged', 'flag_reason',
            'average_rating',
            'created_at', 'updated_at',
            'flashcards'
        ]
        read_only_fields = [
            'id', 'owner', 'owner_id',
            'created_at', 'updated_at',
            'average_rating',
            'is_link_shared', 'share_link',
            'shared_users', 'can_edit', 'access_level',
            'theme'
        ]

    # ------------------------
    # Access logic
    # ------------------------
    def get_access_level(self, obj):
        request = self.context.get('request')
        user = request.user if request and request.user.is_authenticated else None

        if user and obj.owner == user:
            return 'owner'

        if user:
            share_entry = obj.shared_with.filter(user=user).first()
            if share_entry:
                return 'edit' if share_entry.permission == 'edit' else 'view'

        share_link = request.query_params.get("share_link") if request else None
        if share_link and obj.is_link_shared and str(obj.share_link) == share_link:
            return 'link'

        if obj.is_public and not obj.is_archived:
            return 'public'

        return None

    def get_can_edit(self, obj):
        request = self.context.get('request')
        user = request.user if request and request.user.is_authenticated else None
        if not user:
            return False
        if obj.owner == user:
            return True
        return DeckShare.objects.filter(deck=obj, user=user, permission='edit').exists()

    # ------------------------
    # Computed fields
    # ------------------------
    def get_average_rating(self, obj):
        ratings = obj.feedbacks.all().values_list('rating', flat=True)
        if not ratings:
            return None
        return sum(ratings) / len(ratings)

    def get_share_link(self, obj):
        if obj.is_link_shared and obj.share_link:
            return str(obj.share_link)
        return None

    # ------------------------
    # Formatting
    # ------------------------
    def to_representation(self, instance):
        data = super().to_representation(instance)
        if isinstance(instance.tags, str):
            data['tags'] = [tag.strip() for tag in instance.tags.split(",") if tag.strip()]
        if not data.get('flashcards'):
            data['flashcards'] = []
        return data

    # ------------------------
    # Create / Update
    # ------------------------
    def create(self, validated_data):
        flashcards_data = validated_data.pop('flashcards', [])
        theme = validated_data.pop('theme', None) 


        # Create the deck first
        deck = Deck.objects.create(**validated_data)

        # -----------------------------
        # Assign theme
        # -----------------------------
        if theme:
            # If theme_id was provided, assign it
            deck.theme = theme
        else:
            # Assign system-wide default theme if exists
            system_theme = DeckTheme.objects.filter(owner__isnull=True, is_system_theme=True).first()
            if system_theme:
                deck.theme = system_theme
        deck.save(update_fields=['theme'])

        # -----------------------------
        # Create flashcards
        # -----------------------------
        for fc_data in flashcards_data:
            Flashcard.objects.create(
                deck=deck,
                question=fc_data['question'],
                answer=fc_data['answer'],
                difficulty=fc_data.get('difficulty', 'medium')
            )

        return deck
    def update(self, instance, validated_data):
        flashcards_data = validated_data.pop('flashcards', [])
        theme = validated_data.pop('theme', None)
        if 'tags' in validated_data:
            instance.tags = validated_data['tags']

        # -----------------------------
        # Update theme
        # -----------------------------
        if theme is not None:
            instance.theme = theme
        elif instance.theme is None:
            # Assign system-wide default theme if deck has no theme
            system_theme = DeckTheme.objects.filter(owner__isnull=True, is_system_theme=True).first()
            if system_theme:
                instance.theme = system_theme

        # Update other fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        # -----------------------------
        # Update flashcards
        # -----------------------------
        for fc_data in flashcards_data:
            fc_id = fc_data.get('id')
            if fc_id:
                try:
                    fc = Flashcard.objects.get(id=fc_id, deck=instance)
                    fc.question = fc_data.get('question', fc.question)
                    fc.answer = fc_data.get('answer', fc.answer)
                    if 'difficulty' in fc_data:
                        fc.difficulty = fc_data['difficulty']
                    fc.save()
                except Flashcard.DoesNotExist:
                    continue
            else:
                Flashcard.objects.create(deck=instance, **fc_data)

        return instance








class QuizSessionFlashcardSerializer(serializers.ModelSerializer):
    class Meta:
        model = QuizSessionFlashcard
        fields = ['id', 'flashcard', 'answered', 'correct', 'answer_given', 'answered_at']

    def update(self, instance, validated_data):
        was_answered = instance.answered

        updated = super().update(instance, validated_data)

        # Only record performance when the user FIRST answers
        if not was_answered and updated.answered:
            user = instance.session.user

            perf, _ = FlashcardPerformance.objects.get_or_create(
                user=user,
                flashcard=instance.flashcard
            )

            perf.record_answer(
                correct=updated.correct,
                response_time=None  # add later if available
            )

        return updated


class QuizSessionSerializer(serializers.ModelSerializer):
    flashcard_attempts = QuizSessionFlashcardSerializer(many=True, read_only=True)
    accuracy = serializers.SerializerMethodField()
    class Meta:
        model = QuizSession
        fields = ['id', 'user', 'deck', 'mode', 'adaptive_mode', 'time_per_card',
                  'started_at', 'finished_at', 'is_paused', 'correct_count', 'total_answered',
                  'current_index', 'order', 'flashcard_attempts', 'accuracy']
        read_only_fields = ['user', 'started_at', 'finished_at', 'correct_count', 'total_answered',
                            'current_index', 'order', 'flashcard_attempts', 'accuracy']
    def get_accuracy(self, obj):
        return obj.accuracy()
    
class FlashcardWithPerformanceSerializer(FlashcardSerializer):
    user_performance = serializers.SerializerMethodField()

    class Meta(FlashcardSerializer.Meta):
        fields = FlashcardSerializer.Meta.fields + ['user_performance']

    def get_user_performance(self, obj):
        user = self.context.get("request").user
        if not user or user.is_anonymous:
            return None

        perf, _ = FlashcardPerformance.objects.get_or_create(
            user=user,
            flashcard=obj
        )
        return FlashcardPerformanceSerializer(perf).data


class FlashcardPerformanceSerializer(serializers.ModelSerializer):
    flashcard_id = serializers.ReadOnlyField(source='flashcard.id')
    question = serializers.ReadOnlyField(source='flashcard.question')

    class Meta:
        model = FlashcardPerformance
        fields = [
            'id', 'flashcard_id', 'question',

            # Core accuracy
            'correct_count', 'incorrect_count', 'avg_response_time',

            # Adaptive difficulty
            'user_difficulty',

            # Spaced repetition fields (SM-2)
            'easiness',
            'interval',
            'repetitions',
            'last_reviewed',
            'next_review_due',
        ]

        read_only_fields = [
            'id', 'flashcard_id', 'question',

            # User should not modify these
            'correct_count', 'incorrect_count',
            'avg_response_time',
            'user_difficulty',

            # SRS auto-computed
            'easiness',
            'interval',
            'repetitions',
            'last_reviewed',
            'next_review_due',
        ]

class FeedbackSerializer(serializers.ModelSerializer):
    user = serializers.ReadOnlyField(source='user.username')

    class Meta:
        model = Feedback
        fields = ['id', 'deck', 'user', 'rating', 'comment', 'created_at']
        read_only_fields = ['id', 'user', 'created_at']

    def validate_rating(self, value):
        if not (1 <= value <= 5):
            raise serializers.ValidationError("Rating must be between 1 and 5.")
        return value
