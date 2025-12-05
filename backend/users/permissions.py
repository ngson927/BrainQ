from rest_framework.permissions import BasePermission
import logging

logger = logging.getLogger("security")

class IsAdmin(BasePermission):
    """Allow access only to active, non-suspended admin users."""
    message = "Admin access only."

    def has_permission(self, request, view):
        user = getattr(request, "user", None)

        if not user or not user.is_authenticated:
            logger.warning(
                f"Unauthenticated admin access attempt to {view.__class__.__name__} path={request.path}"
            )
            return False

        if getattr(user, "is_suspended", False) or not getattr(user, "is_active", True):
            logger.warning(
                f"Suspended/inactive admin '{user.username}' attempted access to {view.__class__.__name__}"
            )
            return False

        if getattr(user, "role", None) != "admin":
            logger.warning(
                f"Non-admin '{user.username}' attempted access to {view.__class__.__name__}"
            )
            return False

        return True
class IsRegularUser(BasePermission):
    """Allow access only to active, non-suspended regular users."""
    message = "User access only."

    def has_permission(self, request, view):
        user = getattr(request, "user", None)

        if not user or not user.is_authenticated:
            return False

        if getattr(user, "is_suspended", False) or not getattr(user, "is_active", True):
            return False

        return getattr(user, "role", None) == "user"
