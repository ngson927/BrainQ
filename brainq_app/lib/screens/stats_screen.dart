import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../services/api_service.dart';

class Achievement {
  final String key;
  final String title;
  final String description;
  final String category;
  final bool unlocked;
  final double progress;

  Achievement({
    required this.key,
    required this.title,
    required this.description,
    required this.category,
    this.unlocked = false,
    this.progress = 0.0,
  });

  // ---------------- ICON: BADGEs ----------------
  IconData get icon {
    switch (key) {

      // 🔥 STREAKS
      case '3_day_streak':
        return Icons.play_circle_fill_rounded;      

      case '7_day_streak':
        return Icons.star_border_rounded;          

      case '14_day_streak':
        return Icons.shield_rounded;               

      case '30_day_streak':
        return Icons.auto_awesome_rounded;        

      case '50_day_streak':
        return Icons.local_fire_department_rounded;

      case '100_day_streak':
        return Icons.whatshot_rounded;            

      case 'streak_champion':
        return Icons.emoji_events_rounded;        

      // 🎯 QUIZZES
      case 'perfect_quiz_1':
        return Icons.check_circle_rounded;        

      case 'perfect_quiz_5':
        return Icons.psychology_alt_rounded;      

      case 'perfect_quiz_10':
        return Icons.workspace_premium_rounded;   

      case 'perfect_quiz_25':
        return Icons.military_tech_rounded;       

      case 'perfect_quiz_50':
        return Icons.rocket_launch_rounded;       

      case 'perfect_quiz_100':
        return Icons.public_rounded;              

      // 📚 DECKS
      case 'deck_1':
        return Icons.note_add_rounded;            

      case 'deck_5':
        return Icons.bookmark_add_rounded;        

      case 'deck_10':
        return Icons.menu_book_rounded;           

      case 'deck_25':
        return Icons.library_add_rounded;         

      case 'deck_50':
        return Icons.collections_bookmark_rounded;

      case 'deck_100':
        return Icons.account_balance_rounded;     

      default:
        return Icons.emoji_events_rounded;
    }
  }


  // ---------------- COLOR: UNIQUE PER BADGE ----------------
  Color get color {
    switch (key) {

      // 🔥 STREAKS
      case '3_day_streak':
        return const Color(0xFF64B5F6); // Light Blue

      case '7_day_streak':
        return const Color(0xFFAB47BC); // Purple

      case '14_day_streak':
        return const Color(0xFF26A69A); // Teal

      case '30_day_streak':
        return const Color(0xFF66BB6A); // Green

      case '50_day_streak':
        return const Color(0xFFFFA726); // Orange

      case '100_day_streak':
        return const Color(0xFFE53935); // Red

      case 'streak_champion':
        return const Color(0xFFD4AF37); // Gold

      // 🎯 QUIZZES
      case 'perfect_quiz_1':
        return const Color(0xFF29B6F6); 

      case 'perfect_quiz_5':
        return const Color(0xFF5C6BC0); 

      case 'perfect_quiz_10':
        return const Color(0xFF7E57C2); 

      case 'perfect_quiz_25':
        return const Color(0xFFEC407A); 

      case 'perfect_quiz_50':
        return const Color(0xFFFF7043);

      case 'perfect_quiz_100':
        return const Color(0xFF8D6E63);

      // 📚 DECKS
      case 'deck_1':
        return const Color(0xFF26C6DA);

      case 'deck_5':
        return const Color(0xFF42A5F5);

      case 'deck_10':
        return const Color(0xFF5E35B1);

      case 'deck_25':
        return const Color(0xFF43A047);

      case 'deck_50':
        return const Color(0xFFFB8C00);

      case 'deck_100':
        return const Color(0xFF6D4C41);

      default:
        return Colors.blueGrey;
    }
  }
}


class StatsScreen extends StatefulWidget {
  final String token;
  final int currentStreak;
  final int bestStreak;
  final int totalStudyDays;
  final int consecutivePerfectQuizzes;
  final int totalDecksCreated;
  final List<Map<String, dynamic>> badges;

