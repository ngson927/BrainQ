from rest_framework import permissions

class IsOwnerOrCollaboratorOrReadOnly(permissions.BasePermission):

    def has_object_permission(self, request, view, obj):
        user = request.user

        # SAFE METHODS (GET, HEAD, OPTIONS)
        if request.method in permissions.SAFE_METHODS:
            # Public decks → anyone can view
            if obj.is_public:
                return True
            
            # Owner can view
            if obj.owner == user:
                return True
            
            # Collaborator can view
            if hasattr(obj, "shared_with") and user in obj.shared_with.all():
                return True
            
            return False

        # NON–SAFE METHODS → EDITING

        # Owners can always edit the deck
        if obj.owner == user:
            return True

        # Collaborators can edit only certain things (flashcards)
        if hasattr(obj, "shared_with") and user in obj.shared_with.all():
            
            # Only allow collaborators to add flashcards
            # NOT customize deck, rename deck, etc.
            if view.__class__.__name__ == "CreateFlashcardView":
                return True
            
            return False

        return False
