from .models import Notification
from .tasks import send_notification_task


class BaseNotificationHandler:
    def send(self, notification: Notification):
        raise NotImplementedError("Handlers must implement send()")


class InAppNotificationHandler(BaseNotificationHandler):

    def send(self, notification: Notification):
        if notification.delivery_channel == "in_app":
            return True

        return True


class PushNotificationHandler(BaseNotificationHandler):
    """
    Sends push notifications via Celery task.
    """
    def send(self, notification: Notification):
        # Only push channel updates push_status
        notification.push_status = "pending"
        notification.save(update_fields=["push_status"])

        # Pass UUID directly, not string
        send_notification_task.delay(notification.id)
        return True


HANDLER_REGISTRY = {
    "in_app": InAppNotificationHandler(),
    "push": PushNotificationHandler(),
}
