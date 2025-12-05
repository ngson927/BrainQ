import 'package:flutter/material.dart';
import 'package:brainq_app/services/api_service.dart';

class QuizResultsScreen extends StatefulWidget {
  final int sessionId;
  final String token;
  final int? correctCount;
  final int? totalAnswered;

  const QuizResultsScreen({
    super.key,
    required this.sessionId,
    required this.token,
    this.correctCount,
    this.totalAnswered,
  });

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  int correctCount = 0;
  int totalAnswered = 0;
  double accuracy = 0.0;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    if (widget.correctCount != null && widget.totalAnswered != null) {
      correctCount = widget.correctCount!;
      totalAnswered = widget.totalAnswered!;
      accuracy = totalAnswered > 0 ? correctCount / totalAnswered : 0.0;
      isLoading = false;
      _controller.forward();
    } else {
      _fetchResults();
    }
  }

  Future<void> _fetchResults() async {
    if (!mounted) return; 
    setState(() => isLoading = true);

    try {
      final res = await ApiService.getResults(
        sessionId: widget.sessionId,
        token: widget.token,
      );

      if (!mounted) return;

      setState(() {
        correctCount = res['correct_count'] ?? 0;
        totalAnswered = res['total_answered'] ?? 0;
        final a = (res['accuracy'] ?? 0.0).toDouble();
        accuracy = a.isFinite ? a : 0.0;
        isLoading = false;
      });

      if (mounted) _controller.forward();

    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch results: $e')),
      );
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color getAccuracyColor() {
    if (accuracy >= 0.7) return Colors.greenAccent.shade400;
    if (accuracy >= 0.4) return Colors.orangeAccent.shade200;
    return Colors.redAccent.shade200;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Quiz Results"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: theme.textTheme.bodyLarge?.color,
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(
                opacity: _animation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),

                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 160,
                            width: 160,
                            child: CircularProgressIndicator(
                              value: accuracy,
                              strokeWidth: 14,
                              backgroundColor: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                getAccuracyColor(),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${(accuracy * 100).toStringAsFixed(1)}%",
                                style: theme.textTheme.headlineMedium!.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: getAccuracyColor(),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Accuracy",
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Score",
                              style: theme.textTheme.titleLarge!.copyWith(
                                color: theme.textTheme.bodyLarge?.color
                                    ?.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "$correctCount / $totalAnswered",
                              style: theme.textTheme.headlineMedium!.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                        ),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text(
                          "Back to Deck",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

