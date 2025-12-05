import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

Future<void> requestWebNotificationPermission() async {
  final permission = await web.Notification.requestPermission().toDart;
  // ignore: unrelated_type_equality_checks
  if (permission != 'granted') {
    if (kDebugMode) {
      print('Notification permission not granted: $permission');
    }
  }
}

void showWebNotification(String title, String body) {
  if (web.Notification.permission == 'granted') {
    web.Notification(
      title,
      web.NotificationOptions(body: body),
    );
  }
}
