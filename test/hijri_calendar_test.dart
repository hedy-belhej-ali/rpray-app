import 'package:test/test.dart';
import 'package:rafel/services/hijri_calendar_service.dart';

void main() {
  const service = HijriCalendarService();

  group('known Umm al-Qura anchors', () {
    test('1 Ramadan 1446 is 1 March 2025', () {
      expect(
        service.fromGregorian(DateTime(2025, 3, 1)),
        const HijriDate(year: 1446, month: 9, day: 1),
      );
    });

    test('1 Shawwal 1445 is 10 April 2024', () {
      expect(
        service.fromGregorian(DateTime(2024, 4, 10)),
        const HijriDate(year: 1445, month: 10, day: 1),
      );
    });

    test('10 Dhu al-Hijjah 1445 is 16 June 2024', () {
      expect(
        service.fromGregorian(DateTime(2024, 6, 16)),
        const HijriDate(year: 1445, month: 12, day: 10),
      );
    });
  });

  group('offset handling', () {
    test('a +1 offset moves the Hijri day forward one civil day', () {
      expect(
        service.fromGregorian(DateTime(2025, 3, 1), offsetDays: 1),
        const HijriDate(year: 1446, month: 9, day: 2),
      );
      expect(
        service.fromGregorian(DateTime(2025, 2, 28), offsetDays: 1),
        const HijriDate(year: 1446, month: 9, day: 1),
      );
    });

    test('toGregorian is the inverse of fromGregorian for every offset', () {
      for (final offset in const <int>[-2, -1, 0, 1, 2]) {
        final civil = DateTime(2026, 3, 20);
        final hijri = service.fromGregorian(civil, offsetDays: offset);
        expect(hijri, isNotNull);
        expect(
          service.toGregorian(hijri!, offsetDays: offset),
          DateTime(2026, 3, 20),
          reason: 'offset $offset must round-trip',
        );
      }
    });

    test('offset dates can be formatted for both languages', () {
      const hijri = HijriDate(year: 1447, month: 9, day: 1);
      expect(hijri.formatted, '1 Ramadan 1447 AH');
      expect(hijri.monthNameArabic, 'رمضان');
      expect(hijri.formattedArabic, contains('رمضان'));
    });
  });

  group('month and year lengths', () {
    test('every Hijri month is 29 or 30 days', () {
      for (var year = 1440; year <= 1460; year++) {
        for (var month = 1; month <= 12; month++) {
          final length = service.daysInMonth(year, month);
          expect(length, isNotNull, reason: '$year-$month');
          expect(
            length == 29 || length == 30,
            isTrue,
            reason: '$year-$month has $length days',
          );
        }
      }
    });

    test('year lengths are 354 or 355 and leap years are exactly 355', () {
      for (var year = 1440; year <= 1460; year++) {
        final length = service.daysInYear(year);
        expect(length == 354 || length == 355, isTrue,
            reason: 'year $year has $length days');
        expect(service.isLeapYear(year), length == 355);
      }
    });

    test('month starts are consecutive and match the stated month length', () {
      for (var month = 1; month <= 12; month++) {
        final start = service.dateFor(1447, month, 1);
        expect(start, isNotNull);
        final nextStart = month == 12
            ? service.dateFor(1448, 1, 1)
            : service.dateFor(1447, month + 1, 1);
        expect(nextStart, isNotNull);
        expect(
          nextStart!.difference(start!).inDays,
          service.daysInMonth(1447, month),
          reason: 'month $month length must agree with the next month start',
        );
      }
    });

    test('the first day of a month converts back to day 1', () {
      for (var month = 1; month <= 12; month++) {
        final civil = service.startOfMonth(1447, month);
        expect(civil, isNotNull);
        final hijri = service.fromGregorian(civil!);
        expect(hijri!.day, 1);
        expect(hijri.month, month);
        expect(hijri.year, 1447);
      }
    });
  });

  group('invalid input', () {
    test('invalid Hijri dates are rejected rather than clamped', () {
      expect(service.toGregorian(const HijriDate(year: 1447, month: 0, day: 1)),
          isNull);
      expect(
          service.toGregorian(const HijriDate(year: 1447, month: 13, day: 1)),
          isNull);
      expect(service.toGregorian(const HijriDate(year: 1447, month: 1, day: 0)),
          isNull);
      expect(
          service.toGregorian(
              const HijriDate(year: 1000, month: 1, day: 1)),
          isNull);
      expect(service.daysInMonth(1447, 13), isNull);
    });
  });
}
