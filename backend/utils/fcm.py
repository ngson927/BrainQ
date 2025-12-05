from django.conf import settings
from django.db import transaction
import firebase_admin
from firebase_admin import credentials, messaging
import logging
from datetime import timedelta
from django.utils import timezone

logger = logging.getLogger(__name__)

# -------------------------
# Firebase Singleton Init
# -------------------------
if not firebase_admin._apps:
    cred = credentials.Certificate(str(settings.FIREBASE_CREDENTIAL_PATH))
    firebase_admin.initialize_app(cred)

    import google.auth.transport.requests
    import requests

    session = requests.Session()
    adapter = requests.adapters.HTTPAdapter(pool_connections=50, pool_maxsize=50)
    session.mount("https://", adapter)
    google.auth.transport.requests.Request(session=session)

# -------------------------
# Batch sending (sync)
# -------------------------
BATCH_SIZE = 20

# Temporary in-memory cache to track recently sent tags (safety net)
_SENT_TAG_CACHE = {}
_SENT_TAG_TTL = timedelta(seconds=60)  # Keep each tag for 60 seconds

def _cleanup_sent_cache():
    """Remove expired tags from the in-memory cache."""
    now = timezone.now()
    expired = [tag for tag, ts in _SENT_TAG_CACHE.items() if now - ts > _SENT_TAG_TTL]
    for tag in expired:
        del _SENT_TAG_CACHE[tag]

def send_batch(batch_tokens, title, body, data=None, tag=None, channel_id="default"):
    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=title,
            body=body
        ),
        data=data or {},
        android=messaging.AndroidConfig(
            notification=messaging.AndroidNotification(
                tag=tag,
                channel_id=channel_id
            )
        ),
        tokens=batch_tokens,
    )
    response = messaging.send_each_for_multicast(message)

    logger.info(f"{tag or 'Notification'}: {response.success_count}/{len(batch_tokens)} sent")

    if response.failure_count > 0:
        for idx, resp in enumerate(response.responses):
            if not resp.success:
                token = batch_tokens[idx]
                error = resp.exception
                logger.warning(f"Invalid token removed: {token} | Error: {error}")
                from notifications.models import DeviceToken
                DeviceToken.objects.filter(token=token).delete()

def send_push_to_user(user, title, body, data=None, tag=None, channel_id="default"):
    """
    Sends a push notification to all devices for a given user.

    Safety net: prevent sending the same `tag` multiple times within ~1 minute.
    """
    global _SENT_TAG_CACHE

    # Clean old entries
    _cleanup_sent_cache()

    now = timezone.now()

    # Skip if recently sent
    if tag:
        last_sent = _SENT_TAG_CACHE.get(tag)
        if last_sent and now - last_sent < _SENT_TAG_TTL:
            logger.info(f"Skipped duplicate notification with tag={tag}")
            return
        _SENT_TAG_CACHE[tag] = now

    from reminders.models import DeviceToken
    device_tokens = list(
        DeviceToken.objects.filter(user=user).values_list("token", flat=True)
    )
    if not device_tokens:
        logger.info(f"No devices for user {user.id}")
        return

    for i in range(0, len(device_tokens), BATCH_SIZE):
        batch_tokens = device_tokens[i:i + BATCH_SIZE]
        send_batch(batch_tokens, title, body, data=data, tag=tag, channel_id=channel_id)
