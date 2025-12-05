import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'dart:js_interop';


class FlutterNativeTimezoneWeb {
  /// Registers the plugin with the Flutter web engine.
  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'flutter_native_timezone',
      const StandardMethodCodec(),
    );

    final instance = FlutterNativeTimezoneWeb();
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  /// Handles method calls from the Dart layer
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getLocalTimezone':
        return _getLocalTimezone();
      case 'getAvailableTimezones':
        return [_getLocalTimezone()];
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: "Method '${call.method}' not implemented on web plugin",
        );
    }
  }

  /// Returns the local timezone via JS interop
  String _getLocalTimezone() {
    return jsDateTimeFormat().resolvedOptions().timeZone;
  }
}

/// JS interop for Intl.DateTimeFormat
@JS('Intl.DateTimeFormat')
external JSDateTimeFormat jsDateTimeFormat();

@JS()
abstract class JSDateTimeFormat {
  @JS()
  external JSResolvedOptions resolvedOptions();
}

@JS()
abstract class JSResolvedOptions {
  @JS()
  external String get timeZone;
}
