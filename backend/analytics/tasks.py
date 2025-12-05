# analytics/tasks.py
from django.utils import timezone
from celery import shared_task
from .models import AnalyticsSnapshot
from .services import get_admin_analytics
from datetime import timedelta, datetime

def serialize_for_json(obj):

    if isinstance(obj, timedelta):
        total_seconds = int(obj.total_seconds())
        hours, remainder = divmod(total_seconds, 3600)
        minutes, seconds = divmod(remainder, 60)
        return f"PT{hours}H{minutes}M{seconds}S"
    elif isinstance(obj, datetime):
        if timezone.is_naive(obj):
            obj = timezone.make_aware(obj, timezone.get_current_timezone())
        return obj.isoformat()
    elif isinstance(obj, dict):
        return {k: serialize_for_json(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [serialize_for_json(v) for v in obj]
    else:
        return obj


@shared_task
def capture_daily_admin_metrics_task():
    """
    Celery task to capture daily admin analytics, serialize them safely,
    and persist them in AnalyticsSnapshot. Returns a minimal JSON-safe dict
    so Celery can store the result without serialization errors.
    """
    today = timezone.localdate()

    # Step 1: Gather raw analytics data
    raw_data = get_admin_analytics()

    # Step 2: Ensure JSON-safe payload
    safe_payload = serialize_for_json(raw_data)

    # Step 3: Save snapshot (update or create ensures uniqueness per day)
    snapshot, _ = AnalyticsSnapshot.objects.update_or_create(
        name="daily_admin_metrics",
        snapshot_date=today,
        defaults={"payload": safe_payload},
    )

    # Step 4: Return a minimal JSON-safe dict
    return {
        "status": "ok",
        "snapshot_date": today.isoformat(),
        "recorded": True,
    }

