import 'flashcard.dart';
import 'deck.dart';

class DeckItem {
  final int id; // <-- changed to int
  final String title;
  final String description;
  final List<String> tags;
  final String? ownerId;
  final bool isPublic;
  final List<Flashcard> cards;
  final DateTime createdAt;
  bool recentlyUsed;

  DeckItem({
    required this.title,
    this.description = '',
    this.tags = const [],
    this.ownerId,
    this.isPublic = false,
    this.cards = const [],
    this.recentlyUsed = false,
    int? id,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch, // <-- int now
        createdAt = createdAt ?? DateTime.now();

  int get cardCount => cards.length;
  double get progress => 0.0;

  Deck toDeckModel() => Deck(
        id: id.toString(), // Deck model might still use String id
        title: title,
        cards: cardCount,
      );

  DeckItem copyWith({
    int? id,
    String? title,
    String? description,
    List<String>? tags,
    String? ownerId,
    bool? isPublic,
    List<Flashcard>? cards,
    bool? recentlyUsed,
    DateTime? createdAt,
  }) {
    return DeckItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? List.from(this.tags),
      ownerId: ownerId ?? this.ownerId,
      isPublic: isPublic ?? this.isPublic,
      cards: cards ?? List.from(this.cards),
      recentlyUsed: recentlyUsed ?? this.recentlyUsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Map to backend JSON for POST or PATCH requests
  Map<String, dynamic> toBackendJson() => {
        'title': title,
        'description': description,
        'tags': tags,
        'is_public': isPublic,
        'cards': cards.map((c) => c.toBackendJson()).toList(),
      };

  /// Factory to parse backend JSON
  factory DeckItem.fromBackendJson(Map<String, dynamic> json) => DeckItem(
    id: json['id'] is int
        ? json['id']
        : int.tryParse(json['id']?.toString() ?? '') ?? 0,
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    tags: List<String>.from(json['tags'] ?? []),
    ownerId: json['owner_id']?.toString(),  // <- THIS MUST MATCH BACKEND
    isPublic: json['is_public'] ?? false,
    recentlyUsed: json['recently_used'] ?? false,
    cards: (json['flashcards'] as List<dynamic>?)
            ?.map((c) => Flashcard.fromBackendJson(c))
            .toList() ?? [],
    createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
  );


  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'tags': tags,
        'ownerId': ownerId,
        'isPublic': isPublic,
        'recentlyUsed': recentlyUsed,
        'createdAt': createdAt.toIso8601String(),
        'cards': cards.map((c) => c.toJson()).toList(),
      };

  factory DeckItem.fromJson(Map<String, dynamic> json) => DeckItem(
        id: json['id'] is int
            ? json['id']
            : int.tryParse(json['id']?.toString() ?? '') ?? 0,
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        tags: List<String>.from(json['tags'] ?? []),
        ownerId: json['ownerId']?.toString(),
        isPublic: json['isPublic'] ?? false,
        recentlyUsed: json['recentlyUsed'] ?? false,
        cards: (json['cards'] as List<dynamic>?)
                ?.map((c) => Flashcard.fromJson(c))
                .toList() ??
            [],
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}
