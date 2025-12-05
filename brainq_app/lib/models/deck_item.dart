import 'dart:io';
import 'deck.dart';
import 'deck_theme.dart';
import 'flashcard.dart';

class DeckItem {
  final int id;
  final String title;
  final String description;
  final List<String> tags;
  final String? ownerId;
  final bool isPublic;
  final List<Flashcard> cards;
  final DateTime createdAt;

  bool recentlyUsed;
  bool? isArchived;

  
  final String? coverImageUrl;
  final File? coverImageFile;

  final DeckTheme? theme;
  final String? cardOrder;

  bool? isLinkShared;
  String? shareLink;
  List<SharedUser>? sharedUsers;
  bool? canEdit;
  String? accessLevel;

  DeckItem({
    required this.id,
    required this.title,
    this.description = '',
    List<String> tags = const [],
    this.ownerId,
    this.isPublic = false,
    this.cards = const [],
    this.recentlyUsed = false,
    this.isArchived = false,
    this.coverImageUrl,
    this.coverImageFile,
    this.theme,
    this.cardOrder,
    this.isLinkShared,
    this.shareLink,
    this.sharedUsers,
    this.canEdit,
    this.accessLevel,
    DateTime? createdAt,
    })  : tags = tags.map((t) => t.toString()).toList(),
          createdAt = createdAt ?? DateTime.now();

  bool get archived => isArchived ?? false;
  int get cardCount => cards.length;
  double get progress => 0.0;
  String? get fullCoverImageUrl {
    if (coverImageUrl == null || coverImageUrl!.isEmpty) return null;
    if (coverImageUrl!.startsWith("http")) return coverImageUrl;
    return "http://127.0.0.1:8000/media/deck_covers/$coverImageUrl";
    
  }


  dynamic get activeCoverImage => coverImageFile ?? coverImageUrl;

  Deck toDeckModel() => Deck(
        id: id.toString(),
        title: title,
        cards: cardCount,
        ownerId: ownerId,
        isPublic: isPublic,
        archived: archived,
        cardOrder: cardOrder,
        theme: theme?.toJson(),
        coverImageUrl: coverImageUrl,
        coverImageFile: coverImageFile,
      );

  // =========================
  // Copy with
  // =========================
  DeckItem copyWith({
    int? id,
    String? title,
    String? description,
    List<String>? tags,
    String? ownerId,
    bool? isPublic,
    List<Flashcard>? cards,
    bool? recentlyUsed,
    bool? isArchived,
    String? coverImageUrl,
    File? coverImageFile,
    DeckTheme? theme,
    String? cardOrder,
    bool? isLinkShared,
    String? shareLink,
    List<SharedUser>? sharedUsers,
    bool? canEdit,
    String? accessLevel,
    DateTime? createdAt,
  }) {
    return DeckItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: (tags ?? this.tags).map((t) => t.toString()).toList(),
      ownerId: ownerId ?? this.ownerId,
      isPublic: isPublic ?? this.isPublic,
      cards: cards ?? List.from(this.cards),
      recentlyUsed: recentlyUsed ?? this.recentlyUsed,
      isArchived: isArchived ?? this.isArchived,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      coverImageFile: coverImageFile ?? this.coverImageFile,
      theme: theme ?? this.theme,
      cardOrder: cardOrder ?? this.cardOrder,
      isLinkShared: isLinkShared ?? this.isLinkShared,
      shareLink: shareLink ?? this.shareLink,
      sharedUsers: sharedUsers ?? this.sharedUsers,
      canEdit: canEdit ?? this.canEdit,
      accessLevel: accessLevel ?? this.accessLevel,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // =========================
  // Backend JSON parsing
  // =========================
  factory DeckItem.fromBackendJson(Map<String, dynamic> json) {
    return DeckItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      tags: (json['tags'] as List<dynamic>? ?? [])
          .where((t) => t != null)
          .map((t) => t.toString())
          .toList(),
      ownerId: (json['owner_id'] ?? json['owner'])?.toString(),
      isPublic: json['is_public'] ?? false,
      isArchived: json['is_archived'] ?? false,
      recentlyUsed: json['recently_used'] ?? false,
      coverImageUrl: json['cover_image'],
      cardOrder: json['card_order'],
      theme: json['theme'] != null ? DeckTheme.fromJson(json['theme']) : null,
      cards: (json['flashcards'] as List<dynamic>? ?? [])
          .map((c) => Flashcard.fromBackendJson(c))
          .toList(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isLinkShared: json['is_link_shared'],
      shareLink: json['share_link'],
      canEdit: json['can_edit'],
      accessLevel: json['access_level'],
      sharedUsers: (json['shared_users'] as List<dynamic>? ?? [])
          .map((u) => SharedUser.fromJson(u))
          .toList(),
    );
  }

  // =========================
  // Backend JSON for API requests
  // =========================
  Map<String, dynamic> toBackendJson({bool includeEmptyLists = true}) {
    final Map<String, dynamic> map = {
      'title': title,
      'description': description,
      'is_public': isPublic,
      'is_archived': isArchived ?? false,
      'card_order': cardOrder,
      'theme': theme?.toJson(),
    };

    if (cards.isNotEmpty || includeEmptyLists) {
      map['flashcards'] = cards.map((c) => c.toJson()).toList();
    }

    if (tags.isNotEmpty || includeEmptyLists) {
      map['tags'] = tags.map((t) => t.toString()).toList();
    }


    // cover_image is handled separately by MultipartRequest
    if (coverImageUrl != null) map['cover_image'] = coverImageUrl;

    return map;
  }

  // =========================
  // Local JSON for cache
  // =========================
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'tags': tags,
        'ownerId': ownerId,
        'isPublic': isPublic,
        'isArchived': isArchived,
        'recentlyUsed': recentlyUsed,
        'createdAt': createdAt.toIso8601String(),
        'coverImageUrl': coverImageUrl,
        'cardOrder': cardOrder,
        'theme': theme?.toJson(),
        'cards': cards.map((c) => c.toJson()).toList(),
        'isLinkShared': isLinkShared,
        'shareLink': shareLink,
        'sharedUsers': sharedUsers?.map((u) => u.toJson()).toList(),
      };

  factory DeckItem.fromJson(Map<String, dynamic> json) => DeckItem(
        id: json['id'],
        title: json['title'],
        description: json['description'] ?? '',
        tags: (json['tags'] as List<dynamic>? ?? [])
            .where((t) => t != null)
            .map((t) => t.toString())
            .toList(),
        ownerId: json['ownerId']?.toString(),
        isPublic: json['isPublic'] ?? false,
        isArchived: json['isArchived'] ?? false,
        recentlyUsed: json['recentlyUsed'] ?? false,
        coverImageUrl: json['coverImageUrl'],
        cardOrder: json['cardOrder'],
        theme: json['theme'] != null ? DeckTheme.fromJson(json['theme']) : null,
        cards: (json['cards'] as List<dynamic>? ?? [])
            .map((c) => Flashcard.fromJson(c))
            .toList(),
        createdAt:
            DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        isLinkShared: json['isLinkShared'],
        shareLink: json['shareLink'],
        sharedUsers: (json['sharedUsers'] as List<dynamic>? ?? [])
            .map((u) => SharedUser.fromJson(u))
            .toList(),
      );

  // =========================
  // Share URL
  // =========================
  String? get shareUrl {
    if (shareLink == null || !(isLinkShared ?? false)) return null;
    return 'http://127.0.0.1:8000/decks/share/$shareLink/';
  }
}
