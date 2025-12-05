
from datetime import timedelta
import logging
from typing import Dict, Any

from django.utils import timezone
from django.core.cache import cache
from django.conf import settings
from django.db.models import (
    Count, Avg, Sum, FloatField, ExpressionWrapper, F, DurationField, Q
)
from django.db.models.functions import TruncDate
from django.db import transaction

from users.models import CustomUser
from decks.models import Deck, QuizSession
from achievements.models import Achievements
from .models import AnalyticsSnapshot
from .utils import build_chart 

logger = logging.getLogger(__name__)

# Cache TTLs (seconds)
USER_ANALYTICS_TTL = getattr(settings, "USER_ANALYTICS_TTL", 60 * 5)     
ADMIN_ANALYTICS_TTL = getattr(settings, "ADMIN_ANALYTICS_TTL", 60 * 5)   

# ---------- Helpers ----------

def _annotate_duration(qs):
    """Annotate queryset with DurationField 'duration' when finished_at exists."""
    return qs.exclude(finished_at__isnull=True).annotate(
        duration=ExpressionWrapper(F('finished_at') - F('started_at'), output_field=DurationField())
    )


def _safe_avg_accuracy_agg(expr):

    return Avg(ExpressionWrapper(expr, output_field=FloatField()))


def _aggregate_deck_counts_for_user(user):
    agg = Deck.objects.filter(owner=user).aggregate(
        total=Count('id'),
        public=Count('id', filter=Q(is_public=True))
    )
    return agg.get('total') or 0, agg.get('public') or 0


# ---------- Core analytics functions ----------

def compute_user_analytics(user: CustomUser, days: int = 7) -> Dict[str, Any]:
    """Compute raw analytics for a single user."""
    if not user or not getattr(user, "id", None):
        return {}

    today = timezone.now().date()
    start_date = today - timedelta(days=days)

    # Deck stats
    total_decks, public_decks = _aggregate_deck_counts_for_user(user)

    # Sessions
    sessions = QuizSession.objects.filter(user=user).exclude(started_at__isnull=True)
    total_sessions = sessions.count()

    # Accuracy
    accuracy_qs = sessions.filter(total_answered__gt=0)
    avg_accuracy = accuracy_qs.aggregate(
        avg=_safe_avg_accuracy_agg(F('correct_count') * 1.0 / F('total_answered'))
    ).get('avg') or 0.0

    perfect_quizzes = sessions.filter(
        correct_count=F('total_answered'), total_answered__gt=0
    ).count()

    # Durations
    sessions_d = _annotate_duration(sessions)
    avg_duration = sessions_d.aggregate(avg_duration=Avg('duration')).get('avg_duration')
    avg_minutes = round(avg_duration.total_seconds() / 60, 1) if avg_duration else 0.0

    # Study time per day
    study_time_per_day_qs = (
        sessions_d.filter(started_at__date__gte=start_date)
        .annotate(date=TruncDate('started_at'))
        .values('date')
        .annotate(total_time=Sum('duration'))
        .order_by('date')
    )
    minutes_studied_chart = build_chart(study_time_per_day_qs, label_field='date', value_field='total_time')

    # Deck-level stats
    deck_activity_qs = (
        sessions_d.filter(total_answered__gt=0)
        .values('deck__id', 'deck__title')
        .annotate(
            session_count=Count('id'),
            total_time=Sum('duration'),
            avg_accuracy=_safe_avg_accuracy_agg(F('correct_count') * 1.0 / F('total_answered'))
        )
        .order_by('-session_count')
    )
    study_per_deck_chart = []
    for entry in deck_activity_qs:
        total_time = entry.get('total_time')
        minutes = round(total_time.total_seconds() / 60, 1) if total_time else 0
        study_per_deck_chart.append({
            "deck_id": entry.get('deck__id'),
            "deck": entry.get('deck__title'),
            "sessions": entry.get('session_count') or 0,
            "minutes": minutes,
            "accuracy": round(entry.get('avg_accuracy') or 0, 2),
        })

    # Achievements
    achievements_obj = Achievements.objects.filter(user=user).only(
        'current_streak', 'best_streak', 'total_study_days', 'badges'
    ).first()
    streak_data = {
        "current_streak": getattr(achievements_obj, 'current_streak', 0) or 0,
        "best_streak": getattr(achievements_obj, 'best_streak', 0) or 0,
        "total_study_days": getattr(achievements_obj, 'total_study_days', 0) or 0,
        "badges": getattr(achievements_obj, 'badges', []) or [],
    }

    # Daily activity chart
    recent_activity_qs = (
        sessions.filter(started_at__date__gte=start_date)
        .annotate(date=TruncDate('started_at'))
        .values('date')
        .annotate(count=Count('id'))
        .order_by('date')
    )
    activity_chart = build_chart(recent_activity_qs, label_field='date', value_field='count')

    data = {
        "decks": {"total": total_decks, "public": public_decks},
        "quizzes": {
            "total_sessions": total_sessions,
            "average_accuracy": round(avg_accuracy or 0, 2),
            "perfect_quizzes": perfect_quizzes,
            "average_time_spent_minutes": avg_minutes,
        },
        "streak": streak_data,
        "charts": {
            "activity": activity_chart,
            "minutes_studied": minutes_studied_chart,
            "study_per_deck": study_per_deck_chart,
        },
    }

    logger.debug("Computed user analytics for user_id=%s days=%s", user.id, days)
    return data


