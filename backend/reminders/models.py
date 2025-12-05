from django.db import models
from django.conf import settings
from django.utils import timezone
from datetime import datetime, timedelta
import pytz


class Reminder(models.Model):

    DAYS_OF_WEEK = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    REMINDER_STATUS = [
        ("active", "Active"),
        ("paused", "Paused"),
        ("completed", "Completed"),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    title = models.CharField(max_length=120, blank=True, null=True)
    message = models.CharField(max_length=255)
    deck = models.ForeignKey('decks.Deck', on_delete=models.CASCADE, null=True, blank=True)
    remind_at = models.DateTimeField()

    days_of_week = models.JSONField(default=list, blank=True)

    next_fire_at = models.DateTimeField(null=True, blank=True)

    status = models.CharField(
        max_length=20,
        choices=REMINDER_STATUS,
        default="active"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "next_fire_at", "status"]),
        ]

    def __str__(self):
        return f"{self.title or self.message} @ {self.remind_at} (UTC)"


    def _get_user_timezone(self):
        tz_name = getattr(self.user, "timezone", None)
        try:
            return pytz.timezone(tz_name) if tz_name else pytz.UTC
        except pytz.UnknownTimeZoneError:
            return pytz.UTC

    # ------------------------------------------
    # Convert user local → UTC
    # ------------------------------------------
    def _convert_local_to_utc(self, dt_local):
        user_tz = self._get_user_timezone()
        if timezone.is_naive(dt_local):
            dt_local = user_tz.localize(dt_local)
        return dt_local.astimezone(pytz.UTC)

    # ------------------------------------------
    # Calculate next fire time
    # ------------------------------------------
    def _calculate_next_fire(self, remind_at_utc):
        user_tz = self._get_user_timezone()
        now_utc = timezone.now()
        now_local = now_utc.astimezone(user_tz)
        reminder_local = remind_at_utc.astimezone(user_tz)

        # Recurring reminder
        if self.days_of_week:
            weekday_map = {day: i for i, day in enumerate(self.DAYS_OF_WEEK)}
            current_weekday = now_local.weekday()
            target_time = reminder_local.time()
            next_candidates = []

            for day in self.days_of_week:
                if day not in weekday_map:
                    continue
                target_weekday = weekday_map[day]
                delta = (target_weekday - current_weekday + 7) % 7
                date_candidate = (now_local + timedelta(days=delta)).date()
                local_dt = datetime.combine(date_candidate, target_time)
                local_dt = user_tz.localize(local_dt)
                utc_dt = local_dt.astimezone(pytz.UTC)

                if utc_dt <= now_utc:
                    utc_dt += timedelta(days=7)

                next_candidates.append(utc_dt)

            return min(next_candidates) if next_candidates else remind_at_utc

        # One-time reminder
        return remind_at_utc

    def save(self, *args, **kwargs):
        if not (timezone.is_aware(self.remind_at) and self.remind_at.tzinfo == pytz.UTC):
            self.remind_at = self._convert_local_to_utc(self.remind_at)

        # Always recalc next fire
        self.next_fire_at = self._calculate_next_fire(self.remind_at)

        super().save(*args, **kwargs)

    # ------------------------------------------
    # Trigger after sending
    # ------------------------------------------
    def deactivate_or_reschedule(self):
        if not self.days_of_week:
            if self.status != "completed":
                self.status = "completed"
                self.save(update_fields=["status"])
            return

        next_fire = self._calculate_next_fire(self.remind_at)
        if self.next_fire_at != next_fire:
            self.next_fire_at = next_fire
            self.save(update_fields=["next_fire_at"])


class DeviceToken(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    token = models.CharField(max_length=255, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "token")

    def __str__(self):
        return f"{self.user} - {self.token}"

