
import uuid
from django.db import models
from django.conf import settings
from django.utils import timezone
import random




# -----------------------------
# DECK
# -----------------------------
class Deck(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="decks"
    )

    title = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    tags = models.CharField(max_length=200, blank=True, default='')

    is_public = models.BooleanField(default=False)
    is_archived = models.BooleanField(default=False)
    was_public = models.BooleanField(null=True, blank=True)

    # Moderation Fields
    is_flagged = models.BooleanField(default=False)
    flag_reason = models.TextField(blank=True, null=True)
    admin_hidden = models.BooleanField(default=False)
    admin_note = models.TextField(blank=True, null=True)

    # UI / Display Settings
    theme = models.ForeignKey(
        "DeckTheme",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="decks"
    )

    card_order = models.CharField(
        max_length=10,
        choices=[("asc", "Ascending"), ("desc", "Descending")],
        default="asc"
    )

    cover_image = models.ImageField(
        upload_to="deck_covers/",
        null=True,
        blank=True
    )


    # Sharing by Link
    is_link_shared = models.BooleanField(default=False)
    share_link = models.UUIDField(
        default=uuid.uuid4,
        unique=True,
        null=True,
        blank=True,
        editable=False,
        db_index=True
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("owner", "title")
        ordering = ["-updated_at"]
        indexes = [
            models.Index(fields=["owner"]),
            models.Index(fields=["is_public"]),
            models.Index(fields=["is_archived"]),
            models.Index(fields=["is_flagged"]),
            models.Index(fields=["admin_hidden"]),
            models.Index(fields=["share_link"]),
        ]

    def __str__(self):
        return f"{self.title} (Owner: {self.owner.username})"

    def enable_link_sharing(self):
        """Safely enable link sharing"""
        if not self.share_link:
            self.share_link = uuid.uuid4()
        self.is_link_shared = True
        self.save(update_fields=["share_link", "is_link_shared"])


    def disable_link_sharing(self):
        """Disable access via link AND invalidate old link"""
        self.is_link_shared = False
        self.share_link = uuid.uuid4()
        self.save(update_fields=["is_link_shared", "share_link"])



class DeckTheme(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="deck_themes",
        null=True,
        blank=True
    )


    name = models.CharField(max_length=120)
    description = models.TextField(blank=True)

    # Visual Styling
    background_color = models.CharField(max_length=7, default="#ffffff")
    text_color = models.CharField(max_length=7, default="#000000")
    accent_color = models.CharField(max_length=7, default="#4f46e5")

    FONT_CHOICES = [
        ("system", "System Default"),
        ("serif", "Serif"),
        ("sans", "Sans-serif"),
        ("mono", "Monospace"),
        ("dyslexic", "Dyslexic-friendly"),
    ]
    font_family = models.CharField(
        max_length=20,
        choices=FONT_CHOICES,
        default="system"
    )

    font_size = models.PositiveIntegerField(default=14)

    LAYOUT_CHOICES = [
        ("classic", "Classic"),
        ("modern", "Modern"),
        ("minimal", "Minimal"),
    ]
    layout_style = models.CharField(
        max_length=20,
        choices=LAYOUT_CHOICES,
        default="classic"
    )

    # Optional UI Settings
    border_radius = models.PositiveIntegerField(default=8)
    card_spacing = models.PositiveIntegerField(default=12)

    # Theme Metadata
    is_default = models.BooleanField(default=False)
    is_system_theme = models.BooleanField(default=False)

    preview_image = models.ImageField(
        upload_to="theme_previews/",
        null=True,
        blank=True
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("owner", "name")
        ordering = ["name"]
        indexes = [
            models.Index(fields=["owner"]),
            models.Index(fields=["is_default"]),
            models.Index(fields=["is_system_theme"]),
        ]

    def __str__(self):
        if self.owner:
            return f"{self.name} (Owner: {self.owner.username})"
        return f"{self.name} (System Theme)"



    def set_as_default(self):
        """Ensure only one default theme per user"""
        DeckTheme.objects.filter(owner=self.owner, is_default=True).update(is_default=False)
        self.is_default = True
        self.save(update_fields=["is_default"])




# -----------------------------
# FLASHCARD MODEL
# -----------------------------
class Flashcard(models.Model):
    DIFFICULTY_CHOICES = [
        ("easy", "Easy"),
        ("medium", "Medium"),
        ("hard", "Hard"),
    ]

    deck = models.ForeignKey(
        Deck,
        on_delete=models.CASCADE,
        related_name="flashcards"
    )

    question = models.TextField()
    answer = models.TextField()
    difficulty = models.CharField(
        max_length=10,
        choices=DIFFICULTY_CHOICES,
        default="medium"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]

    def __str__(self):
        return f"Flashcard for {self.deck.title}: {self.question[:50]}"


# -----------------------------
# USER SHARE PERMISSIONS
# -----------------------------
from django.db import models
from django.conf import settings

class DeckShare(models.Model):
    PERMISSION_CHOICES = (
        ('view', 'View Only'),
        ('edit', 'Can Edit'),
    )

    deck = models.ForeignKey(
        'decks.Deck',
        on_delete=models.CASCADE,
        related_name='shared_with'
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE,
        related_name='shared_decks'
    )

    permission = models.CharField(
        max_length=10,
        choices=PERMISSION_CHOICES,
        default='view'
    )

    shared_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('deck', 'user')
        indexes = [
            models.Index(fields=['deck', 'user']),
        ]

    def __str__(self):
        return f"{self.user} -> {self.deck} [{self.permission}]"



# -----------------------------
# FEEDBACK MODEL
# -----------------------------
class Feedback(models.Model):
    deck = models.ForeignKey(
        Deck,
        on_delete=models.CASCADE,
        related_name='feedbacks'
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='feedbacks'
    )

    rating = models.IntegerField()
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('deck', 'user')
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} -> {self.deck.title} ({self.rating}★)"


# -----------------------------
# QUIZ SESSION
# -----------------------------
class QuizSession(models.Model):
    MODE_CHOICES = [
        ("random", "Random"),
        ("sequential", "Sequential"),
        ("timed", "Timed"),
    ]
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    deck = models.ForeignKey(Deck, on_delete=models.CASCADE)
    mode = models.CharField(max_length=20, choices=MODE_CHOICES)
    adaptive_mode = models.BooleanField(default=True)
    srs_enabled = models.BooleanField(default=True) 
    started_at = models.DateTimeField(auto_now_add=True)
    finished_at = models.DateTimeField(null=True, blank=True)
    is_paused = models.BooleanField(default=False)
    correct_count = models.PositiveIntegerField(default=0)
    total_answered = models.PositiveIntegerField(default=0)
    current_index = models.PositiveIntegerField(default=0)
    order = models.JSONField(default=list)  
    time_per_card = models.PositiveIntegerField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "started_at"]),
            models.Index(fields=["deck", "started_at"]),
            models.Index(fields=["total_answered"]),
        ]

    # ------------------------
    # Session Initialization
    # ------------------------
    def initialize_order(self):
        """Prepare flashcards order based on mode."""
        flashcards_qs = self.deck.flashcards.all()
        if not flashcards_qs.exists():
            raise ValueError("Deck is empty") 

        if self.adaptive_mode or self.srs_enabled:
            self.order = [] 
        else:
            # Non-adaptive mode: prepare order immediately
            if self.mode in ['random', 'timed']:
                self.order = list(flashcards_qs.values_list('id', flat=True))
                random.shuffle(self.order)
            else:  # sequential
                self.order = list(flashcards_qs.order_by('created_at').values_list('id', flat=True))

        self.current_index = 0
        self.finished_at = None
        self.save()

    # ------------------------
    # Dynamic Flashcard Selection (only used if adaptive/SRS is on)
    # ------------------------
    def select_next_flashcard(self):
        if not (self.adaptive_mode or self.srs_enabled):
            return None  

        from django.utils import timezone
        now = timezone.now()
        attempted_ids = self.order
        remaining = self.deck.flashcards.exclude(id__in=attempted_ids)
        if not remaining.exists():
            return None

        due_cards = []
        new_cards = []

        for fc in remaining:
            perf = fc.user_performance.filter(user=self.user).first()
            if not perf or not self.srs_enabled:
                new_cards.append(fc)
            elif perf.next_review_due is None or perf.next_review_due <= now:
                due_cards.append((fc, perf))

        # Due cards
        if due_cards:
            weighted_pool = []
            for fc, perf in due_cards:
                weight = 1
                total = perf.correct_count + perf.incorrect_count
                if total > 0:
                    accuracy = perf.correct_count / total
                    if accuracy < 0.6: weight *= 3
                    elif accuracy < 0.85: weight *= 2
                if perf.user_difficulty == 'hard': weight *= 2
                elif perf.user_difficulty == 'easy': weight *= 0.5
                weighted_pool.extend([fc] * max(1, int(weight)))
            next_fc = random.choice(weighted_pool)

        # New cards
        elif new_cards:
            next_fc = random.choice(new_cards)

        # Fallback
        else:
            next_fc = random.choice(list(remaining))

        self.order.append(next_fc.id)
        self.save()
        return next_fc.id

    # ------------------------
    # Get Current Flashcard
    # ------------------------
    def get_current_flashcard_id(self):
        if not (self.adaptive_mode or self.srs_enabled):
            # non-adaptive mode: just return from pre-built order
            if self.current_index < len(self.order):
                return self.order[self.current_index]
            return None

        # adaptive/SRS mode
        if self.current_index < len(self.order):
            return self.order[self.current_index]
        return self.select_next_flashcard()

    # ------------------------
    # Move to Next Flashcard
    # ------------------------
    def increment_index(self):
        self.current_index += 1

        # Check for completion
        from django.utils import timezone
        if not (self.adaptive_mode or self.srs_enabled):
            if self.current_index >= len(self.order):
                self.finished_at = timezone.now()
        else:
            if self.get_current_flashcard_id() is None:
                self.finished_at = timezone.now()

        self.save()

    # ------------------------
    # Accuracy Computation
    # ------------------------
    def accuracy(self):
        if self.total_answered == 0:
            return 0.0
        return self.correct_count / self.total_answered


