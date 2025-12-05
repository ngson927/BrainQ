import 'dart:async';
import 'package:flutter/services.dart';

/// Provides access to the native timezone on Android, iOS, and web.
class FlutterNativeTimezone {
  // Channel to communicate with the native plugin
  static const MethodChannel _channel =
      MethodChannel('flutter_native_timezone');

  /// Returns the local timezone ID (e.g., "America/New_York").
  static Future<String> getLocalTimezone() async {
    final String? timezone = await _channel.invokeMethod<String>("getLocalTimezone");
    if (timezone == null) {
      throw ArgumentError("Invalid return from platform getLocalTimezone()");
    }
    return timezone;
  }

  /// Returns a list of available timezones (currently just returns the local timezone).
  static Future<List<String>> getAvailableTimezones() async {
    final List<String>? timezones =
        await _channel.invokeListMethod<String>("getAvailableTimezones");
    if (timezones == null) {
      throw ArgumentError("Invalid return from platform getAvailableTimezones()");
    }
    return timezones;
  }
}
