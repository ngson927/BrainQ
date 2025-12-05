# analytics/urls.py
from django.urls import path
from .views import AdminAnalyticsHistoryView, UserAnalyticsView, AdminAnalyticsView

urlpatterns = [
    path("user/", UserAnalyticsView.as_view(), name="user-analytics"),
    path("admin/", AdminAnalyticsView.as_view(), name="admin-analytics"),
    path("admin/history/", AdminAnalyticsHistoryView.as_view(), name="admin-analytics-history"),

]
