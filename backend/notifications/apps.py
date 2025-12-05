
from django.apps import AppConfig
import logging

logger = logging.getLogger(__name__)

class NotificationsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'notifications'
    
    def ready(self):
        try:
            import notifications.listeners  # noqa: F401
        except Exception as e:
            logger.exception("Failed to import notifications.listeners in AppConfig.ready(): %s", e)