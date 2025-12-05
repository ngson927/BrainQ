import 'package:flutter/material.dart';
import '../../models/notifications.dart';
import '../../services/api_service.dart';
import '../../api_helper.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationModel> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications({bool showSnackbar = false}) async {
    setState(() => _loading = true);
    try {
      final token = await ApiHelper.getAuthToken();
      if (token == null) return;

      final paginated = await ApiService.getNotifications(token: token);
      final fetchedNotifications = paginated.results;

      if (showSnackbar && mounted) {
        final newCount = fetchedNotifications
            .where((n) => !_notifications.any((old) => old.id == n.id))
            .length;
        if (newCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$newCount new notification(s)')),
          );
        }
      }

      if (mounted) {
        setState(() => _notifications = fetchedNotifications);
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final token = await ApiHelper.getAuthToken();
      if (token == null) return;

      await ApiService.markNotificationRead(token: token, notificationId: id);

      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == id);
          if (index != -1) _notifications[index].isRead = true;
        });
      }
    } catch (e) {
      debugPrint("Failed to mark notification read: $e");
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final token = await ApiHelper.getAuthToken();
      if (token == null) return;

      await ApiService.markAllNotificationsRead(token: token);

      if (mounted) {
        setState(() {
          for (var n in _notifications) {
            n.isRead = true;
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to mark all notifications read: $e");
    }
  }

  void _handleNotificationTap(NotificationModel notif) {
    _markAsRead(notif.id);

    final route = notif.extraData?['route'] as String?;
    final args = notif.extraData?['args'];
    if (route != null) Navigator.of(context).pushNamed(route, arguments: args);
  }

  /// Convert UTC to local time before formatting
  String _formatDate(DateTime date) =>
      DateFormat('MMM d, yyyy – h:mm a').format(date.toLocal());

  Map<String, List<NotificationModel>> _groupByDay(List<NotificationModel> list) {
    final Map<String, List<NotificationModel>> grouped = {};
    final now = DateTime.now();

    for (var notif in list) {
      final localCreatedAt = notif.createdAt.toLocal();
      final diff = now.difference(localCreatedAt);
      String key;
      if (diff.inDays == 0) {
        key = 'Today';
      } else if (diff.inDays == 1) {
        key = 'Yesterday';
      } else {
        key = DateFormat('MMM d, yyyy').format(localCreatedAt);
      }
      grouped.putIfAbsent(key, () => []).add(notif);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedNotifications = _groupByDay(_notifications);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: "Mark all as read",
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchNotifications(showSnackbar: true),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "No notifications yet 🎉",
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: groupedNotifications.entries.expand((entry) {
                      final unreadCount =
                          entry.value.where((n) => !n.isRead).length;
                      final headerText = unreadCount > 0
                          ? "${entry.key} ($unreadCount)"
                          : entry.key;

                      return [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            headerText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...entry.value.map((notif) {
                          return Dismissible(
                            key: ValueKey(notif.id),
                            direction: notif.isRead
                                ? DismissDirection.none
                                : DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              color: Colors.green,
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) => _markAsRead(notif.id),
                            child: Card(
                              color: notif.isRead
                                  ? Colors.white
                                  : Colors.blue.shade50,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              child: ListTile(
                                leading: Icon(
                                  notif.isRead
                                      ? Icons.mark_email_read
                                      : Icons.mark_email_unread,
                                  color: notif.isRead
                                      ? Colors.grey
                                      : Theme.of(context).primaryColor,
                                ),
                                title: Text(
                                  notif.verb,
                                  style: TextStyle(
                                    fontWeight: notif.isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (notif.deckTitle != null)
                                      Text(
                                        notif.deckTitle!,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    Text(
                                      _formatDate(notif.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: notif.isRead
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.check),
                                        onPressed: () => _markAsRead(notif.id),
                                      ),
                                onTap: () => _handleNotificationTap(notif),
                              ),
                            ),
                          );
                        }),
                      ];
                    }).toList(),
                  ),
      ),
    );
  }
}
