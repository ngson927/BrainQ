from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from .models import Reminder, DeviceToken
from .serializers import ReminderSerializer, DeviceTokenSerializer


class ReminderViewSet(viewsets.ModelViewSet):
    serializer_class = ReminderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):

        return Reminder.objects.filter(
            user=self.request.user,
            status="active"
        ).order_by("next_fire_at")


    def perform_create(self, serializer):

        serializer.save(user=self.request.user)

    def destroy(self, request, *args, **kwargs):

        instance = self.get_object()
        instance.status = "completed"
        instance.save(update_fields=["status"])

        return Response(status=status.HTTP_204_NO_CONTENT)

    def perform_update(self, serializer):

        serializer.save(user=self.request.user)

class DeviceTokenViewSet(viewsets.ModelViewSet):
    serializer_class = DeviceTokenSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return DeviceToken.objects.filter(user=self.request.user)

    def perform_create(self, serializer):

        token = serializer.validated_data.get("token")
        user = self.request.user

        existing = DeviceToken.objects.filter(user=user, token=token).first()
        if existing:
            existing.save()  
        else:
            serializer.save(user=user)

