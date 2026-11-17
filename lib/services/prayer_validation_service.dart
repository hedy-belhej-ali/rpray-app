import '../models/prayer_day.dart';
import '../models/prayer_name.dart';
import 'timezone_service.dart';

class PrayerValidationResult {
  const PrayerValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  bool get shouldFallback =>
      !isValid &&
      (errors.any((error) => error.contains('order')) ||
          errors.any((error) => error.contains('missing')));
}

/// Validates calculated times before anything is scheduled. It deliberately
/// allows legitimate high-latitude results (Isha after local midnight) while
/// rejecting impossible orderings and missing values.
class PrayerValidationService {
  PrayerValidationResult validateDay(PrayerDay day) {
    final times = <PrayerName, DateTime>{
      for (final entry in day.entries.entries) entry.key: entry.value.adjusted,
    };
    return validate(
      times: times,
      sunrise: day.sunrise,
      localDate: day.localDate,
      timezoneId: day.location.timezoneId,
    );
  }

  PrayerValidationResult validate({
    required Map<PrayerName, DateTime?> times,
    required DateTime? sunrise,
    required DateTime localDate,
    required String timezoneId,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    for (final prayer in PrayerName.values) {
      if (times[prayer] == null) {
        errors.add('missing time for ${prayer.englishLabel}');
      }
    }
    if (sunrise == null) errors.add('missing sunrise time');

    if (errors.isNotEmpty) {
      return PrayerValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    final fajr = times[PrayerName.fajr]!;
    final dhuhr = times[PrayerName.dhuhr]!;
    final asr = times[PrayerName.asr]!;
    final maghrib = times[PrayerName.maghrib]!;
    final isha = times[PrayerName.isha]!;
    final sun = sunrise!;

    void requireOrder(String name, DateTime earlier, DateTime later) {
      if (!later.isAfter(earlier)) {
        errors.add('$name order is invalid');
      }
    }

    requireOrder('Fajr/Sunrise', fajr, sun);
    requireOrder('Sunrise/Dhuhr', sun, dhuhr);
    requireOrder('Dhuhr/Asr', dhuhr, asr);
    requireOrder('Asr/Maghrib', asr, maghrib);
    requireOrder('Maghrib/Isha', maghrib, isha);

    // Fajr, sunrise, Dhuhr, Asr and Maghrib must belong to the selected civil
    // date. Isha may legitimately fall after midnight at high latitudes.
    for (final entry in <String, DateTime>{
      'Fajr': fajr,
      'Sunrise': sun,
      'Dhuhr': dhuhr,
      'Asr': asr,
      'Maghrib': maghrib,
    }.entries) {
      final local = TimezoneService.convert(entry.value, timezoneId);
      if (local.year != localDate.year ||
          local.month != localDate.month ||
          local.day != localDate.day) {
        errors.add('${entry.key} is not on the selected local date');
      }
    }

    final ishaLocal = TimezoneService.convert(isha, timezoneId);
    final ishaDayOffset = DateTime(
      ishaLocal.year,
      ishaLocal.month,
      ishaLocal.day,
    ).difference(
      DateTime(localDate.year, localDate.month, localDate.day),
    ).inDays;
    if (ishaDayOffset < 0 || ishaDayOffset > 1) {
      errors.add('Isha falls outside the prayer day');
    } else if (ishaDayOffset == 1) {
      warnings.add('Isha falls after midnight in this location.');
    }

    final maxMaghribToIsha = isha.difference(maghrib);
    if (maxMaghribToIsha > const Duration(hours: 12)) {
      warnings.add('Isha is unusually late; high-latitude rule is active.');
    }
    if (sun.difference(fajr) > const Duration(hours: 8)) {
      warnings.add('Fajr is unusually early; high-latitude rule is active.');
    }
    final dhuhrWindow = dhuhr.difference(sun);
    if (dhuhrWindow < const Duration(minutes: 20) ||
        dhuhrWindow > const Duration(hours: 10)) {
      warnings.add('Solar noon looks unusual for this date and location.');
    }

    return PrayerValidationResult(
      isValid: errors.isEmpty,
      errors: List<String>.unmodifiable(errors),
      warnings: List<String>.unmodifiable(warnings),
    );
  }
}
