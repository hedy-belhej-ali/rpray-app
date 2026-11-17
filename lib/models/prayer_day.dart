import 'prayer_name.dart';
import 'prayer_settings.dart';

class PrayerTimeEntry {
  const PrayerTimeEntry({
    required this.prayer,
    required this.calculated,
    required this.adjusted,
  });

  final PrayerName prayer;
  final DateTime calculated;
  final DateTime adjusted;

  int get adjustmentMinutes => adjusted.difference(calculated).inMinutes;

  bool get isAdjusted => adjustmentMinutes != 0;
}

/// The full result of one local day's calculation, including per-prayer user
/// adjustments, validation warnings, and whether a high-latitude fallback was
/// needed.
class PrayerDay {
  PrayerDay({
    required this.localDate,
    required this.location,
    required this.config,
    required Map<PrayerName, PrayerTimeEntry> entries,
    required this.sunrise,
    required this.calculatedAt,
    this.warnings = const <String>[],
    this.highLatitudeFallbackApplied = false,
    this.isValid = true,
  }) : entries = Map<PrayerName, PrayerTimeEntry>.unmodifiable(entries);

  /// Midnight of the Gregorian date the times belong to, in the location's
  /// timezone.
  final DateTime localDate;
  final GeoLocation location;
  final CalculationConfig config;
  final Map<PrayerName, PrayerTimeEntry> entries;
  final DateTime sunrise;
  final DateTime calculatedAt;
  final List<String> warnings;
  final bool highLatitudeFallbackApplied;
  final bool isValid;

  String get dateKey =>
      '${localDate.year.toString().padLeft(4, '0')}-'
      '${localDate.month.toString().padLeft(2, '0')}-'
      '${localDate.day.toString().padLeft(2, '0')}';

  String get cacheKey =>
      '$dateKey|${location.latitude}|${location.longitude}|'
      '${location.timezoneId}|${config.cacheKey}';

  PrayerTimeEntry entry(PrayerName prayer) => entries[prayer]!;

  DateTime calculatedTime(PrayerName prayer) => entry(prayer).calculated;

  DateTime adjustedTime(PrayerName prayer) => entry(prayer).adjusted;

  List<PrayerTimeEntry> get ordered =>
      <PrayerTimeEntry>[for (final prayer in prayerOrder) entry(prayer)];

  List<DateTime> get adjustedTimes => ordered
      .map((entry) => entry.adjusted)
      .toList(growable: false);

  List<DateTime> get calculatedTimes => ordered
      .map((entry) => entry.calculated)
      .toList(growable: false);

  /// The next prayer strictly after [after]. Isha can fall after midnight in
  /// high-latitude locations, so this uses real instants, not clock strings.
  PrayerTimeEntry? nextAfter(DateTime after) {
    for (final entry in ordered) {
      if (entry.adjusted.isAfter(after)) return entry;
    }
    return null;
  }

  /// The last prayer at or before [at], if any.
  PrayerTimeEntry? lastAtOrBefore(DateTime at) {
    PrayerTimeEntry? last;
    for (final entry in ordered) {
      if (!entry.adjusted.isAfter(at)) last = entry;
    }
    return last;
  }

  bool get hasWarnings => warnings.isNotEmpty || !isValid;

  bool get appliesHighLatitudeFallback => highLatitudeFallbackApplied;
}
