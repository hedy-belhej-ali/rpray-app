import 'package:hijri/hijri_calendar.dart';

const List<String> hijriMonthNamesEnglish = <String>[
  'Muharram',
  'Safar',
  "Rabi' al-Awwal",
  "Rabi' al-Thani",
  'Jumada al-Awwal',
  'Jumada al-Thani',
  'Rajab',
  "Sha'ban",
  'Ramadan',
  'Shawwal',
  "Dhu al-Qa'dah",
  'Dhu al-Hijjah',
];

const List<String> hijriMonthNamesArabic = <String>[
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

class HijriDate {
  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  String get monthNameEnglish => hijriMonthNamesEnglish[month - 1];
  String get monthNameArabic => hijriMonthNamesArabic[month - 1];

  String get formatted => '$day $monthNameEnglish $year AH';
  String get formattedArabic => '$day $monthNameArabic $year هـ';

  @override
  String toString() => formatted;

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// Hijri dates are calculated independently from prayer times. This service
/// wraps the Umm al-Qura based `hijri` package, keeps explicit month lengths,
/// and applies the user's local sighting offset as a civil-day shift.
class HijriCalendarService {
  const HijriCalendarService();

  static const int minSupportedYear = 1356;
  static const int maxSupportedYear = 1500;

  DateTime _shift(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  HijriDate? fromGregorian(DateTime date, {int offsetDays = 0}) {
    try {
      final shifted = _shift(date, offsetDays);
      final calendar = HijriCalendar.fromDate(shifted);
      final hijri = HijriDate(
        year: calendar.hYear,
        month: calendar.hMonth,
        day: calendar.hDay,
      );
      if (hijri.year < minSupportedYear || hijri.year > maxSupportedYear) {
        return null;
      }
      return hijri;
    } catch (_) {
      return null;
    }
  }

  /// Converts a Hijri date back to a civil Gregorian date. The inverse of
  /// [fromGregorian]'s offset: a +1 sighting offset subtracts one day here.
  DateTime? toGregorian(
    HijriDate hijri, {
    int offsetDays = 0,
  }) {
    if (hijri.month < 1 ||
        hijri.month > 12 ||
        hijri.day < 1 ||
        hijri.year < minSupportedYear ||
        hijri.year > maxSupportedYear) {
      return null;
    }
    try {
      final calendar = HijriCalendar();
      final result = calendar.hijriToGregorian(
        hijri.year,
        hijri.month,
        hijri.day,
      );
      return _shift(result, -offsetDays);
    } catch (_) {
      return null;
    }
  }

  DateTime? startOfMonth(
    int hijriYear,
    int hijriMonth, {
    int offsetDays = 0,
  }) {
    return toGregorian(
      HijriDate(year: hijriYear, month: hijriMonth, day: 1),
      offsetDays: offsetDays,
    );
  }

  int? daysInMonth(int hijriYear, int hijriMonth) {
    if (hijriMonth < 1 || hijriMonth > 12) return null;
    try {
      return HijriCalendar().getDaysInMonth(hijriYear, hijriMonth);
    } catch (_) {
      return null;
    }
  }

  int? daysInYear(int hijriYear) {
    var total = 0;
    for (var month = 1; month <= 12; month++) {
      final length = daysInMonth(hijriYear, month);
      if (length == null) return null;
      total += length;
    }
    return total;
  }

  /// Hijri leap years are the years whose length is 355 days rather than 354.
  bool isLeapYear(int hijriYear) => daysInYear(hijriYear) == 355;

  /// Returns the civil Gregorian date for a specific Hijri date, shifted by
  /// the user's offset, returning null when outside the library's range.
  DateTime? dateFor(
    int hijriYear,
    int hijriMonth,
    int hijriDay, {
    int offsetDays = 0,
  }) {
    return toGregorian(
      HijriDate(year: hijriYear, month: hijriMonth, day: hijriDay),
      offsetDays: offsetDays,
    );
  }
}
