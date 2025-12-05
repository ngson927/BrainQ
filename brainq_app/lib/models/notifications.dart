class NotificationModel {
  final String id;
  final String notifType;
  final String verb;
  final String? actorUsername;
  final String? deckTitle;
  final String deliveryChannel;
  bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? extraData;

  NotificationModel({
    required this.id,
    required this.notifType,
    required this.verb,
    this.actorUsername,
    this.deckTitle,
    required this.deliveryChannel,
    required this.isRead,
    required this.createdAt,
    this.extraData,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      notifType: json['notif_type'],
      verb: json['verb'],
      actorUsername: json['actor_username'],
      deckTitle: json['deck_title'],
      deliveryChannel: json['delivery_channel'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      extraData: json['extra_data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notif_type': notifType,
      'verb': verb,
      'actor_username': actorUsername,
      'deck_title': deckTitle,
      'delivery_channel': deliveryChannel,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'extra_data': extraData,
    };
  }
}

// Paginated response wrapper
class PaginatedNotifications {
  final int count;
  final String? next;
  final String? previous;
  final List<NotificationModel> results;

  PaginatedNotifications({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory PaginatedNotifications.fromJson(Map<String, dynamic> json) {
    return PaginatedNotifications(
      count: json['count'] ?? 0,
      next: json['next'],
      previous: json['previous'],
      results: (json['results'] as List<dynamic>)
          .map((e) => NotificationModel.fromJson(e))
          .toList(),
    );
  }
}