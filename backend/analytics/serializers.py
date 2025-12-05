
from rest_framework import serializers

class ChartPointSerializer(serializers.Serializer):
    label = serializers.CharField()
    value = serializers.FloatField()

class StudyPerDeckSerializer(serializers.Serializer):
    deck_id = serializers.IntegerField()
    deck = serializers.CharField()
    sessions = serializers.IntegerField()
    minutes = serializers.FloatField()
    accuracy = serializers.FloatField()

class UserAnalyticsSerializer(serializers.Serializer):
    decks = serializers.DictField()
    quizzes = serializers.DictField()
    streak = serializers.DictField()
    charts = serializers.DictField()