def get_user_analytics(user: CustomUser, days: int = 7, use_cache: bool = True) -> Dict[str, Any]:
    """Retrieve (and cache) user analytics."""
    cache_key = f"analytics:user:{user.id}:days:{days}"
    if use_cache:
        cached = cache.get(cache_key)
        if cached is not None:
            return cached

    data = compute_user_analytics(user, days=days)
    if use_cache:
        cache.set(cache_key, data, USER_ANALYTICS_TTL)
    return data


# ---------- Admin / Global analytics ----------

def compute_admin_analytics(days: int = 7, top_n_decks: int = 10) -> Dict[str, Any]:
    today = timezone.now().date()
    start_date = today - timedelta(days=days)

    total_users = CustomUser.objects.count()
    active_today = CustomUser.objects.filter(last_login__date=today).count()
    new_this_week = CustomUser.objects.filter(date_joined__gte=start_date).count()

    deck_agg = Deck.objects.aggregate(
        total=Count('id'),
        public=Count('id', filter=Q(is_public=True)),
        archived=Count('id', filter=Q(is_archived=True))
    )

    total_decks = deck_agg.get('total') or 0
    public_decks = deck_agg.get('public') or 0
    archived = deck_agg.get('archived') or 0

    sessions = QuizSession.objects.exclude(started_at__isnull=True)
    total_sessions = sessions.count()

    avg_accuracy = sessions.filter(total_answered__gt=0).aggregate(
        avg=_safe_avg_accuracy_agg(F('correct_count') * 1.0 / F('total_answered'))
    ).get('avg') or 0.0

    sessions_d = _annotate_duration(sessions)
    study_time_chart_qs = (
        sessions_d.filter(started_at__date__gte=start_date)
        .annotate(date=TruncDate('started_at'))
        .values('date')
        .annotate(total_time=Sum('duration'))
        .order_by('date')
    )
    time_studied_chart = build_chart(study_time_chart_qs, label_field='date', value_field='total_time')

    deck_activity_qs = (
        sessions_d.filter(total_answered__gt=0)
        .values('deck__id', 'deck__title')
        .annotate(
            total_sessions=Count('id'),
            total_time=Sum('duration'),
            avg_accuracy=Avg(
                ExpressionWrapper(F('correct_count') * 1.0 / F('total_answered'), output_field=FloatField()),
                filter=Q(total_answered__gt=0)
            )
        )
        .order_by('-total_sessions')[:top_n_decks]
    )
    study_per_deck_chart = []
    for entry in deck_activity_qs:
        total_time = entry.get('total_time')
        minutes = round(total_time.total_seconds() / 60, 1) if total_time else 0
        study_per_deck_chart.append({
            "deck_id": entry.get('deck__id'),
            "deck": entry.get('deck__title'),
            "sessions": entry.get('total_sessions') or 0,
            "minutes": minutes,
            "accuracy": round(entry.get('avg_accuracy') or 0, 2),
        })

    payload = {
        "users": {"total": total_users, "active_today": active_today, "new_this_week": new_this_week},
        "decks": {"total": total_decks, "public": public_decks, "archived": archived},
        "quizzes": {"total_sessions": total_sessions, "average_accuracy": round(avg_accuracy or 0, 2)},
        "charts": {"time_studied_per_day": time_studied_chart, "study_per_deck": study_per_deck_chart},
    }

    logger.debug("Computed admin analytics for days=%s top_n_decks=%s", days, top_n_decks)
    return payload


def get_admin_analytics(days: int = 7, top_n_decks: int = 10, use_cache: bool = True, use_snapshot: bool = True) -> Dict[str, Any]:
    """Return admin analytics (cached or from snapshot)."""
    today = timezone.now().date()
    cache_key = f"analytics:admin:days:{days}:top:{top_n_decks}"

    if use_snapshot:
        snap = AnalyticsSnapshot.objects.filter(name="admin_metrics", snapshot_date=today).first()
        if snap:
            logger.debug("Returning admin analytics from snapshot for %s", today)
            return snap.payload

    if use_cache:
        cached = cache.get(cache_key)
        if cached is not None:
            return cached

    payload = compute_admin_analytics(days=days, top_n_decks=top_n_decks)
    if use_cache:
        cache.set(cache_key, payload, ADMIN_ANALYTICS_TTL)
    return payload


# ---------- Snapshot helpers ----------

def generate_admin_snapshot(days: int = 7, top_n_decks: int = 10):
    """Generate and save daily admin analytics snapshot."""
    today = timezone.now().date()
    payload = compute_admin_analytics(days=days, top_n_decks=top_n_decks)
    try:
        with transaction.atomic():
            AnalyticsSnapshot.objects.update_or_create(
                name="admin_metrics",
                snapshot_date=today,
                defaults={"payload": payload},
            )
        logger.info("Saved admin analytics snapshot for %s", today)
        cache_key = f"analytics:admin:days:{days}:top:{top_n_decks}"
        cache.set(cache_key, payload, ADMIN_ANALYTICS_TTL)
    except Exception as e:
        logger.exception("Failed to save admin analytics snapshot: %s", e)
        raise


def clear_user_cache(user_id: int, days: int = 7):
    cache_key = f"analytics:user:{user_id}:days:{days}"
    cache.delete(cache_key)
