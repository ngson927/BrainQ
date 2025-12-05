from celery import shared_task
from django.utils import timezone
from django.db import transaction
from .models import Reminder
from utils.fcm import send_push_to_user 
import logging

logger = logging.getLogger(__name__)

# -------------------------
# Main Celery Worker
# -------------------------
@shared_task(bind=True, autoretry_for=(Exception,), retry_kwargs={'max_retries': 5}, retry_backoff=True, retry_jitter=True)
def check_and_send_reminders(self):
    now = timezone.now()
    try:
        with transaction.atomic():
            # Lock rows to avoid duplicates
            due_reminders = Reminder.objects.select_for_update().filter(
                next_fire_at__lte=now,
                status="active"
            )
            for reminder in due_reminders:
                try:
                    # Mark as processing immediately
                    reminder.status = "processing"
                    reminder.save(update_fields=["status"])

                    send_push_to_user(
                        user=reminder.user,
                        title=reminder.title or "Study Reminder",
                        body=reminder.message,
                        data={"reminder_id": str(reminder.id), "type": "reminder"},
                        tag=str(reminder.id),
                        channel_id="reminders"
                    )

                    # Reschedule or deactivate after sending
                    reminder.deactivate_or_reschedule()
                except Exception as e:
                    logger.error(f"Reminder {reminder.id} failed: {str(e)}", exc_info=True)
                    raise self.retry(exc=e)
    except Exception as outer_exc:
        logger.error(f"Transaction failed: {str(outer_exc)}", exc_info=True)
        raise self.retry(exc=outer_exc)
