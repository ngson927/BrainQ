
from rest_framework import serializers
from .models import Notification

class NotificationSerializer(serializers.ModelSerializer):
    actor_username = serializers.CharField(source='actor.username', read_only=True)
    deck_title = serializers.CharField(source='deck.title', read_only=True)

    class Meta:
        model = Notification
        fields = [
            'id',
            'recipient',
            'actor',
            'actor_username',
            'notif_type',
            'verb',
            'deck',
            'deck_title',
            'delivery_channel',
            'push_status',
            'extra_data',
            'is_read',
            'created_at',
        ]

        read_only_fields = [
            'id',
            'actor_username',
            'deck_title',
            'created_at',
            'push_status',
        ]