# -----------------------------
# QUIZ SESSION FLASHCARD
# -----------------------------
class QuizSessionFlashcard(models.Model):
    session = models.ForeignKey(
        QuizSession,
        on_delete=models.CASCADE,
        related_name='flashcard_attempts'
    )
    flashcard = models.ForeignKey(Flashcard, on_delete=models.CASCADE)
    answered = models.BooleanField(default=False)
    correct = models.BooleanField(default=False)
    answer_given = models.TextField(blank=True)
    answered_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["session", "flashcard"]),
        ]

    # -----------------------------
    # Record attempt with optional SRS/Adaptive update
    # -----------------------------
    def record_attempt(self, correct: bool, answer_text: str = "", response_time: float = None):
        from django.utils import timezone
        self.answered = True
        self.correct = correct
        self.answer_given = answer_text
        self.answered_at = timezone.now()
        self.save()

        # Only update FlashcardPerformance (adaptive/SRS)
        if self.session.adaptive_mode or self.session.srs_enabled:
            perf, _ = FlashcardPerformance.objects.get_or_create(user=self.session.user, flashcard=self.flashcard)
            perf.record_answer(correct=correct, response_time=response_time)



# -----------------------------
# USER-FLASHCARD PERFORMANCE
# -----------------------------
class FlashcardPerformance(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="flashcard_performance")
    flashcard = models.ForeignKey(Flashcard, on_delete=models.CASCADE, related_name="user_performance")

    correct_count = models.PositiveIntegerField(default=0)
    incorrect_count = models.PositiveIntegerField(default=0)
    avg_response_time = models.FloatField(default=0.0)

    DIFFICULTY_CHOICES = [('easy', 'Easy'), ('medium', 'Medium'), ('hard', 'Hard')]
    user_difficulty = models.CharField(max_length=10, choices=DIFFICULTY_CHOICES, default='medium')

    # Spaced repetition
    easiness = models.FloatField(default=2.5)
    interval = models.IntegerField(default=0)
    repetitions = models.IntegerField(default=0)
    last_reviewed = models.DateTimeField(null=True, blank=True)
    next_review_due = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ('user', 'flashcard')
        indexes = [
            models.Index(fields=["user"]),
            models.Index(fields=["flashcard"]),
            models.Index(fields=["user_difficulty"]),
            models.Index(fields=["next_review_due"]),
        ]

    # Adaptive difficulty
    def update_difficulty(self):
        total = self.correct_count + self.incorrect_count
        if total < 3:
            self.user_difficulty = "medium"
            return
        accuracy = self.correct_count / total
        if accuracy >= 0.85: self.user_difficulty = "easy"
        elif accuracy <= 0.60: self.user_difficulty = "hard"
        else:
            self.user_difficulty = "medium"

    # Spaced repetition logic
    def update_spaced_repetition(self, correct: bool):
        grade = 5 if correct else 2
        new_e = self.easiness + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02))
        self.easiness = max(1.3, new_e)
        if grade < 3:
            self.repetitions = 0
            self.interval = 1
        else:
            self.repetitions += 1
            if self.repetitions == 1:
                self.interval = 1
            elif self.repetitions == 2:
                self.interval = 6
            else:
                self.interval = int(self.interval * self.easiness)
        from django.utils import timezone
        self.last_reviewed = timezone.now()
        self.next_review_due = timezone.now() + timezone.timedelta(days=self.interval)

    def record_answer(self, correct: bool, response_time: float = None):
        if correct: self.correct_count += 1
        else: self.incorrect_count += 1

        if response_time is not None:
            prev = self.correct_count + self.incorrect_count - 1
            if prev <= 0:
                self.avg_response_time = response_time
            else:
                self.avg_response_time = ((self.avg_response_time * prev) + response_time) / (prev + 1)

        self.update_difficulty()
        self.update_spaced_repetition(correct)
        self.save()

    def __str__(self):
        return f"{self.user.username} - {self.flashcard.id} performance"
