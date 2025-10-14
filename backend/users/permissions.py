from rest_framework.permissions import BasePermission

class IsAdmin(BasePermission):
    """Allow access only to admin users."""
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'admin'

class IsRegularUser(BasePermission):
    """Allow access only to regular users."""
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'user'
