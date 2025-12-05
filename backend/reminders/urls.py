from rest_framework.routers import DefaultRouter
from .views import ReminderViewSet, DeviceTokenViewSet

router = DefaultRouter()
router.register(r'reminders', ReminderViewSet, basename='reminder')
router.register(r'device-tokens', DeviceTokenViewSet, basename='device-token')

urlpatterns = router.urls
