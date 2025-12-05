
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.pagination import PageNumberPagination
from .models import Notification
from .serializers import NotificationSerializer

class NotificationListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Notification.objects.filter(recipient=request.user)

        is_read_param = request.query_params.get('is_read')
        if is_read_param is not None:
            if is_read_param.lower() == 'true':
                qs = qs.filter(is_read=True)
            elif is_read_param.lower() == 'false':
                qs = qs.filter(is_read=False)

        qs = qs.order_by('is_read', '-created_at')

        paginator = PageNumberPagination()
        paginated_qs = paginator.paginate_queryset(qs, request, view=self)

        if paginated_qs is not None:
            serializer = NotificationSerializer(paginated_qs, many=True, context={'request': request})
            return paginator.get_paginated_response(serializer.data)

        serializer = NotificationSerializer(qs, many=True, context={'request': request})
        return Response({
            "count": 0,
            "next": None,
            "previous": None,
            "results": serializer.data
        })

class MarkNotificationReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        notif = Notification.objects.filter(id=pk, recipient=request.user).first()
        if not notif:
            return Response({"detail": "Notification not found."}, status=404)
        
        notif.is_read = True
        notif.save(update_fields=['is_read'])

        serializer = NotificationSerializer(notif, context={'request': request})
        return Response(serializer.data)


class MarkAllNotificationsReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        unread_qs = Notification.objects.filter(recipient=request.user, is_read=False)
        updated_count = unread_qs.update(is_read=True)

        # Re-fetch the updated notifications so serializer shows current state
        updated_notifications = Notification.objects.filter(recipient=request.user, is_read=True)[:updated_count]

        serializer = NotificationSerializer(updated_notifications, many=True, context={'request': request})

        return Response({
            "detail": f"{updated_count} notifications marked as read.",
            "updated_notifications": serializer.data
        })
