from rest_framework import serializers
from users.models import CustomUser
from decks.models import Deck


class AdminUserSummarySerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = ['id', 'username', 'email', 'role', 'is_active', 'is_suspended', 'date_joined']

class AdminUserDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name',
            'role', 'is_active', 'is_suspended', 'date_joined'
        ]
        read_only_fields = ['id', 'date_joined']


class AdminDeckSummarySerializer(serializers.ModelSerializer):
    owner_username = serializers.CharField(source='owner.username', read_only=True)
    flashcards_count = serializers.SerializerMethodField()
    tags = serializers.SerializerMethodField()
    cover_image = serializers.SerializerMethodField()
    average_rating = serializers.SerializerMethodField()

    class Meta:
        model = Deck
        fields = [
            'id', 'title', 'owner_username', 'is_public', 'is_archived',
            'is_flagged', 'admin_hidden', 'created_at',
            'flashcards_count', 'tags', 'cover_image', 'average_rating'
        ]
        read_only_fields = ['id', 'owner_username', 'created_at']

    def get_flashcards_count(self, obj):
        if obj.is_public:
            return obj.flashcards.count()
        return None

    def get_tags(self, obj):
        if obj.is_public:
            if isinstance(obj.tags, str):
                return [tag.strip() for tag in obj.tags.split(",") if tag.strip()]
            return obj.tags or []
        return None

    def get_cover_image(self, obj):
        if obj.is_public and obj.cover_image:
            request = self.context.get('request')
            return request.build_absolute_uri(obj.cover_image.url) if request else obj.cover_image.url
        return None

    def get_average_rating(self, obj):
        if obj.is_public:
            ratings = obj.feedbacks.all().values_list('rating', flat=True)
            if not ratings:
                return None
            return sum(ratings) / len(ratings)
        return None


class AdminDeckDetailSerializer(serializers.ModelSerializer):
    owner_username = serializers.CharField(source='owner.username', read_only=True)
    flashcards = serializers.SerializerMethodField()
    tags = serializers.SerializerMethodField()
    cover_image = serializers.SerializerMethodField()
    average_rating = serializers.SerializerMethodField()
    comments = serializers.SerializerMethodField()  # comments with rating

    class Meta:
        model = Deck
        fields = [
            'id', 'title', 'description', 'owner_username',
            'is_public', 'is_archived', 'is_flagged', 'flag_reason',
            'admin_hidden', 'admin_note', 'created_at', 'updated_at',
            'flashcards', 'tags', 'cover_image', 'average_rating', 'comments'
        ]
        read_only_fields = ['id', 'owner_username', 'created_at', 'updated_at']

    def get_flashcards(self, obj):
        if obj.is_public:
            return [{'question': c.question, 'answer': c.answer} for c in obj.flashcards.all()]
        return None

    def get_tags(self, obj):
        if obj.is_public:
            if isinstance(obj.tags, str):
                return [tag.strip() for tag in obj.tags.split(",") if tag.strip()]
            return obj.tags or []
        return None

    def get_cover_image(self, obj):
        if obj.is_public and obj.cover_image:
            request = self.context.get('request')
            return request.build_absolute_uri(obj.cover_image.url) if request else obj.cover_image.url
        return None

    def get_average_rating(self, obj):
        if obj.is_public:
            ratings = obj.feedbacks.all().values_list('rating', flat=True)
            if not ratings:
                return None
            return sum(ratings) / len(ratings)
        return None

    def get_comments(self, obj):

        if obj.is_public:
            return [
                {
                    "user": f.user.username if f.user else "Anonymous",
                    "comment": f.comment or "",
                    "rating": f.rating
                }
                for f in obj.feedbacks.all().order_by('-created_at')
            ]
        return None
