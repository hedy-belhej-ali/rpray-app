/// Stable 31-bit notification identifiers. Deterministic IDs mean reopening
/// the app can safely replace its own notifications without duplicates.
class NotificationIds {
  NotificationIds._();

  static const int _reminderBase = 100000000;
  static const int _adhanBase = 200000000;
  static const int _eventBase = 300000000;
  static const int testId = 999999;

  static int _dayIndex(DateTime localDate) {
    final epochDay = DateTime.utc(
      localDate.year,
      localDate.month,
      localDate.day,
    ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return epochDay % 9000;
  }

  static int reminder({
    required DateTime prayerDay,
    required int prayerIndex,
    required int minutesBefore,
  }) {
    final intervalIndex = const <int>[5, 10, 15, 20, 25, 30]
        .indexOf(minutesBefore);
    assert(intervalIndex >= 0, 'Unsupported reminder interval');
    return _reminderBase +
        _dayIndex(prayerDay) * 100 +
        prayerIndex * 10 +
        (intervalIndex < 0 ? 0 : intervalIndex);
  }

  static int adhan({
    required DateTime prayerDay,
    required int prayerIndex,
  }) =>
      _adhanBase + _dayIndex(prayerDay) * 10 + prayerIndex;

  /// Event IDs are derived from the stable event key. Masking to 31 bits keeps
  /// them valid on Android and iOS.
  static int event(String key) {
    var hash = 0x811C9DC5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return _eventBase + (hash % 100000000);
  }
}
