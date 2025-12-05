from django.urls import path
from .views_admin import (
    AdminUserListView,
    AdminUserDetailView,
    AdminDashboardStatsView,
    AdminBulkUserActionView,
)
from .views_admin import (
    AdminDeckListView,
    AdminDeckDetailView,
    AdminBulkDeckActionView,
)

urlpatterns = [
    # Users
    path('users/', AdminUserListView.as_view(), name='admin-user-list'),
    path('users/<int:pk>/', AdminUserDetailView.as_view(), name='admin-user-detail'),
    path('users/bulk/', AdminBulkUserActionView.as_view(), name='admin-user-bulk'),

    # Decks
    path('decks/', AdminDeckListView.as_view(), name='admin-deck-list'),
    path('decks/<int:pk>/', AdminDeckDetailView.as_view(), name='admin-deck-detail'),
    path('decks/bulk/', AdminBulkDeckActionView.as_view(), name='admin-deck-bulk'),

    # Dashboard
    path('dashboard/stats/', AdminDashboardStatsView.as_view(), name='admin-dashboard-stats'),
]
