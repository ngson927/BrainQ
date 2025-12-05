class Flashcard {
  int? id;
  String question;
  String answer;
  String difficulty;
  List<String>? options;
  bool isNew;

  Flashcard({
    this.id,
    required this.question,
    required this.answer,
    this.difficulty = 'medium',
    this.options,
    this.isNew = true,
  });

  /// Backend JSON mapping for POST/PATCH
  Map<String, dynamic> toBackendJson() {
    final Map<String, dynamic> data = {
      'question': question,
      'answer': answer,
      'difficulty': difficulty,
    };

    if (options != null && options!.isNotEmpty) {
      data['options'] = options;
    }

    if (id != null) {
      data['id'] = id;
    }

    return data;
  }

  factory Flashcard.fromBackendJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'] as int?,
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        difficulty: json['difficulty'] as String? ?? 'medium',
        options: json['options'] != null ? List<String>.from(json['options']) : null,
        isNew: false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'answer': answer,
        'difficulty': difficulty,
        'options': options,
        'isNew': isNew,
      };

  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(
        id: j['id'] as int?,
        question: j['question'] as String? ?? '',
        answer: j['answer'] as String? ?? '',
        difficulty: j['difficulty'] as String? ?? 'medium',
        options: j['options'] != null ? List<String>.from(j['options']) : null,
        isNew: j['isNew'] as bool? ?? true,
      );

  Flashcard copyWith({
    int? id,
    String? question,
    String? answer,
    String? difficulty,
    List<String>? options,
    bool? isNew,
  }) =>
      Flashcard(
        id: id ?? this.id,
        question: question ?? this.question,
        answer: answer ?? this.answer,
        difficulty: difficulty ?? this.difficulty,
        options: options ?? this.options,
        isNew: isNew ?? this.isNew,
      );
}
