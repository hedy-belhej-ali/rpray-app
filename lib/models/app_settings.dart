import 'islamic_event.dart';
import 'prayer_name.dart';
import 'prayer_settings.dart';

class PrayerNotificationPref {
  const PrayerNotificationPref({
    this.prayerEnabled = true,
    this.enabledIntervals = const <int>{5, 10, 15, 20, 25, 30},
    this.adhanEnabled = true,
  });

  final bool prayerEnabled;
  final Set<int> enabledIntervals;
  final bool adhanEnabled;

  bool wantsReminder(int minutes) =>
      prayerEnabled && enabledIntervals.contains(minutes);

  PrayerNotificationPref copyWith({
    bool? prayerEnabled,
    Set<int>? enabledIntervals,
    bool? adhanEnabled,
  }) {
    return PrayerNotificationPref(
      prayerEnabled: prayerEnabled ?? this.prayerEnabled,
      enabledIntervals: enabledIntervals ?? this.enabledIntervals,
      adhanEnabled: adhanEnabled ?? this.adhanEnabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'prayerEnabled': prayerEnabled,
        'intervals': enabledIntervals.toList()..sort(),
        'adhanEnabled': adhanEnabled,
      };

  static PrayerNotificationPref fromJson(Object? value) {
    if (value is! Map) return const PrayerNotificationPref();
    final rawIntervals = value['intervals'];
    final intervals = <int>{};
    if (rawIntervals is List) {
      for (final item in rawIntervals) {
        if (item is num && reminderIntervals.contains(item.toInt())) {
          intervals.add(item.toInt());
        }
      }
    }
    return PrayerNotificationPref(
      prayerEnabled: value['prayerEnabled'] != false,
      enabledIntervals:
          rawIntervals is List ? intervals : const {5, 10, 15, 20, 25, 30},
      adhanEnabled: value['adhanEnabled'] != false,
    );
  }
}

/// All persisted preferences. Immutable: every change replaces the object and
/// is written through [SettingsRepository].
class AppSettings {
  AppSettings({
    this.notificationsEnabled = true,
    Map<PrayerName, PrayerNotificationPref>? prayerPrefs,
    Map<OccasionType, bool>? occasionPrefs,
    this.hijriOffset = 0,
    Map<String, EventDateOverride>? dateOverrides,
    this.location,
    this.calculation = const CalculationConfig(),
    this.onboardingComplete = false,
    this.locationPermissionDenied = false,
    this.isDarkTheme = true,
  })  : prayerPrefs = prayerPrefs ?? _defaultPrayerPrefs(),
        occasionPrefs = occasionPrefs ?? _defaultOccasionPrefs(),
        dateOverrides = dateOverrides ?? <String, EventDateOverride>{};

  final bool notificationsEnabled;
  final Map<PrayerName, PrayerNotificationPref> prayerPrefs;
  final Map<OccasionType, bool> occasionPrefs;
  final int hijriOffset;
  final Map<String, EventDateOverride> dateOverrides;
  final GeoLocation? location;
  final CalculationConfig calculation;
  final bool onboardingComplete;

  /// Set after the user denies location permission so Rpray never repeatedly
  /// prompts them. Manual selection remains available.
  final bool locationPermissionDenied;

  /// Whether the app uses the dark theme. Defaults to dark to preserve the
  /// existing look for returning users.
  final bool isDarkTheme;

  bool get hasLocation => location != null;

  PrayerNotificationPref prefFor(PrayerName prayer) =>
      prayerPrefs[prayer] ?? const PrayerNotificationPref();

  bool occasionEnabled(OccasionType type) =>
      occasionPrefs[type] ?? type.defaultEnabled;

  bool isReminderEnabled(PrayerName prayer, int minutes) =>
      notificationsEnabled && prefFor(prayer).wantsReminder(minutes);

  bool isAdhanEnabled(PrayerName prayer) =>
      notificationsEnabled && prefFor(prayer).adhanEnabled;

  EventDateOverride? overrideFor(String key) => dateOverrides[key];

