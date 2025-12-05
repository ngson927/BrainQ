import 'package:brainq_app/models/flashcard_attempt.dart';

class QuizSession {
  final int id;
  final int deckId;
  final String mode;
  int currentIndex;
  List<int> order;
  List<FlashcardAttempt> attempts;
  double accuracy;
  String? currentQuestion;

  QuizSession({
    required this.id,
    required this.deckId,
    required this.mode,
    this.currentIndex = 0,
    this.order = const [],
    this.attempts = const [],
    this.accuracy = 0.0,
    this.currentQuestion,
  });

  factory QuizSession.fromBackendJson(Map<String, dynamic> json) {
    // Detect if wrapped or not
    final sessionJson = json.containsKey('session') ? json['session'] : json;

    return QuizSession(
      id: sessionJson['id'],
      deckId: sessionJson['deck'],
      mode: sessionJson['mode'] ?? 'random',
      currentIndex: sessionJson['current_index'] ?? 0,
      order: List<int>.from(sessionJson['order'] ?? []),
      attempts: (sessionJson['flashcard_attempts'] as List<dynamic>? ?? [])
          .map((e) => FlashcardAttempt.fromBackendJson(e))
          .toList(),
      accuracy: (sessionJson['accuracy'] ?? 0.0).toDouble(),
      currentQuestion: json['question'] as String?, // only present in start/resume
    );
  }

  QuizSession copyWith({
    double? accuracy,
    String? currentQuestion,
    int? currentIndex,
  }) {
    return QuizSession(
      id: id,
      deckId: deckId,
      mode: mode,
      currentIndex: currentIndex ?? this.currentIndex,
      order: order,
      attempts: attempts,
      accuracy: accuracy ?? this.accuracy,
      currentQuestion: currentQuestion ?? this.currentQuestion,
    );
  }
}
