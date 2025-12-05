from django.shortcuts import render

from datetime import timedelta
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser

from analytics.services import get_user_analytics, get_admin_analytics
from analytics.models import AnalyticsSnapshot



class UserAnalyticsView(APIView):
    """
    Returns analytics data for the currently authenticated user.
    Delegates computation to analytics/services.py
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        data = get_user_analytics(request.user)
        return Response({
            "user": request.user.username,
            **data
        })


class AdminAnalyticsView(APIView):
    """
    Returns site-wide analytics for admins.
    Loads cached snapshots if available (auto-generated daily).
    """
    permission_classes = [IsAdminUser]

    def get(self, request):
        data = get_admin_analytics(use_snapshot=True)
        return Response(data)
    
class AdminAnalyticsHistoryView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        snapshots = AnalyticsSnapshot.objects.order_by("-snapshot_date")[:30]
        data = [
            {
                "date": s.snapshot_date.isoformat(),
                "metrics": s.payload,
            }
            for s in snapshots
        ]
        return Response(data)
