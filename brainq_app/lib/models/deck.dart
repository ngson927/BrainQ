import 'dart:io';

class Deck {
  final String id;
  final String title;
  final int cards;
  final String? ownerId;
  final bool isPublic;
  final bool archived;
  final String? cardOrder;
  final Map<String, dynamic>? theme;

  
  final String? coverImageUrl;
  final File? coverImageFile;

  Deck({
    required this.id,
    required this.title,
    required this.cards,
    this.ownerId,
    this.isPublic = false,
    this.archived = false,
    this.cardOrder,
    this.theme,
    this.coverImageUrl,
    this.coverImageFile,
  });


  // =========================
  // JSON factory for backend
  // =========================
  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
        id: json['id'].toString(),
        title: json['title'] ?? '',
        cards: json['cards_count'] ?? 0,
        ownerId: json['owner_id']?.toString(),
        isPublic: json['is_public'] ?? false,
        archived: json['is_archived'] ?? false,
        cardOrder: json['card_order'],
        theme: json['theme'] != null
            ? Map<String, dynamic>.from(json['theme'])
            : null,
        coverImageUrl: json['cover_image'],
      );

  // =========================
  // Convert to JSON for backend or local cache
  // =========================
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cards_count': cards,
        'owner_id': ownerId,
        'is_public': isPublic,
        'is_archived': archived,
        'card_order': cardOrder,
        'theme': theme,
        'cover_image': coverImageUrl,
      };


  dynamic get activeCoverImage => coverImageFile ?? coverImageUrl;
}

class SharedUser {
  final String username;
  String permission; // mutable

  SharedUser({required this.username, required this.permission});

  factory SharedUser.fromJson(Map<String, dynamic> json) => SharedUser(
        username: json['username'] ?? '',
        permission: json['permission'] ?? 'view',
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'permission': permission,
      };
}
