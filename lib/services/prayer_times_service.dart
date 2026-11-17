import 'package:adhan/adhan.dart';

import '../models/prayer_day.dart';
import '../models/prayer_name.dart';
import '../models/prayer_settings.dart';
import 'prayer_validation_service.dart';
import 'timezone_service.dart';

class PrayerCalculationOutcome {
  const PrayerCalculationOutcome({
    this.day,
    this.errors = const <String>[],
    this.warnings = const <String>[],
    this.fallbackApplied = false,
  });

  final PrayerDay? day;
  final List<String> errors;
  final List<String> warnings;
  final bool fallbackApplied;

  bool get isSuccess => day != null && day!.isValid;
}

/// Offline prayer-time calculation built on the established `adhan` library.
/// The library calculates solar instants in UTC; this service resolves the
/// correct solar day for the selected civil date and converts to the chosen
/// IANA timezone. User adjustments are applied only after the calculated time
/// is captured, so the two values remain distinct.
class PrayerTimesService {
  PrayerTimesService({
    PrayerValidationService? validation,
  }) : _validation = validation ?? PrayerValidationService();

  final PrayerValidationService _validation;
  final Map<String, PrayerDay> _cache = <String, PrayerDay>{};

  PrayerCalculationOutcome calculate({
    required DateTime localDate,
    required GeoLocation location,
    required CalculationConfig config,
    DateTime? now,
  }) {
    if (!location.isValid) {
      return const PrayerCalculationOutcome(
        errors: ['The selected location is invalid.'],
      );
    }
    TimezoneService.initialize();

    final civil = DateTime(localDate.year, localDate.month, localDate.day);
    final cacheKey = '${TimezoneService.civilDateKey(civil)}|'
        '${location.latitude}|${location.longitude}|'
        '${location.timezoneId}|${config.cacheKey}';
    final cached = _cache[cacheKey];
    if (cached != null) return PrayerCalculationOutcome(day: cached);

    final primary = _attempt(
      civilDate: civil,
      location: location,
      config: config,
      highLatitude: config.highLatitudeMethod,
      now: now,
    );

    if (primary.day != null && primary.day!.isValid) {
      _store(cacheKey, primary.day!);
      return primary;
    }

    // A high-latitude fallback is only attempted when the selected method
    // could not produce a valid day. The user's original choice is reported.
    if (config.highLatitudeMethod != HighLatitudeMethod.middleOfTheNight) {
      final fallback = _attempt(
        civilDate: civil,
        location: location,
        config: config,
        highLatitude: HighLatitudeMethod.middleOfTheNight,
        now: now,
        fallbackApplied: true,
      );
      if (fallback.day != null && fallback.day!.isValid) {
        _store(cacheKey, fallback.day!);
        return PrayerCalculationOutcome(
          day: fallback.day,
          warnings: <String>[
            'Your high-latitude method could not produce valid times; '
                'the middle-of-the-night fallback was applied.',
            ...fallback.warnings,
          ],
          fallbackApplied: true,
        );
      }
      return PrayerCalculationOutcome(
        errors: <String>[
          ...primary.errors,
          ...fallback.errors,
        ],
        warnings: <String>[
          'Both the selected high-latitude method and the fallback failed. '
              'Nothing will be scheduled until valid times are available.',
          ...primary.warnings,
          ...fallback.warnings,
        ],
        fallbackApplied: true,
      );
    }

    return primary;
  }

  void clearCache() => _cache.clear();

  void _store(String key, PrayerDay day) {
    if (_cache.length >= 48) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = day;
  }

  PrayerCalculationOutcome _attempt({
    required DateTime civilDate,
    required GeoLocation location,
    required CalculationConfig config,
    required HighLatitudeMethod highLatitude,
    required DateTime? now,
    bool fallbackApplied = false,
  }) {
    final issues = <String>[];
    _RawTimes? lastRaw;

    // The library's input date is a UTC civil date. Pick the solar day whose
    // local Dhuhr lands on the requested local date. This also handles extreme
    // UTC offsets around the date line.
    for (final offset in const <int>[0, 1, -1]) {
      final utcDate =
          DateTime.utc(civilDate.year, civilDate.month, civilDate.day)
              .add(Duration(days: offset));
      try {
        final raw = _calculateUtc(
          utcDate: utcDate,
          location: location,
          config: config,
          highLatitude: highLatitude,
        );
        lastRaw = raw;
        final dhuhrLocal =
            TimezoneService.convert(raw.prayerUtc[PrayerName.dhuhr]!,
                location.timezoneId);
        if (dhuhrLocal.year == civilDate.year &&
            dhuhrLocal.month == civilDate.month &&
            dhuhrLocal.day == civilDate.day) {
          return _buildOutcome(
            raw: raw,
            civilDate: civilDate,
            location: location,
            config: config,
            now: now,
            fallbackApplied: fallbackApplied,
          );
        }
      } catch (error) {
        issues.add(error.toString());
      }
    }

    if (lastRaw != null) {
      // Use the closest attempt so validation can explain exactly what is
      // wrong, rather than fabricating a time.
      final outcome = _buildOutcome(
        raw: lastRaw,
        civilDate: civilDate,
        location: location,
        config: config,
        now: now,
        fallbackApplied: fallbackApplied,
        extraIssues: <String>[
          'Calculated Dhuhr does not fall on the selected local date.',
        ],
      );
      return outcome;
    }

    return PrayerCalculationOutcome(
      errors: <String>[
        'Prayer calculation failed for this location and date.',
        ...issues,
      ],
      warnings: const <String>[
        'No notification will be scheduled from an invalid calculation.',
      ],
      fallbackApplied: fallbackApplied,
    );
  }

