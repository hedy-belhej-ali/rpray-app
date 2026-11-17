import 'prayer_name.dart';

/// Established calculation methods exposed by the app. [adhanId] identifies
/// the method in the offline `adhan` package; `tunisia` and `morocco` are
/// explicit angle configurations because those ministries are not part of the
/// library's built-in enum.
enum PrayerCalculationMethod {
  muslimWorldLeague(
    key: 'mwl',
    label: 'Muslim World League',
    shortLabel: 'MWL',
    detail: 'Fajr 18° · Isha 17°',
    adhanId: 'muslim_world_league',
    fajrAngle: 18,
    ishaAngle: 17,
  ),
  egyptian(
    key: 'egyptian',
    label: 'Egyptian General Authority',
    shortLabel: 'Egypt',
    detail: 'Fajr 19.5° · Isha 17.5°',
    adhanId: 'egyptian',
    fajrAngle: 19.5,
    ishaAngle: 17.5,
  ),
  karachi(
    key: 'karachi',
    label: 'University of Islamic Sciences, Karachi',
    shortLabel: 'Karachi',
    detail: 'Fajr 18° · Isha 18°',
    adhanId: 'karachi',
    fajrAngle: 18,
    ishaAngle: 18,
  ),
  ummAlQura(
    key: 'umm_al_qura',
    label: 'Umm al-Qura, Makkah',
    shortLabel: 'Umm al-Qura',
    detail: 'Fajr 18.5° · Isha 90 min after Maghrib',
    adhanId: 'umm_al_qura',
    fajrAngle: 18.5,
  ),
  dubai(
    key: 'dubai',
    label: 'Dubai',
    shortLabel: 'Dubai',
    detail: 'Fajr 18.2° · Isha 18.2°',
    adhanId: 'dubai',
    fajrAngle: 18.2,
    ishaAngle: 18.2,
  ),
  northAmerica(
    key: 'isna',
    label: 'Islamic Society of North America',
    shortLabel: 'ISNA',
    detail: 'Fajr 15° · Isha 15°',
    adhanId: 'north_america',
    fajrAngle: 15,
    ishaAngle: 15,
  ),
  kuwait(
    key: 'kuwait',
    label: 'Kuwait',
    shortLabel: 'Kuwait',
    detail: 'Fajr 18° · Isha 17.5°',
    adhanId: 'kuwait',
    fajrAngle: 18,
    ishaAngle: 17.5,
  ),
  qatar(
    key: 'qatar',
    label: 'Qatar',
    shortLabel: 'Qatar',
    detail: 'Fajr 18° · Isha 90 min after Maghrib',
    adhanId: 'qatar',
    fajrAngle: 18,
  ),
  singapore(
    key: 'singapore',
    label: 'Singapore',
    shortLabel: 'Singapore',
    detail: 'Fajr 20° · Isha 18°',
    adhanId: 'singapore',
    fajrAngle: 20,
    ishaAngle: 18,
  ),
  turkey(
    key: 'turkey',
    label: 'Diyanet, Türkiye',
    shortLabel: 'Diyanet',
    detail: 'Fajr 18° · Isha 17°',
    adhanId: 'turkey',
    fajrAngle: 18,
    ishaAngle: 17,
  ),
  tunisia(
    key: 'tunisia',
    label: 'Tunisia (18° / 18°)',
    shortLabel: 'Tunisia',
    detail: 'Local convention, not an official authority endorsement',
    adhanId: 'other',
    fajrAngle: 18,
    ishaAngle: 18,
  ),
  morocco(
    key: 'morocco',
    label: 'Morocco (19° / 17°)',
    shortLabel: 'Morocco',
    detail: 'Local convention, not an official authority endorsement',
    adhanId: 'other',
    fajrAngle: 19,
    ishaAngle: 17,
  );

  const PrayerCalculationMethod({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.detail,
    required this.adhanId,
    required this.fajrAngle,
    this.ishaAngle,
  });

  final String key;
  final String label;
  final String shortLabel;
  final String detail;
  final String adhanId;
  final double fajrAngle;
  final double? ishaAngle;

  bool get usesIshaInterval =>
      ishaAngle == null && adhanId == 'umm_al_qura';

  static PrayerCalculationMethod fromKey(String? key) {
    for (final method in PrayerCalculationMethod.values) {
      if (method.key == key) return method;
    }
    return PrayerCalculationMethod.muslimWorldLeague;
  }
}

enum AsrMadhab {
  standard('standard', "Standard (Shafi'i, Maliki, Hanbali)", 'Shafi'),
  hanafi('hanafi', 'Hanafi', 'Hanafi');

  const AsrMadhab(this.key, this.label, this.shortLabel);

  final String key;
  final String label;
  final String shortLabel;

  static AsrMadhab fromKey(String? key) {
    for (final madhab in AsrMadhab.values) {
      if (madhab.key == key) return madhab;
    }
    return AsrMadhab.standard;
  }
}

enum HighLatitudeMethod {
  middleOfTheNight(
    key: 'middle_of_the_night',
    label: 'Middle of the night',
    detail: 'Fajr and Isha are bounded by the midpoint of the night.',
  ),
  seventhOfTheNight(
    key: 'seventh_of_the_night',
    label: 'One seventh of the night',
    detail: 'Fajr uses the last seventh, Isha the first seventh of the night.',
  ),
  twilightAngle(
    key: 'angle_based',
    label: 'Angle-based',
    detail: 'Uses the twilight angle as a fraction of the night.',
  );

  const HighLatitudeMethod({
    required this.key,
    required this.label,
    required this.detail,
  });

  final String key;
  final String label;
  final String detail;

