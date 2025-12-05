import 'dart:convert';
import 'package:brainq_app/api_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

class ReminderService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  ReminderService(this.flutterLocalNotificationsPlugin);

  // -------------------------------
  // FETCH REMINDERS
  // -------------------------------
  Future<List<ReminderModel>> fetchReminders() async {
    final token = await ApiHelper.getAuthToken();
    if (token == null) return [];

    final response = await ApiHelper.get(
      'reminders/',
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final now = DateTime.now();

      return data
          .map((e) => ReminderModel.fromJson(e))
          .where((r) {
            if (r.daysOfWeek != null && r.daysOfWeek!.isNotEmpty) return true;
            return r.remindAt.isAfter(now);
          })
          .toList();
    }

    return [];
  }

  // -------------------------------
  // CREATE REMINDER
  // -------------------------------
  Future<http.Response> createReminder(ReminderModel reminder) async {
    final token = await ApiHelper.getAuthToken();
    if (token == null) throw Exception("No auth token");

    final Map<String, dynamic> body = reminder.toJson();
    if (reminder.daysOfWeek != null && reminder.daysOfWeek!.isNotEmpty) {
      body['days_of_week'] = reminder.daysOfWeek;
    } else {
      body.remove('days_of_week');
    }

    final response = await ApiHelper.post(
      'reminders/',
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newReminder = ReminderModel.fromJson(data);
      await _scheduleNotification(newReminder);
    }

    return response;
  }

  // -------------------------------
  // UPDATE REMINDER
  // -------------------------------
  Future<http.Response> updateReminder(ReminderModel reminder) async {
    final token = await ApiHelper.getAuthToken();
    if (token == null) throw Exception("No auth token");
    if (reminder.id == null) throw Exception("Cannot update reminder without ID");

    final Map<String, dynamic> patchData = {
      'message': reminder.message,
      'remind_at': reminder.remindAt.toUtc().toIso8601String(),
      'status': reminder.status,
    };
    if (reminder.title != null) patchData['title'] = reminder.title;
    if (reminder.deckId != null) patchData['deck'] = reminder.deckId;
    if (reminder.daysOfWeek != null && reminder.daysOfWeek!.isNotEmpty) {
      patchData['days_of_week'] = reminder.daysOfWeek;
    } else {
      patchData.remove('days_of_week');
    }

    final response = await ApiHelper.patch(
      'reminders/${reminder.id}/',
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(patchData),
    );

    await cancelNotification(reminder.id!);
    await _scheduleNotification(reminder);

    return response;
  }

  // -------------------------------
  // DELETE REMINDER
  // -------------------------------
  Future<http.Response> deleteReminder(ReminderModel reminder) async {
    final token = await ApiHelper.getAuthToken();
    if (token == null) throw Exception("No auth token");

    final response = await ApiHelper.delete(
      'reminders/${reminder.id}/',
      headers: {'Authorization': 'Token $token'},
    );

    await cancelNotification(reminder.id!);

    return response;
  }

  // -------------------------------
  // SCHEDULE NOTIFICATION
  // -------------------------------
  Future<void> _scheduleNotification(ReminderModel reminder) async {
    if (reminder.id == null) return;

    final DateTime scheduleTime = (reminder.nextFireAt ?? reminder.remindAt).toLocal();
    tz.TZDateTime scheduledTZ = tz.TZDateTime.from(scheduleTime, tz.local);

    final nowTZ = tz.TZDateTime.now(tz.local);
    if (scheduledTZ.isBefore(nowTZ)) {
      scheduledTZ = nowTZ.add(const Duration(seconds: 1));
      if (kDebugMode) {
        print("Reminder time was in the past, adjusted to $scheduledTZ");
      }
    }

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Channel for study reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      reminder.id!,
      reminder.title ?? 'Study Reminder',
      reminder.message,
      scheduledTZ,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: (reminder.daysOfWeek != null && reminder.daysOfWeek!.isNotEmpty)
          ? DateTimeComponents.dayOfWeekAndTime
          : null,
      payload: reminder.id.toString(),
    );

    if (kDebugMode) {
      print("Notification scheduled for $scheduledTZ with id ${reminder.id}");
      if (reminder.daysOfWeek != null && reminder.daysOfWeek!.isNotEmpty) {
        print("Recurring on days: ${reminder.daysOfWeek}");
      }
    }
  }

  // -------------------------------
  // CANCEL NOTIFICATION
  // -------------------------------
  Future<void> cancelNotification(int reminderId) async {
    await flutterLocalNotificationsPlugin.cancel(reminderId);
  }

}
