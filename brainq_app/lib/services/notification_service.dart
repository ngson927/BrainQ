import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'timezone_service.dart';

// Web notifications
import 'web_notification_stub.dart'
    if (dart.library.html) 'web_notification_real.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final Map<int, Timer> _webTimers = {};
  GlobalKey<NavigatorState>? navigatorKey;

  // --------------------------------------
  // INIT
  // --------------------------------------
  Future<void> init() async {
    if (kIsWeb) {
      await requestWebNotificationPermission();
      debugPrint("🌐 Web notifications enabled");
      return;
    }

    // Initialize timezones
    try {
      tz.initializeTimeZones();
      final tzName = await getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation("UTC"));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        final navigator = navigatorKey?.currentState;

        if (payload != null && navigator != null) {
          try {
            final data = jsonDecode(payload);
            final type = data['type'] ?? 'reminder';

            switch (type) {
              case 'reminder':
                navigator.pushNamed('/reminders', arguments: data);
                break;
              case 'ai_deck_ready':
                navigator.pushNamed('/deck_detail', arguments: data['deck_id']);
                break;
              case 'badge':
                navigator.pushNamed('/badges', arguments: data);
                break;
              default:
                navigator.pushNamed('/notifications', arguments: data);
            }
          } catch (_) {
            navigator.pushNamed('/notifications', arguments: payload);
          }
        }
      },
    );

    if (Platform.isAndroid) {
      await _ensureAndroidNotificationPermission();
      await _requestExactAlarmsPermission();
    }
  }

  // --------------------------------------
  // ANDROID PERMISSION HELPERS
  // --------------------------------------
  Future<void> _ensureAndroidNotificationPermission() async {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<void> _requestExactAlarmsPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    try {
      await androidPlugin.requestExactAlarmsPermission();
    } catch (_) {}
  }

  // --------------------------------------
  // SHOW IMMEDIATE
  // --------------------------------------
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    required int id,
    String type = 'reminder',
  }) async {
    if (kIsWeb) {
      showWebNotification(title, body);
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      type == 'reminder' ? 'reminder_channel' : 'notification_channel',
      type == 'reminder' ? 'Reminders' : 'Notifications',
      channelDescription: type == 'reminder'
          ? 'Reminder notifications'
          : 'Event-driven notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    final notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(id, title, body, notifDetails, payload: payload);
  }

  // --------------------------------------
  // SCHEDULE
  // --------------------------------------
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTimeLocal,
    String? payload,
    String type = 'reminder',
  }) async {
    if (kIsWeb) {
      _scheduleWebNotification(id, title, body, scheduledTimeLocal);
      return;
    }

    final tzTime = tz.TZDateTime.from(scheduledTimeLocal, tz.local);

    final androidDetails = AndroidNotificationDetails(
      type == 'reminder' ? 'reminder_channel' : 'notification_channel',
      type == 'reminder' ? 'Reminders' : 'Notifications',
      channelDescription: type == 'reminder'
          ? 'Reminder notifications'
          : 'Event-driven notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  // --------------------------------------
  // WEB SCHEDULING
  // --------------------------------------
  void _scheduleWebNotification(
    int id,
    String title,
    String body,
    DateTime scheduledTime,
  ) {
    _webTimers[id]?.cancel();

    final delay = scheduledTime.difference(DateTime.now());
    if (delay.isNegative) {
      showWebNotification(title, body);
      return;
    }

    _webTimers[id] = Timer(delay, () {
      showWebNotification(title, body);
      _webTimers.remove(id);
    });
  }

  // --------------------------------------
  // CANCEL
  // --------------------------------------
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) {
      _webTimers[id]?.cancel();
      _webTimers.remove(id);
      return;
    }
    await _plugin.cancel(id);
  }

  FlutterLocalNotificationsPlugin get flutterLocalNotificationsPlugin =>
      _plugin;
}
