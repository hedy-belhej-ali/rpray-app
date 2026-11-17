import 'package:test/test.dart';
import 'package:rafel/models/prayer_name.dart';
import 'package:rafel/models/prayer_settings.dart';
import 'package:rafel/services/prayer_times_service.dart';
import 'package:rafel/services/timezone_service.dart';

const _tunis = GeoLocation(
  name: 'Tunis',
  latitude: 36.8065,
  longitude: 10.1815,
  timezoneId: 'Africa/Tunis',
  country: 'Tunisia',
);

String _hhmm(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

int _minutesOfDay(DateTime value) => value.hour * 60 + value.minute;

/// Compares a calculated clock time with the AlAdhan-verified fixture,
/// tolerating two minutes because the `adhan` package may round differently.
/// High-latitude Isha can legitimately differ more: AlAdhan's middle-of-night
/// value for London is not consistent with its own reported midnight.
void _expectClock(
  String label,
  DateTime actual,
  String expected, {
  int toleranceMinutes = 2,
}) {
  final parts = expected.split(':');
  final expectedMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
  final actualMinutes = _minutesOfDay(actual);
  var difference = (actualMinutes - expectedMinutes).abs();
  if (difference > 12 * 60) difference = 24 * 60 - difference;
  expect(
    difference <= toleranceMinutes,
    isTrue,
    reason: '$label: got ${_hhmm(actual)}, expected $expected '
        '(±$toleranceMinutes min)',
  );
}

void main() {
  group('PrayerTimesService verified fixtures', () {
    final service = PrayerTimesService();
    final config = CalculationConfig();

    void verifyDay({
      required GeoLocation location,
      required DateTime date,
      required List<String> expected,
      int ishaToleranceMinutes = 2,
    }) {
      final outcome = service.calculate(
        localDate: date,
        location: location,
        config: config,
      );
      expect(outcome.errors, isEmpty, reason: outcome.errors.join('; '));
      expect(outcome.isSuccess, isTrue);
      final day = outcome.day!;
      final expectedByPrayer = <PrayerName, String>{
        PrayerName.fajr: expected[0],
        PrayerName.dhuhr: expected[2],
        PrayerName.asr: expected[3],
        PrayerName.maghrib: expected[4],
        PrayerName.isha: expected[5],
      };
      for (final prayer in PrayerName.values) {
        _expectClock(
          '${location.name} ${day.dateKey} ${prayer.key}',
          day.adjustedTime(prayer),
          expectedByPrayer[prayer]!,
          toleranceMinutes:
              prayer == PrayerName.isha ? ishaToleranceMinutes : 2,
        );
      }
      _expectClock(
        '${location.name} ${day.dateKey} sunrise',
        day.sunrise,
        expected[1],
      );
    }

    test('Tunis in summer matches the offline verification fixture', () {
      verifyDay(
        location: _tunis,
        date: DateTime(2026, 7, 15),
        expected: const <String>[
          '03:24',
          '05:12',
          '12:25',
          '16:16',
          '19:38',
          '21:19',
        ],
      );
    });

    test('Tunis in winter matches the offline verification fixture', () {
      verifyDay(
        location: _tunis,
        date: DateTime(2026, 12, 15),
        expected: const <String>[
          '05:52',
          '07:25',
          '12:14',
          '14:46',
          '17:04',
          '18:32',
        ],
      );
    });

    test('London summer Isha crosses midnight but stays on the day', () {
      verifyDay(
        location: const GeoLocation(
          name: 'London',
          latitude: 51.5072,
          longitude: -0.1276,
          timezoneId: 'Europe/London',
          country: 'United Kingdom',
        ),
        date: DateTime(2026, 7, 15),
        expected: const <String>[
          '01:06',
          '05:01',
          '13:07',
          '17:25',
          '21:12',
          '00:53',
        ],
        ishaToleranceMinutes: 20,
      );
    });

    test('Oslo summer values use the selected high-latitude rule', () {
      verifyDay(
        location: const GeoLocation(
          name: 'Oslo',
          latitude: 59.9139,
          longitude: 10.7522,
          timezoneId: 'Europe/Oslo',
          country: 'Norway',
        ),
        date: DateTime(2026, 7, 15),
        expected: const <String>[
          '01:23',
          '04:22',
          '13:23',
          '17:58',
          '22:24',
          '01:23',
        ],
      );
    });

    test('leap day is calculated for the correct civil date', () {
      verifyDay(
        location: _tunis,
        date: DateTime(2028, 2, 29),
        expected: const <String>[
          '05:25',
          '06:51',
          '12:32',
          '15:43',
          '18:13',
          '19:34',
        ],
      );
    });
  });

  group('PrayerTimesService behaviour', () {
    test('adjustments move only the adjusted time and keep calculated time',
        () {
      final base = PrayerTimesService().calculate(
        localDate: DateTime(2026, 7, 15),
        location: _tunis,
        config: const CalculationConfig(),
      );
      final adjusted = PrayerTimesService().calculate(
        localDate: DateTime(2026, 7, 15),
        location: _tunis,
        config: const CalculationConfig(
          adjustments: PrayerAdjustments(<PrayerName, int>{
            PrayerName.fajr: 5,
            PrayerName.isha: -3,
          }),
        ),
      );
      expect(base.isSuccess, isTrue);
      expect(adjusted.isSuccess, isTrue);

      final baseFajr = base.day!.calculatedTime(PrayerName.fajr);
      final adjustedFajr = adjusted.day!.entry(PrayerName.fajr);
      expect(
        adjustedFajr.calculated.difference(baseFajr).inSeconds.abs(),
        lessThanOrEqualTo(60),
      );
      expect(adjustedFajr.adjusted.difference(adjustedFajr.calculated).inMinutes,
          5);
      expect(
        adjustedFajr.adjustmentMinutes,
        5,
        reason: 'calculated and adjusted must remain distinct',
      );

      final adjustedIsha = adjusted.day!.entry(PrayerName.isha);
      expect(
        adjustedIsha.adjusted.difference(adjustedIsha.calculated).inMinutes,
        -3,
      );
    });

    test('invalid coordinates are rejected instead of using a default city',
        () {
      final outcome = PrayerTimesService().calculate(
        localDate: DateTime(2026, 7, 15),
        location: const GeoLocation(
          name: 'Nowhere',
          latitude: 120,
          longitude: 10,
          timezoneId: 'Africa/Tunis',
        ),
        config: const CalculationConfig(),
      );
      expect(outcome.day, isNull);
      expect(outcome.isSuccess, isFalse);
      expect(outcome.errors, isNotEmpty);
    });

    test('every calculation requires an explicit timezone', () {
      final outcome = PrayerTimesService().calculate(
        localDate: DateTime(2026, 7, 15),
        location: const GeoLocation(
          name: 'No timezone',
          latitude: 36.8,
          longitude: 10.18,
          timezoneId: '',
        ),
        config: const CalculationConfig(),
      );
      expect(outcome.day, isNull);
      expect(outcome.errors.join(' '), contains('invalid'));
    });

    test('Hanafi Asr is later than the standard Asr on the same day', () {
      final standard = PrayerTimesService().calculate(
        localDate: DateTime(2026, 7, 15),
        location: _tunis,
        config: const CalculationConfig(),
      );
      final hanafi = PrayerTimesService().calculate(
        localDate: DateTime(2026, 7, 15),
        location: _tunis,
        config: const CalculationConfig(madhab: AsrMadhab.hanafi),
      );
      expect(
        hanafi.day!.adjustedTime(PrayerName.asr).isAfter(
              standard.day!.adjustedTime(PrayerName.asr),
            ),
        isTrue,
      );
    });

    test('config changes never reuse a stale cached day', () {
      final service = PrayerTimesService();
      final first = service.calculate(
        localDate: DateTime(2026, 7, 15),
        location: _tunis,
        config: const CalculationConfig(),
      );
      final second = service.calculate(
        localDate: DateTime(2026, 7, 15),
        location: _tunis,
        config: const CalculationConfig(
          method: PrayerCalculationMethod.ummAlQura,
        ),
      );
      expect(identical(first.day, second.day), isFalse);
      expect(
        first.day!.adjustedTime(PrayerName.fajr),
        isNot(equals(second.day!.adjustedTime(PrayerName.fajr))),
      );
    });

    test('same inputs return the cached immutable day', () {
      final service = PrayerTimesService();
      final first = service.calculate(
        localDate: DateTime(2026, 7, 15),
        location: _tunis,
        config: const CalculationConfig(),
      );
      final second = service.calculate(
        localDate: DateTime(2026, 7, 15),
        location: _tunis,
        config: const CalculationConfig(),
      );
      expect(identical(first.day, second.day), isTrue);
      expect(first.day!.localDate.hour, 0);
      expect(first.day!.isValid, isTrue);
    });

    test('timezone is honoured: the same instant has different civil times',
        () {
      final tunis = PrayerTimesService().calculate(
        localDate: DateTime(2026, 7, 15),
        location: _tunis,
        config: const CalculationConfig(),
      );
      final osloClock = PrayerTimesService().calculate(
        localDate: DateTime(2026, 7, 15),
        location: const GeoLocation(
          name: 'Tunis on Oslo time',
          latitude: 36.8065,
          longitude: 10.1815,
          timezoneId: 'Europe/Oslo',
        ),
        config: const CalculationConfig(),
      );
      expect(
        TimezoneService.convert(
          tunis.day!.adjustedTime(PrayerName.dhuhr),
          'Europe/Oslo',
        ).hour,
        isNot(tunis.day!.adjustedTime(PrayerName.dhuhr).hour),
      );
      expect(osloClock.day!.adjustedTime(PrayerName.dhuhr).hour, 13);
    });
  });
}