  AppSettings copyWith({
    bool? notificationsEnabled,
    Map<PrayerName, PrayerNotificationPref>? prayerPrefs,
    Map<OccasionType, bool>? occasionPrefs,
    int? hijriOffset,
    Map<String, EventDateOverride>? dateOverrides,
    Object? location = _noChange,
    CalculationConfig? calculation,
    bool? onboardingComplete,
    bool? locationPermissionDenied,
    bool? isDarkTheme,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      prayerPrefs: prayerPrefs ?? this.prayerPrefs,
      occasionPrefs: occasionPrefs ?? this.occasionPrefs,
      hijriOffset: (hijriOffset ?? this.hijriOffset).clamp(-2, 2).toInt(),
      dateOverrides: dateOverrides ?? this.dateOverrides,
      location: location == _noChange
          ? this.location
          : location as GeoLocation?,
      calculation: calculation ?? this.calculation,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      locationPermissionDenied:
          locationPermissionDenied ?? this.locationPermissionDenied,
      isDarkTheme: isDarkTheme ?? this.isDarkTheme,
    );
  }

  AppSettings withPrayerPref(PrayerName prayer, PrayerNotificationPref pref) {
    final next = Map<PrayerName, PrayerNotificationPref>.from(prayerPrefs);
    next[prayer] = pref;
    return copyWith(prayerPrefs: next);
  }

  AppSettings withOccasion(OccasionType type, bool enabled) {
    final next = Map<OccasionType, bool>.from(occasionPrefs);
    next[type] = enabled;
    return copyWith(occasionPrefs: next);
  }

  AppSettings withOverride(EventDateOverride override) {
    final next = Map<String, EventDateOverride>.from(dateOverrides);
    next[override.key] = override;
    return copyWith(dateOverrides: next);
  }

  AppSettings withoutOverride(String key) {
    final next = Map<String, EventDateOverride>.from(dateOverrides)
      ..remove(key);
    return copyWith(dateOverrides: next);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': 1,
        'notificationsEnabled': notificationsEnabled,
        'prayerPrefs': <String, dynamic>{
          for (final entry in prayerPrefs.entries)
            entry.key.key: entry.value.toJson(),
        },
        'occasionPrefs': <String, dynamic>{
          for (final entry in occasionPrefs.entries)
            entry.key.key: entry.value,
        },
        'hijriOffset': hijriOffset,
        'dateOverrides': dateOverrides.values
            .map((override) => override.toJson())
            .toList(growable: false),
        'location': location?.toJson(),
        'calculation': calculation.toJson(),
        'onboardingComplete': onboardingComplete,
        'locationPermissionDenied': locationPermissionDenied,
        'isDarkTheme': isDarkTheme,
      };

  static AppSettings fromJson(Map<String, dynamic> json) {
    final prefs = _defaultPrayerPrefs();
    final rawPrayerPrefs = json['prayerPrefs'];
    if (rawPrayerPrefs is Map) {
      for (final entry in rawPrayerPrefs.entries) {
        final prayer = PrayerName.fromKey(entry.key as String?);
        if (prayer != null) {
          prefs[prayer] = PrayerNotificationPref.fromJson(entry.value);
        }
      }
    }

    final occasions = _defaultOccasionPrefs();
    final rawOccasions = json['occasionPrefs'];
    if (rawOccasions is Map) {
      for (final entry in rawOccasions.entries) {
        final type = OccasionType.fromKey(entry.key as String?);
        if (type != null && entry.value is bool) {
          occasions[type] = entry.value as bool;
        }
      }
    }

    final overrides = <String, EventDateOverride>{};
    final rawOverrides = json['dateOverrides'];
    if (rawOverrides is List) {
      for (final raw in rawOverrides) {
        final override = EventDateOverride.fromJson(raw);
        if (override != null) overrides[override.key] = override;
      }
    }

    final offset = json['hijriOffset'];
    return AppSettings(
      notificationsEnabled: json['notificationsEnabled'] != false,
      prayerPrefs: prefs,
      occasionPrefs: occasions,
      hijriOffset: offset is num ? offset.toInt().clamp(-2, 2).toInt() : 0,
      dateOverrides: overrides,
      location: GeoLocation.fromJson(json['location']),
      calculation: CalculationConfig.fromJson(json['calculation']),
      onboardingComplete: json['onboardingComplete'] == true,
      locationPermissionDenied: json['locationPermissionDenied'] == true,
      isDarkTheme: json['isDarkTheme'] ?? true,
    );
  }

  static Map<PrayerName, PrayerNotificationPref> _defaultPrayerPrefs() {
    return <PrayerName, PrayerNotificationPref>{
      for (final prayer in PrayerName.values)
        prayer: const PrayerNotificationPref(),
    };
  }

  static Map<OccasionType, bool> _defaultOccasionPrefs() {
    return <OccasionType, bool>{
      for (final type in OccasionType.values) type: type.defaultEnabled,
    };
  }

  static const Object _noChange = Object();
}
