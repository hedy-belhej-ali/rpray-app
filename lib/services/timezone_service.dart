import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Resolves IANA timezone identifiers and converts between UTC instants and
/// the selected location's civil time. The app never substitutes a fixed UTC
/// offset for a timezone identifier.
class TimezoneService {
  TimezoneService._();

  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  static List<String> get availableTimezones {
    initialize();
    final names = tz.timeZoneDatabase.locations.keys.toList()..sort();
    return names;
  }

  static bool isValidTimezone(String? timezoneId) {
    if (timezoneId == null || timezoneId.isEmpty) return false;
    initialize();
    return tz.timeZoneDatabase.locations.containsKey(timezoneId);
  }

  static tz.Location locationFor(String timezoneId) {
    initialize();
    if (isValidTimezone(timezoneId)) return tz.getLocation(timezoneId);
    return tz.UTC;
  }

  /// The device's current IANA timezone. Falls back to UTC only when the
  /// platform cannot provide a usable identifier. The plugin call lives in
  /// `device_timezone_service.dart`; this class stays pure.
  static DateTime nowIn(String timezoneId) {
    return tz.TZDateTime.now(locationFor(timezoneId));
  }

  static DateTime convert(DateTime instant, String timezoneId) {
    return tz.TZDateTime.from(instant, locationFor(timezoneId));
  }

  static DateTime civilMidnight(String timezoneId, DateTime civilDate) {
    final location = locationFor(timezoneId);
    return tz.TZDateTime(
      location,
      civilDate.year,
      civilDate.month,
      civilDate.day,
    );
  }

  static DateTime atCivilTime(
    String timezoneId,
    DateTime civilDate,
    int hour,
    int minute, {
    int second = 0,
  }) {
    final location = locationFor(timezoneId);
    return tz.TZDateTime(
      location,
      civilDate.year,
      civilDate.month,
      civilDate.day,
      hour,
      minute,
      second,
    );
  }

  static DateTime todayAt(String timezoneId, {DateTime? now}) {
    final current = now ?? nowIn(timezoneId);
    final converted = convert(current, timezoneId);
    return tz.TZDateTime(
      locationFor(timezoneId),
      converted.year,
      converted.month,
      converted.day,
    );
  }

  static DateTime tomorrowAt(String timezoneId, {DateTime? now}) {
    final today = todayAt(timezoneId, now: now);
    return civilMidnight(
      timezoneId,
      DateTime(today.year, today.month, today.day + 1),
    );
  }

  static DateTime addCivilDays(
    String timezoneId,
    DateTime civilDate,
    int days,
  ) {
    return civilMidnight(
      timezoneId,
      DateTime(civilDate.year, civilDate.month, civilDate.day + days),
    );
  }

  static bool isSameCivilDay(DateTime a, DateTime b, String timezoneId) {
    final localA = convert(a, timezoneId);
    final localB = convert(b, timezoneId);
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  static String civilDateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String offsetLabel(DateTime value) {
    final offset = value.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final hours = abs.inHours.toString().padLeft(2, '0');
    final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  /// Human-friendly timezone label, e.g. `Africa/Tunis (UTC+01:00)`.
  static String timezoneLabel(String timezoneId) {
    if (!isValidTimezone(timezoneId)) return timezoneId;
    final now = nowIn(timezoneId);
    return '$timezoneId (${offsetLabel(now)})';
  }
}
