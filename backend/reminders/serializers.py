from rest_framework import serializers
from django.utils import timezone
import pytz
from .models import Reminder, DeviceToken


class ReminderSerializer(serializers.ModelSerializer):

    # Display local time for frontend
    remind_at_local = serializers.SerializerMethodField()

    days_of_week = serializers.ListField(
        child=serializers.ChoiceField(choices=Reminder.DAYS_OF_WEEK),
        required=False,
        allow_null=True
    )

    class Meta:
        model = Reminder
        fields = [
            'id',
            'user',
            'title',
            'message',
            'deck',
            'remind_at',          
            'remind_at_local',     
            'days_of_week',
            'next_fire_at',
            'status',
            'created_at',
            'updated_at'
        ]

        read_only_fields = [
            'user',
            'next_fire_at',
            'created_at',
            'updated_at'
        ]

    # -----------------------------
    # UTC → User local time
    # -----------------------------
    def get_remind_at_local(self, obj):
        request = self.context.get("request")

        if not request or not getattr(request, "user", None):
            return obj.remind_at

        user = request.user

        try:
            user_tz = pytz.timezone(user.timezone)
        except Exception:
            user_tz = pytz.UTC

        return timezone.localtime(obj.remind_at, user_tz).isoformat()

    # -----------------------------
    # Custom validation
    # -----------------------------
    def validate_days_of_week(self, value):
        if value in (None, []):
            return None

        invalid = [d for d in value if d not in Reminder.DAYS_OF_WEEK]
        if invalid:
            raise serializers.ValidationError(
                f"Invalid days: {invalid}. Must be one of {Reminder.DAYS_OF_WEEK}"
            )
        return value


    def update(self, instance, validated_data):

        if not instance.days_of_week and "status" in validated_data:
            if validated_data["status"] == "active":
                validated_data.pop("status")

        return super().update(instance, validated_data)

    # -----------------------------
    # Auto-assign user
    # -----------------------------
    def create(self, validated_data):
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ['id', 'token', 'created_at']
        read_only_fields = ['id', 'created_at']

    def validate_token(self, value):

        return value
