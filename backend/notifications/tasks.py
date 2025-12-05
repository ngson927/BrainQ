from celery import shared_task
import logging
from .models import Notification
from django.db import transaction
from utils.fcm import send_push_to_user

logger = logging.getLogger(__name__)


@shared_task(
    bind=True,
    name="notifications.tasks.send_notification_task",
    autoretry_for=(Exception,),
    retry_kwargs={'max_retries': 5},
    retry_backoff=True,
    retry_jitter=True
)
def send_notification_task(self, notification_id):
    try:
        with transaction.atomic():
            notif = Notification.objects.select_for_update().get(id=notification_id)

            # Skip if already sent or processing
            if notif.push_status in ["sent", "processing"]:
                logger.info(f"Notification {notification_id} already processed")
                return

            # Mark as processing
            notif.push_status = "processing"
            notif.save(update_fields=["push_status"])

        payload = {
            "notification_id": str(notif.id),
            "type": notif.notif_type,
            "deck_id": str(notif.deck.id) if notif.deck else ""
        }

        send_push_to_user(
            user=notif.recipient,
            title="BrainQ",
            body=notif.verb,
            data=payload,
            tag=f"notif_{notif.id}",
            channel_id="notifications"
        )

        # Mark as sent after success
        notif.push_status = "sent"
        notif.save(update_fields=["push_status"])

    except Notification.DoesNotExist:
        logger.warning(f"Notification {notification_id} does not exist")
    except Exception as e:
        try:
            notif.push_status = "failed"
            notif.save(update_fields=["push_status"])
        except Exception:
            logger.exception(f"Failed to update push_status for notification {notification_id}")
        logger.error(f"Failed to send notification {notification_id}: {e}", exc_info=True)
        raise self.retry(exc=e)


@shared_task
def retry_pending_notifications():
    pending = Notification.objects.filter(push_status='pending')
    count = pending.count()
    logger.info(f"Retrying {count} pending notifications")
    for notif in pending:
        send_notification_task.delay(notif.id)