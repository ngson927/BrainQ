class FlashcardAttempt {
  final int id;
  final int flashcardId;
  bool answered;
  bool correct;
  String answerGiven;
  DateTime? answeredAt;

  FlashcardAttempt({
    required this.id,
    required this.flashcardId,
    this.answered = false,
    this.correct = false,
    this.answerGiven = '',
    this.answeredAt,
  });

  factory FlashcardAttempt.fromBackendJson(Map<String, dynamic> json) {
    return FlashcardAttempt(
      id: json['id'] ?? 0,
      flashcardId: json['flashcard'] ?? 0,
      answered: json['answered'] ?? false,
      correct: json['correct'] ?? false,
      answerGiven: json['answer_given'] ?? '',
      answeredAt: json['answered_at'] != null
          ? DateTime.tryParse(json['answered_at'])
          : null,
    );
  }

  Map<String, dynamic> toBackendJson() {
    return {
      'id': id,
      'flashcard': flashcardId,
      'answered': answered,
      'correct': correct,
      'answer_given': answerGiven,
      'answered_at': answeredAt?.toIso8601String(),
    };
  }
}
