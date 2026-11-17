import 'package:flutter_timezone/flutter_timezone.dart';

import 'timezone_service.dart';

/// Platform-facing timezone lookup, kept separate from the pure conversion
/// helpers so prayer calculation and scheduling remain testable without a
/// Flutter engine or a native compiler.
abstract final class DeviceTimezoneService {
  static Future<String> deviceTimezoneId() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      if (TimezoneService.isValidTimezone(info.identifier)) {
        return info.identifier;
      }
    } catch (_) {
      // Plugin unavailable (e.g. unsupported desktop target).
    }
    return 'UTC';
  }
}
