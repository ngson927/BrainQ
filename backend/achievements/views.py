from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import TokenAuthentication
from rest_framework import status
from django.utils import timezone
from .models import Achievements
from .serializers import StreakSerializer


class StreakDetailView(APIView):
    """
    GET: Retrieve the current user's streak and badges.
    """
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        streak, _ = Achievements.objects.get_or_create(user=request.user)
        serializer = StreakSerializer(streak)
        return Response(serializer.data)


class UpdateStreakView(APIView):

    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        streak, _ = Achievements.objects.get_or_create(user=request.user)

        perfect_quiz = bool(request.data.get("perfect_quiz", False))
        created_first_deck = bool(request.data.get("created_first_deck", False))

        streak.update_study(
            study_date=timezone.localdate(),
            perfect_quiz=perfect_quiz,
            created_first_deck=created_first_deck
        )

        return Response(StreakSerializer(streak).data, status=status.HTTP_200_OK)


class ResetStreakView(APIView):

    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        streak, _ = Achievements.objects.get_or_create(user=request.user)
        break_date = request.data.get("break_date")
        streak.reset_streak(break_date=break_date)
        return Response({"message": "Streak reset successfully"}, status=status.HTTP_200_OK)


class RecoverStreakView(APIView):

    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        streak, _ = Achievements.objects.get_or_create(user=request.user)
        streak.recover_streak()
        return Response(StreakSerializer(streak).data, status=status.HTTP_200_OK)
