/// Flashcard model
class Flashcard {
  int? id; // <-- unique backend ID
  String question;
  String answer;
  List<String>? options;

  /// ⚡ New field to track if the card is unsynced with backend
  bool isNew;

  Flashcard({
    this.id,
    required this.question,
    required this.answer,
    this.options,
    this.isNew = true, // default new
  });

  /// Backend JSON mapping
  Map<String, dynamic> toBackendJson() => {
        'question': question,
        'answer': answer,
        'options': options,
      };

  factory Flashcard.fromBackendJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'] as int?, // <-- map backend ID
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        options: json['options'] != null ? List<String>.from(json['options']) : null,
        isNew: false, // cards from backend are not new
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'answer': answer,
        'options': options,
        'isNew': isNew,
      };

  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(
        id: j['id'] as int?, // <-- include ID
        question: j['question'] as String? ?? '',
        answer: j['answer'] as String? ?? '',
        options: j['options'] != null ? List<String>.from(j['options']) : null,
        isNew: j['isNew'] as bool? ?? true,
      );

  Flashcard copyWith({
    int? id,
    String? question,
    String? answer,
    List<String>? options,
    bool? isNew,
  }) =>
      Flashcard(
        id: id ?? this.id,
        question: question ?? this.question,
        answer: answer ?? this.answer,
        options: options ?? this.options,
        isNew: isNew ?? this.isNew,
      );
}