  const StatsScreen({
    super.key,
    required this.token,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalStudyDays,
    required this.consecutivePerfectQuizzes,
    required this.totalDecksCreated,
    required this.badges,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool showAllStreaks = false;
  bool showAllQuizzes = false;
  bool showAllDecks = false;

  late int currentStreak;
  late int bestStreak;
  late int totalStudyDays;
  late int consecutivePerfectQuizzes;
  late int totalDecksCreated;
  late List<Map<String, dynamic>> badges;
  late List<Achievement> allAchievements;

  // Define all possible badges
  final List<Map<String, dynamic>> masterBadges = [
    // Streaks
    {'key': '3_day_streak', 'title': 'Getting Started', 'description': 'Study for 3 consecutive days.', 'category': 'streaks'},
    {'key': '7_day_streak', 'title': 'Week Warrior', 'description': 'Maintain a 7-day streak.', 'category': 'streaks'},
    {'key': '14_day_streak', 'title': 'Fortnight Focus', 'description': 'Keep up a 14-day streak.', 'category': 'streaks'},
    {'key': '30_day_streak', 'title': 'Month Master', 'description': 'Achieve a 30-day streak.', 'category': 'streaks'},
    {'key': '50_day_streak', 'title': 'Consistency King', 'description': 'Reach a 50-day streak.', 'category': 'streaks'},
    {'key': '100_day_streak', 'title': 'Unstoppable', 'description': 'Hit a 100-day streak!', 'category': 'streaks'},
    {'key': 'streak_champion', 'title': 'Streak Champion', 'description': 'Maintain the longest streak so far.', 'category': 'streaks'},

    // Quizzes
    {'key': 'perfect_quiz_1', 'title': 'Flawless Victory', 'description': 'Complete your first perfect quiz.', 'category': 'quizzes'},
    {'key': 'perfect_quiz_5', 'title': 'Quiz Novice', 'description': '5 consecutive perfect quizzes.', 'category': 'quizzes'},
    {'key': 'perfect_quiz_10', 'title': 'Quiz Expert', 'description': '10 consecutive perfect quizzes.', 'category': 'quizzes'},
    {'key': 'perfect_quiz_25', 'title': 'Quiz Master', 'description': '25 consecutive perfect quizzes.', 'category': 'quizzes'},
    {'key': 'perfect_quiz_50', 'title': 'Quiz Legend', 'description': '50 consecutive perfect quizzes.', 'category': 'quizzes'},
    {'key': 'perfect_quiz_100', 'title': 'Quiz Conqueror', 'description': '100 consecutive perfect quizzes!', 'category': 'quizzes'},

    // Decks
    {'key': 'deck_1', 'title': 'First Deck', 'description': 'Create your first flashcard deck.', 'category': 'decks'},
    {'key': 'deck_5', 'title': 'Deck Enthusiast', 'description': 'Create 5 decks.', 'category': 'decks'},
    {'key': 'deck_10', 'title': 'Deck Builder', 'description': 'Create 10 decks.', 'category': 'decks'},
    {'key': 'deck_25', 'title': 'Deck Architect', 'description': 'Create 25 decks.', 'category': 'decks'},
    {'key': 'deck_50', 'title': 'Deck Master', 'description': 'Create 50 decks.', 'category': 'decks'},
    {'key': 'deck_100', 'title': 'Deck Conqueror', 'description': 'Create 100 decks!', 'category': 'decks'},
  ];

  double extractNumberFromKey(String key) {
    final parts = key.split('_');
    for (int i = parts.length - 1; i >= 0; i--) {
      final number = double.tryParse(parts[i]);
      if (number != null) return number;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();

    currentStreak = widget.currentStreak;
    bestStreak = widget.bestStreak;
    totalStudyDays = widget.totalStudyDays;
    consecutivePerfectQuizzes = widget.consecutivePerfectQuizzes;
    totalDecksCreated = widget.totalDecksCreated;
    badges = widget.badges;

    _buildAchievements();
  }

  void _buildAchievements() {
    final unlockedKeys = badges.map((b) => b['key']).toSet();

    allAchievements = masterBadges.map((b) {
      final isUnlocked = unlockedKeys.contains(b['key']);
      double progress = 0.0;

      if (!isUnlocked) {
        final required = extractNumberFromKey(b['key']);

        switch (b['category']) {
          case 'streaks':
            progress = required > 0 ? (currentStreak / required).clamp(0.0, 1.0) : 0.0;
            break;
          case 'quizzes':
            progress = required > 0 ? (consecutivePerfectQuizzes / required).clamp(0.0, 1.0) : 0.0;
            break;
          case 'decks':
            progress = required > 0 ? (totalDecksCreated / required).clamp(0.0, 1.0) : 0.0;
            break;
        }
      } else {
        progress = 1.0;
      }

      return Achievement(
        key: b['key'] ?? '',
        title: b['title'] ?? '',
        description: b['description'] ?? '',
        category: b['category'] ?? '',
        unlocked: isUnlocked,
        progress: progress,
      );
    }).toList();
  }

  Future<void> _refreshStats() async {
    try {
      final data = await ApiService.getStreak(token: widget.token);

      setState(() {
        currentStreak = data['current_streak'] ?? currentStreak;
        bestStreak = data['best_streak'] ?? bestStreak;
        totalStudyDays = data['total_study_days'] ?? totalStudyDays;
        consecutivePerfectQuizzes = data['consecutive_perfect_quizzes'] ?? consecutivePerfectQuizzes;
        totalDecksCreated = data['total_decks_created'] ?? totalDecksCreated;
        badges = List<Map<String, dynamic>>.from(data['badges'] ?? badges);

        _buildAchievements();
      });
    } catch (e) {
      debugPrint("Error refreshing stats: $e");
    }
  }

  Widget buildCategory(
      String title, List<Achievement> items, bool showAll, void Function() toggleShowAll) {
    if (items.isEmpty) return const SizedBox.shrink();
    final displayed = showAll ? items : items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (items.length > 3)
              TextButton(
                onPressed: toggleShowAll,
                child: Text(showAll ? "View Less" : "View All"),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: displayed
                .map((ach) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: AnimatedAchievementBadge(
                        key: ValueKey(ach.key),
                        achievement: ach,
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final streaks = allAchievements.where((a) => a.category == "streaks").toList();
    final quizzes = allAchievements.where((a) => a.category == "quizzes").toList();
    final decks = allAchievements.where((a) => a.category == "decks").toList();

    return RefreshIndicator(
      onRefresh: _refreshStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your Streak Summary", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _StatTile(icon: Icons.local_fire_department, label: "Current Streak", value: "$currentStreak days"),
                    _StatTile(icon: Icons.workspace_premium, label: "Best Streak", value: "$bestStreak days"),
                    _StatTile(icon: Icons.calendar_month, label: "Total Study Days", value: "$totalStudyDays days"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            buildCategory("Streak Achievements", streaks, showAllStreaks, () {
              setState(() => showAllStreaks = !showAllStreaks);
            }),
            buildCategory("Quiz Achievements", quizzes, showAllQuizzes, () {
              setState(() => showAllQuizzes = !showAllQuizzes);
            }),
            buildCategory("Deck Achievements", decks, showAllDecks, () {
              setState(() => showAllDecks = !showAllDecks);
            }),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 28, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class AnimatedAchievementBadge extends StatefulWidget {
  final Achievement achievement;

  const AnimatedAchievementBadge({super.key, required this.achievement});

  @override
  State<AnimatedAchievementBadge> createState() => _AnimatedAchievementBadgeState();
}

class _AnimatedAchievementBadgeState extends State<AnimatedAchievementBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _bounce = Tween<double>(begin: 0.8, end: 1.0)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_controller);

    if (widget.achievement.unlocked) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedAchievementBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.achievement.unlocked && !oldWidget.achievement.unlocked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text(widget.achievement.title),
            content: Text(widget.achievement.description),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      },
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularPercentIndicator(
              radius: 50,
              lineWidth: 5,
              percent: widget.achievement.progress.clamp(0.0, 1.0),
              animation: true,
              progressColor: widget.achievement.unlocked
                  ? widget.achievement.color
                  : widget.achievement.color.withValues(alpha:0.3),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              center: ScaleTransition(
                scale: _bounce,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.achievement.unlocked
                        ? LinearGradient(
                            colors: [
                              widget.achievement.color.withValues(alpha:0.7),
                              widget.achievement.color.withValues(alpha:1.0),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    boxShadow: widget.achievement.unlocked
                        ? [
                            BoxShadow(
                              color: widget.achievement.color.withValues(alpha:0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    widget.achievement.icon,
                    size: 36,
                    color: widget.achievement.unlocked
                        ? Colors.white
                        : widget.achievement.color.withValues(alpha:0.3),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),
            Flexible(
              child: Text(
                widget.achievement.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.achievement.unlocked
                      ? widget.achievement.color
                      : widget.achievement.color.withValues(alpha: 0.3),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
