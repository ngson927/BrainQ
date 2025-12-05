from rest_framework import serializers
from .models import Achievements

class StreakSerializer(serializers.ModelSerializer):
    class Meta:
        model = Achievements
        fields = [
            "current_streak",
            "best_streak",
            "total_study_days",
            "last_active",
            "badges",
            "break_dates",
            "has_freeze",
            "recovery_used",
        ]
