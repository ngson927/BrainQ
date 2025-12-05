import 'package:flutter_native_timezone/flutter_native_timezone.dart';

Future<String> getLocalTimezone() async {
  return await FlutterNativeTimezone.getLocalTimezone();
}
