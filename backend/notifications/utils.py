
from .models import Notification
from .handlers import HANDLER_REGISTRY

def create_notification(
    recipient,
    notif_type,
    verb,
    actor=None,
    deck=None,
    channels=("in_app",),
    extra_data=None
):
    # Determine delivery channel
    if "push" in channels and "in_app" in channels:
        delivery_channel = "both"
    elif "push" in channels:
        delivery_channel = "push"
    else:
        delivery_channel = "in_app"

    # Create the notification
    notif = Notification.objects.create(
        recipient=recipient,
        actor=actor,
        notif_type=notif_type,
        verb=verb,
        deck=deck,
        delivery_channel=delivery_channel,
        extra_data=extra_data or {},
        push_status="pending" if "push" in channels else "sent"  # Only mark pending if push will be attempted
    )

    # Dispatch delivery through handlers
    for channel in channels:
        handler = HANDLER_REGISTRY.get(channel)
        if handler:
            try:
                handler.send(notif)
            except Exception:
        
                pass

    return notif
