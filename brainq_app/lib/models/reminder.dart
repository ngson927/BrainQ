class ReminderModel {
  final int? id;
  final String? title;
  final String message;
  final int? deckId;
  final DateTime remindAt;
  final List<String>? daysOfWeek;
  final DateTime? nextFireAt;
  final String status;

  ReminderModel({
    this.id,
    this.title,
    required this.message,
    this.deckId,
    required this.remindAt,
    this.daysOfWeek,
    this.nextFireAt,
    required this.status,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      deckId: json['deck'],
      remindAt: DateTime.parse(
        json['remind_at_local'] ?? json['remind_at'],
      ).toLocal(),
      nextFireAt: json['next_fire_at'] != null
          ? DateTime.parse(json['next_fire_at']).toLocal()
          : null,
      daysOfWeek: (json['days_of_week'] == null || (json['days_of_week'] as List).isEmpty)
          ? null
          : List<String>.from(json['days_of_week']),
      status: json['status'] ?? "active",
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      "title": title,
      "message": message,
      "deck": deckId,
      "remind_at": remindAt.toUtc().toIso8601String(),
      "status": status,
    };

    if (daysOfWeek != null && daysOfWeek!.isNotEmpty) {
      map['days_of_week'] = daysOfWeek;
    }

    return map;
  }
}
