import 'package:flutter/material.dart';

/// Simple model for achievement
class Achievement {
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;

  Achievement({
    required this.title,
    required this.description,
    required this.icon,
    this.unlocked = false,
  });
}

/// StatsScreen ready to plug backend logic
class StatsScreen extends StatelessWidget {
  final int totalDecksStudied;
  final int totalCardsStudied;
  final Duration totalStudyTime;
  final double quizAccuracy; // 0.0 - 1.0
  final List<Achievement> achievements;

  const StatsScreen({
    super.key,
    required this.totalDecksStudied,
    required this.totalCardsStudied,
    required this.totalStudyTime,
    required this.quizAccuracy,
    required this.achievements,
  });

  String get formattedTime {
    final hours = totalStudyTime.inHours;
    final minutes = totalStudyTime.inMinutes.remainder(60);
    return "${hours}h ${minutes}m";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Stats & Achievements'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _StatTile(
                      icon: Icons.menu_book,
                      label: 'Decks Studied',
                      value: totalDecksStudied.toString(),
                    ),
                    _StatTile(
                      icon: Icons.layers,
                      label: 'Cards Studied',
                      value: totalCardsStudied.toString(),
                    ),
                    _StatTile(
                      icon: Icons.timer,
                      label: 'Total Time',
                      value: formattedTime,
                    ),
                    _StatTile(
                      icon: Icons.bar_chart,
                      label: 'Quiz Accuracy',
                      value: "${(quizAccuracy * 100).toStringAsFixed(0)}%",
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text('Achievements', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: achievements.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final ach = achievements[index];
                return AchievementWidget(achievement: ach);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Small reusable stat tile
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
          Expanded(
            child: Text(label, style: theme.textTheme.bodyLarge),
          ),
          Text(value,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Achievement widget
class AchievementWidget extends StatelessWidget {
  final Achievement achievement;

  const AchievementWidget({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: achievement.unlocked
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              achievement.icon,
              size: 36,
              color: achievement.unlocked
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              achievement.title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