  static HighLatitudeMethod fromKey(String? key) {
    for (final method in HighLatitudeMethod.values) {
      if (method.key == key) return method;
    }
    return HighLatitudeMethod.middleOfTheNight;
  }
}

/// A location chosen by the user. There is deliberately no built-in default
/// city: Rpray never silently assumes Tunis, or anywhere else.
class GeoLocation {
  const GeoLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timezoneId,
    this.country,
    this.isDeviceLocation = false,
    this.suggestedMethod,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String timezoneId;
  final String? country;
  final bool isDeviceLocation;
  final PrayerCalculationMethod? suggestedMethod;

  String get coordinateLabel {
    final lat = latitude.toStringAsFixed(4);
    final lng = longitude.toStringAsFixed(4);
    return '$lat°, $lng°';
  }

  String get displayName {
    if (country == null || country!.isEmpty) return name;
    if (name.toLowerCase() == country!.toLowerCase()) return name;
    return '$name, $country';
  }

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      timezoneId.isNotEmpty;

  GeoLocation copyWith({
    String? name,
    double? latitude,
    double? longitude,
    String? timezoneId,
    String? country,
    bool? isDeviceLocation,
    PrayerCalculationMethod? suggestedMethod,
  }) {
    return GeoLocation(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timezoneId: timezoneId ?? this.timezoneId,
      country: country ?? this.country,
      isDeviceLocation: isDeviceLocation ?? this.isDeviceLocation,
      suggestedMethod: suggestedMethod ?? this.suggestedMethod,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'timezoneId': timezoneId,
        'country': country,
        'isDeviceLocation': isDeviceLocation,
        'suggestedMethod': suggestedMethod?.key,
      };

  static GeoLocation? fromJson(Object? value) {
    if (value is! Map) return null;
    final name = value['name'];
    final lat = value['latitude'];
    final lng = value['longitude'];
    final timezone = value['timezoneId'];
    if (name is! String ||
        lat is! num ||
        lng is! num ||
        timezone is! String) {
      return null;
    }
    final location = GeoLocation(
      name: name,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      timezoneId: timezone,
      country: value['country'] is String ? value['country'] as String : null,
      isDeviceLocation: value['isDeviceLocation'] == true,
      suggestedMethod: value['suggestedMethod'] is String
          ? PrayerCalculationMethod.fromKey(value['suggestedMethod'] as String)
          : null,
    );
    return location.isValid ? location : null;
  }

  @override
  String toString() => 'GeoLocation($name, $latitude, $longitude, $timezoneId)';
}

/// User-defined minute offsets for the five prayers. The calculated time is
/// always kept separately from this adjustment.
class PrayerAdjustments {
  const PrayerAdjustments([Map<PrayerName, int>? values])
      : _values = values ?? const <PrayerName, int>{};

  final Map<PrayerName, int> _values;

  int forPrayer(PrayerName prayer) => _values[prayer] ?? 0;

  bool get isEmpty =>
      _values.values.every((value) => value == 0) || _values.isEmpty;

  PrayerAdjustments withAdjustment(PrayerName prayer, int minutes) {
    final next = Map<PrayerName, int>.from(_values);
    final clamped = minutes.clamp(-60, 60).toInt();
    if (clamped == 0) {
      next.remove(prayer);
    } else {
      next[prayer] = clamped;
    }
    return PrayerAdjustments(next);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        for (final entry in _values.entries)
          if (entry.value != 0) entry.key.key: entry.value,
      };

  static PrayerAdjustments fromJson(Object? value) {
    if (value is! Map) return const PrayerAdjustments();
    final out = <PrayerName, int>{};
    for (final entry in value.entries) {
      final prayer = PrayerName.fromKey(entry.key as String?);
      final minutes = entry.value;
      if (prayer != null && minutes is num) {
        final clamped = minutes.toInt().clamp(-60, 60).toInt();
        if (clamped != 0) out[prayer] = clamped;
      }
    }
    return PrayerAdjustments(out);
  }
}

class CalculationConfig {
  const CalculationConfig({
    this.method = PrayerCalculationMethod.muslimWorldLeague,
    this.madhab = AsrMadhab.standard,
    this.highLatitudeMethod = HighLatitudeMethod.middleOfTheNight,
    this.adjustments = const PrayerAdjustments(),
  });

  final PrayerCalculationMethod method;
  final AsrMadhab madhab;
  final HighLatitudeMethod highLatitudeMethod;
  final PrayerAdjustments adjustments;

  CalculationConfig copyWith({
    PrayerCalculationMethod? method,
    AsrMadhab? madhab,
    HighLatitudeMethod? highLatitudeMethod,
    PrayerAdjustments? adjustments,
  }) {
    return CalculationConfig(
      method: method ?? this.method,
      madhab: madhab ?? this.madhab,
      highLatitudeMethod: highLatitudeMethod ?? this.highLatitudeMethod,
      adjustments: adjustments ?? this.adjustments,
    );
  }

  /// A stable cache key that includes every input that affects the result.
  String get cacheKey =>
      '${method.key}|${madhab.key}|${highLatitudeMethod.key}|${adjustments.toJson()}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'method': method.key,
        'madhab': madhab.key,
        'highLatitudeMethod': highLatitudeMethod.key,
        'adjustments': adjustments.toJson(),
      };

  static CalculationConfig fromJson(Object? value) {
    if (value is! Map) return const CalculationConfig();
    return CalculationConfig(
      method: PrayerCalculationMethod.fromKey(value['method'] as String?),
      madhab: AsrMadhab.fromKey(value['madhab'] as String?),
      highLatitudeMethod:
          HighLatitudeMethod.fromKey(value['highLatitudeMethod'] as String?),
      adjustments: PrayerAdjustments.fromJson(value['adjustments']),
    );
  }
}
