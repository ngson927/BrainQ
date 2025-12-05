from django.urls import path
from .views import (
    RegisterView,
    LoginView,
    LogoutView,
    AdminOnlyView,
    RequestPasswordResetView,
    ConfirmPasswordResetView,
    UpdateTimezoneView,
    UpdateProfileView,
    DeleteAccountView
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('logout/', LogoutView.as_view(), name='logout'),
    path('admin-only/', AdminOnlyView.as_view(), name='admin-only'),
    path('update-timezone/', UpdateTimezoneView.as_view(), name='update-timezone'),
    path('password-reset/', RequestPasswordResetView.as_view(), name='password-reset'),
    path('password-reset/confirm/', ConfirmPasswordResetView.as_view(), name='password-reset-confirm'),
    path("update-profile/", UpdateProfileView.as_view()),
    path("delete-account/", DeleteAccountView.as_view()),

]