  PrayerCalculationOutcome _buildOutcome({
    required _RawTimes raw,
    required DateTime civilDate,
    required GeoLocation location,
    required CalculationConfig config,
    required DateTime? now,
    required bool fallbackApplied,
    List<String> extraIssues = const <String>[],
  }) {
    final entries = <PrayerName, PrayerTimeEntry>{};
    for (final prayer in PrayerName.values) {
      final calculated = TimezoneService.convert(
        raw.prayerUtc[prayer]!,
        location.timezoneId,
      );
      final adjusted = calculated.add(
        Duration(minutes: config.adjustments.forPrayer(prayer)),
      );
      entries[prayer] = PrayerTimeEntry(
        prayer: prayer,
        calculated: calculated,
        adjusted: TimezoneService.convert(adjusted, location.timezoneId),
      );
    }
    final sunrise =
        TimezoneService.convert(raw.sunriseUtc, location.timezoneId);
    final localMidnight = TimezoneService.civilMidnight(
      location.timezoneId,
      civilDate,
    );

    final validation = _validation.validate(
      times: <PrayerName, DateTime?>{
        for (final prayer in PrayerName.values)
          prayer: entries[prayer]?.adjusted,
      },
      sunrise: sunrise,
      localDate: localMidnight,
      timezoneId: location.timezoneId,
    );

    final day = PrayerDay(
      localDate: localMidnight,
      location: location,
      config: config,
      entries: entries,
      sunrise: sunrise,
      calculatedAt: now ?? DateTime.now(),
      warnings: <String>[
        ...raw.warnings,
        ...validation.warnings,
        ...extraIssues,
        if (fallbackApplied)
          'High-latitude fallback applied: middle of the night.',
      ],
      highLatitudeFallbackApplied: fallbackApplied,
      isValid: validation.isValid,
    );

    if (!validation.isValid) {
      return PrayerCalculationOutcome(
        day: day,
        errors: <String>[
          ...validation.errors,
          ...extraIssues,
        ],
        warnings: <String>[
          ...day.warnings,
          'No notification will be scheduled from an invalid calculation.',
        ],
        fallbackApplied: fallbackApplied,
      );
    }

    return PrayerCalculationOutcome(
      day: day,
      warnings: day.warnings,
      fallbackApplied: fallbackApplied,
    );
  }

  _RawTimes _calculateUtc({
    required DateTime utcDate,
    required GeoLocation location,
    required CalculationConfig config,
    required HighLatitudeMethod highLatitude,
  }) {
    final parameters = _parameters(config, highLatitude);
    final warnings = <String>[];
    if (highLatitude == HighLatitudeMethod.twilightAngle &&
        (parameters.ishaAngle == null || parameters.ishaAngle! <= 0)) {
      parameters.highLatitudeRule = HighLatitudeRule.middle_of_the_night;
      warnings.add(
        'This method defines Isha by minutes, so the angle-based '
        'high-latitude rule could not be used for Isha.',
      );
    }

    final times = PrayerTimes.utc(
      Coordinates(location.latitude, location.longitude, validate: true),
      DateComponents(utcDate.year, utcDate.month, utcDate.day),
      parameters,
    );

    return _RawTimes(
      prayerUtc: <PrayerName, DateTime>{
        PrayerName.fajr: times.fajr,
        PrayerName.dhuhr: times.dhuhr,
        PrayerName.asr: times.asr,
        PrayerName.maghrib: times.maghrib,
        PrayerName.isha: times.isha,
      },
      sunriseUtc: times.sunrise,
      warnings: warnings,
    );
  }

  CalculationParameters _parameters(
    CalculationConfig config,
    HighLatitudeMethod highLatitude,
  ) {
    final method = config.method;
    CalculationParameters parameters;
    if (method.adhanId == 'other') {
      parameters = CalculationParameters(
        method: CalculationMethod.other,
        fajrAngle: method.fajrAngle,
        ishaAngle: method.ishaAngle,
      );
    } else {
      CalculationMethod adhanMethod = CalculationMethod.other;
      for (final candidate in CalculationMethod.values) {
        if (candidate.name == method.adhanId) {
          adhanMethod = candidate;
          break;
        }
      }
      parameters = adhanMethod.getParameters();
    }

    parameters.madhab =
        config.madhab == AsrMadhab.hanafi ? Madhab.hanafi : Madhab.shafi;
    parameters.highLatitudeRule = switch (highLatitude) {
      HighLatitudeMethod.middleOfTheNight =>
        HighLatitudeRule.middle_of_the_night,
      HighLatitudeMethod.seventhOfTheNight =>
        HighLatitudeRule.seventh_of_the_night,
      HighLatitudeMethod.twilightAngle => HighLatitudeRule.twilight_angle,
    };
    return parameters;
  }
}

class _RawTimes {
  const _RawTimes({
    required this.prayerUtc,
    required this.sunriseUtc,
    required this.warnings,
  });

  final Map<PrayerName, DateTime> prayerUtc;
  final DateTime sunriseUtc;
  final List<String> warnings;
}
