"""
URL configuration for brainq project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import path, include

from brainq import settings


urlpatterns = [
    path('admin/', admin.site.urls),
    path('decks/', include('decks.urls_public')),
    path('api/users/', include('users.urls')),
    path('api/', include('decks.decksurls')),
    path('api/ai/', include('ai.urls')),
    path("api/achievements/", include("achievements.urls")),
    path("api/analytics/", include("analytics.urls")),
    path('api/admin/', include('users.urls_admin')),
    path('api/', include('reminders.urls')),
        path('api/notifications/', include('notifications.urls')),



]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
