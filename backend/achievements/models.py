from django.db import models
from django.utils import timezone
from users.models import CustomUser

class Achievements(models.Model):
    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="achievements"
    )

    # ---- Streak Fields ----
    current_streak = models.IntegerField(default=0)
    best_streak = models.IntegerField(default=0)
    total_study_days = models.IntegerField(default=0)
    last_active = models.DateField(null=True, blank=True)

    # ---- Quiz & Deck Fields ----
    consecutive_perfect_quizzes = models.IntegerField(default=0)
    perfect_quiz_decks = models.JSONField(default=list, blank=True)

    # ---- Misc ----
    badges = models.JSONField(default=list, blank=True)
    break_dates = models.JSONField(default=list, blank=True)
    has_freeze = models.BooleanField(default=True)
    recovery_used = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "achievements"

    def __str__(self):
        return f"{self.user.username} achievements"

    # ------------------------
    # Main Logic
    # ------------------------

    def update_study(self, study_date=None, perfect_quiz=False, created_first_deck=False, deck_id=None):
        study_date = study_date or timezone.localdate()
        last_active = self.last_active or (study_date - timezone.timedelta(days=1))
        delta_days = (study_date - last_active).days
        created_decks_count = 1 if created_first_deck else 0

        # Temporary list for newly earned badges
        self._new_badges = []

        # ---- Handle missed days ----
        if delta_days == 1:
            # Normal streak continuation
            self.current_streak += 1
        elif delta_days == 2:
            if self.has_freeze:
                # Use freeze to maintain streak
                self.has_freeze = False
                self.recovery_used = True
                self.current_streak += 1
                self.break_dates.append((last_active + timezone.timedelta(days=1)).isoformat())
            else:
                # No freeze → streak breaks
                self.current_streak = 0
                self.consecutive_perfect_quizzes = 0
                for i in range(1, delta_days):
                    self.break_dates.append((last_active + timezone.timedelta(days=i)).isoformat())
        elif delta_days > 2:
            # Missed more than 2 days → streak breaks
            self.current_streak = 0
            self.consecutive_perfect_quizzes = 0
            self.has_freeze = False
            self.recovery_used = False
            for i in range(1, delta_days):
                self.break_dates.append((last_active + timezone.timedelta(days=i)).isoformat())
        else:
            # delta_days == 0 → same day study, do nothing
            pass

        # ---- Count a new study day ----
        if self.last_active != study_date:
            self.total_study_days += 1
        self.last_active = study_date

        # ---- Check perfect quiz updates ----
        new_perfect_deck = False
        if perfect_quiz and deck_id and deck_id not in self.perfect_quiz_decks:
            self.perfect_quiz_decks.append(deck_id)
            new_perfect_deck = True

        if new_perfect_deck:
            self.consecutive_perfect_quizzes += 1
        elif perfect_quiz:
            pass  # already perfected deck → ignore
        else:
            self.consecutive_perfect_quizzes = 0

        # ---- Update best streak ----
        if self.current_streak > self.best_streak:
            self.best_streak = self.current_streak

        # ---- Regain freeze every 14 days ----
        if self.current_streak > 0 and self.current_streak % 14 == 0:
            self.has_freeze = True

        # ---- Award badges & track new ones ----
        self.check_badges(perfect_quiz=new_perfect_deck, created_decks_count=created_decks_count)
        self.save()



    # ------------------------
    # Badges / Achievements
    # ------------------------
    def check_badges(self, perfect_quiz=False, created_decks_count=0):
        """Award badges for milestones and track newly earned ones."""

        # ----- Streak Milestones -----
        streak_milestones = {
            3: {"name": "Getting Started", "description": "Study for 3 consecutive days."},
            7: {"name": "Week Warrior", "description": "Maintain a 7-day streak."},
            14: {"name": "Fortnight Focus", "description": "Keep up a 14-day streak."},
            30: {"name": "Month Master", "description": "Achieve a 30-day streak."},
            50: {"name": "Consistency King", "description": "Reach a 50-day streak."},
            100: {"name": "Unstoppable", "description": "Hit a 100-day streak!"}
        }
        for days, info in streak_milestones.items():
            key = f"{days}_day_streak"
            if self.current_streak >= days and key not in [b["key"] for b in self.badges if isinstance(b, dict)]:
                badge = {
                    "key": key,
                    "name": info["name"],
                    "description": info["description"],
                    "category": "streaks"
                }
                self.badges.append(badge)
                self._new_badges.append(badge)

        # ----- Longest Streak -----
        if self.best_streak >= 7 and "streak_champion" not in [b["key"] for b in self.badges if isinstance(b, dict)]:
            badge = {
                "key": "streak_champion",
                "name": "Streak Champion",
                "description": "Maintain the longest streak so far.",
                "category": "streaks"
            }
            self.badges.append(badge)
            self._new_badges.append(badge)

        # ----- Perfect Quiz Milestones -----
        quiz_milestones = {
            1: {"name": "Flawless Victory", "description": "Complete your first perfect quiz."},
            5: {"name": "Quiz Novice", "description": "5 consecutive perfect quizzes."},
            10: {"name": "Quiz Expert", "description": "10 consecutive perfect quizzes."},
            25: {"name": "Quiz Master", "description": "25 consecutive perfect quizzes."},
            50: {"name": "Quiz Legend", "description": "50 consecutive perfect quizzes."},
            100: {"name": "Quiz Conqueror", "description": "100 consecutive perfect quizzes!"}
        }
        if perfect_quiz:
            for milestone, info in quiz_milestones.items():
                key = f"perfect_quiz_{milestone}"
                if self.consecutive_perfect_quizzes >= milestone and key not in [b["key"] for b in self.badges if isinstance(b, dict)]:
                    badge = {
                        "key": key,
                        "name": info["name"],
                        "description": info["description"],
                        "category": "quizzes"
                    }
                    self.badges.append(badge)
                    self._new_badges.append(badge)

        # ----- Deck Creation Milestones -----
        deck_milestones = {
            1: {"name": "First Deck", "description": "Create your first flashcard deck."},
            5: {"name": "Deck Enthusiast", "description": "Create 5 decks."},
            10: {"name": "Deck Builder", "description": "Create 10 decks."},
            25: {"name": "Deck Architect", "description": "Create 25 decks."},
            50: {"name": "Deck Master", "description": "Create 50 decks."},
            100: {"name": "Deck Conqueror", "description": "Create 100 decks!"}
        }
        for milestone, info in deck_milestones.items():
            key = f"deck_{milestone}"
            if created_decks_count >= milestone and key not in [b["key"] for b in self.badges if isinstance(b, dict)]:
                badge = {
                    "key": key,
                    "name": info["name"],
                    "description": info["description"],
                    "category": "decks"
                }
                self.badges.append(badge)
                self._new_badges.append(badge)

    # ------------------------
    # Newly earned badges helper
    # ------------------------
    def get_new_badges(self):
        return getattr(self, "_new_badges", [])

    # ------------------------
    # Resets / Recovery
    # ------------------------
    def reset_streak(self, break_date=None):
        break_date = break_date or timezone.localdate()
        self.break_dates.append(break_date.isoformat())
        self.current_streak = 0
        self.consecutive_perfect_quizzes = 0
        self.recovery_used = False
        self.has_freeze = False
        self.save()

    def recover_streak(self):
        if not self.recovery_used and self.break_dates:
            self.current_streak = self.best_streak
            self.recovery_used = True
            self.save()