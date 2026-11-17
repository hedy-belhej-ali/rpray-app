import '../models/islamic_event.dart';
import '../services/hijri_calendar_service.dart';
import 'timezone_service.dart';

class _EventCopy {
  const _EventCopy(this.title, this.message);

  final String title;
  final String message;
}

class _EventSeed {
  const _EventSeed({
    required this.key,
    required this.type,
    required this.phase,
    required this.civilDate,
    required this.hour,
    required this.minute,
    required this.copy,
    required this.status,
    this.hijriYear,
    this.hijriLabel,
    this.primaryOverrideKey,
    this.dayNumber,
  });

  final String key;
  final OccasionType type;
  final EventPhase phase;
  final DateTime civilDate;
  final int hour;
  final int minute;
  final _EventCopy copy;
  final EventDateStatus status;
  final int? hijriYear;
  final String? hijriLabel;
  final String? primaryOverrideKey;
  final int? dayNumber;
}

/// Generates Islamic occasions from Hijri dates, never hardcoded Gregorian
/// dates. Confirmed/adjusted primary dates override the calculated calendar
/// and all dependent reminders are regenerated from the corrected date.
class IslamicEventsService {
  const IslamicEventsService({
    this.hijri = const HijriCalendarService(),
  });

  final HijriCalendarService hijri;

  List<IslamicEvent> upcoming({
    required DateTime from,
    required DateTime to,
    required String timezoneId,
    int hijriOffset = 0,
    Map<String, EventDateOverride> overrides = const {},
  }) {
    TimezoneService.initialize();
    final fromLocal = TimezoneService.convert(from, timezoneId);
    final toLocal = TimezoneService.convert(to, timezoneId);
    final startCivil = DateTime(fromLocal.year, fromLocal.month, fromLocal.day);
    final endCivil = DateTime(toLocal.year, toLocal.month, toLocal.day);
    final startHijri = hijri.fromGregorian(startCivil, offsetDays: hijriOffset);
    final endHijri = hijri.fromGregorian(endCivil, offsetDays: hijriOffset);
    if (startHijri == null || endHijri == null) return const <IslamicEvent>[];

    final seeds = <String, _EventSeed>{};
    final lastYear = endHijri.year.clamp(
      HijriCalendarService.minSupportedYear,
      HijriCalendarService.maxSupportedYear,
    );
    final firstYear = startHijri.year.clamp(
      HijriCalendarService.minSupportedYear,
      HijriCalendarService.maxSupportedYear,
    );

    for (var year = firstYear; year <= lastYear; year++) {
      for (var month = 1; month <= 12; month++) {
        final monthStart = _hijriDate(year, month, 1, hijriOffset);
        if (monthStart == null) continue;

        // Quick month-window rejection, but keep one month of margin so
        // overrides near a boundary are not lost.
        final monthEnd = _monthEnd(year, month, hijriOffset);
        if (monthEnd != null &&
            monthEnd.isBefore(
              _addDays(startCivil, -35),
            ) &&
            monthStart.isAfter(_addDays(endCivil, 35))) {
          continue;
        }

        _addMuharramEvents(
          seeds: seeds,
          year: year,
          month: month,
          hijriOffset: hijriOffset,
          overrides: overrides,
        );
        _addMawlidEvents(
          seeds: seeds,
          year: year,
          month: month,
          hijriOffset: hijriOffset,
          overrides: overrides,
        );
        _addRamadanEvents(
          seeds: seeds,
          year: year,
          month: month,
          hijriOffset: hijriOffset,
          overrides: overrides,
        );
        _addEidFitrEvents(
          seeds: seeds,
          year: year,
          month: month,
          hijriOffset: hijriOffset,
          overrides: overrides,
        );
        _addDhulHijjahEvents(
          seeds: seeds,
          year: year,
          month: month,
          hijriOffset: hijriOffset,
          overrides: overrides,
        );
        _addWhiteDayEvents(
          seeds: seeds,
          year: year,
          month: month,
          hijriOffset: hijriOffset,
          overrides: overrides,
        );
      }
    }

    final events = <IslamicEvent>[];
    for (final seed in seeds.values) {
      final date = TimezoneService.atCivilTime(
        timezoneId,
        seed.civilDate,
        seed.hour,
        seed.minute,
      );
      if (date.isBefore(from) || date.isAfter(to)) continue;
      events.add(
        IslamicEvent(
          key: seed.key,
          type: seed.type,
          phase: seed.phase,
          date: date,
          title: seed.copy.title,
          message: seed.copy.message,
          status: seed.status,
          audioRaw: seed.type.audioRaw,
          hijriYear: seed.hijriYear,
          hijriLabel: seed.hijriLabel,
          primaryOverrideKey: seed.primaryOverrideKey,
          dayNumber: seed.dayNumber,
        ),
      );
    }
    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  /// Primary confirmable dates within the requested window.
  List<PrimaryOccasionDate> primaryDates({
    required DateTime from,
    required DateTime to,
    required String timezoneId,
    int hijriOffset = 0,
    Map<String, EventDateOverride> overrides = const {},
  }) {
    TimezoneService.initialize();
    final fromLocal = TimezoneService.convert(from, timezoneId);
    final toLocal = TimezoneService.convert(to, timezoneId);
    final startCivil = DateTime(fromLocal.year, fromLocal.month, fromLocal.day);
    final endCivil = DateTime(toLocal.year, toLocal.month, toLocal.day);
    final startHijri = hijri.fromGregorian(startCivil, offsetDays: hijriOffset);
    final endHijri = hijri.fromGregorian(endCivil, offsetDays: hijriOffset);
    if (startHijri == null || endHijri == null) return const <PrimaryOccasionDate>[];

    final output = <PrimaryOccasionDate>[];
    for (var year = startHijri.year; year <= endHijri.year + 1; year++) {
      if (year < HijriCalendarService.minSupportedYear ||
          year > HijriCalendarService.maxSupportedYear) {
        continue;
      }
      final candidates = <_PrimarySeed>[
        _PrimarySeed(
          OccasionType.ramadan,
          year,
          9,
          1,
          'ramadan_$year',
          overrides,
          hijriOffset,
        ),
        _PrimarySeed(
          OccasionType.eidAlFitr,
          year,
          10,
          1,
          'eid_fitr_$year',
          overrides,
          hijriOffset,
        ),
        _PrimarySeed(
          OccasionType.eidAlAdha,
          year,
          12,
          10,
          'eid_adha_$year',
          overrides,
          hijriOffset,
        ),
      ];
      for (final candidate in candidates) {
        final civil = candidate.civilDate;
        if (civil == null) continue;
        if (civil.isBefore(startCivil) || civil.isAfter(endCivil)) continue;
        output.add(
          PrimaryOccasionDate(
            type: candidate.type,
            hijriYear: year,
            date: TimezoneService.civilMidnight(timezoneId, civil),
            status: candidate.status,
            overrideKey: candidate.overrideKey,
            hijriLabel: candidate.hijriLabel,
            isOverridden: candidate.override != null,
          ),
        );
      }
    }
    output.sort((a, b) => a.date.compareTo(b.date));
    // De-duplicate by override key.
    final seen = <String>{};
    return output.where((date) => seen.add(date.overrideKey)).toList();
  }

  void _addMuharramEvents({
    required Map<String, _EventSeed> seeds,
    required int year,
    required int month,
    required int hijriOffset,
    required Map<String, EventDateOverride> overrides,
  }) {
    if (month != 1) return;
    final newYear = _hijriDate(year, 1, 1, hijriOffset);
    final ashura = _hijriDate(year, 1, 10, hijriOffset);
    final status = _statusForOffset(hijriOffset);
    if (newYear != null) {
      _addSeed(
        seeds: seeds,
        key: 'new_hijri_year_${year}_eve',
        type: OccasionType.islamicNewYear,
        phase: EventPhase.dayBefore,
        civilDate: _addDays(newYear, -1),
        hour: 9,
        copy: _copyFor(OccasionType.islamicNewYear, EventPhase.dayBefore),
        status: status,
        hijriYear: year,
        hijriLabel: '1 Muharram $year AH',
      );
      _addSeed(
        seeds: seeds,
        key: 'new_hijri_year_${year}_day',
        type: OccasionType.islamicNewYear,
        phase: EventPhase.onDay,
        civilDate: newYear,
        hour: 9,
        copy: _copyFor(OccasionType.islamicNewYear, EventPhase.onDay),
        status: status,
        hijriYear: year,
        hijriLabel: '1 Muharram $year AH',
      );
    }
    if (ashura != null) {
      _addSeed(
        seeds: seeds,
        key: 'ashura_${year}_eve',
        type: OccasionType.ashura,
        phase: EventPhase.dayBefore,
        civilDate: _addDays(ashura, -1),
        hour: 9,
        copy: _copyFor(OccasionType.ashura, EventPhase.dayBefore),
        status: status,
        hijriYear: year,
        hijriLabel: '10 Muharram $year AH',
      );
      _addSeed(
        seeds: seeds,
        key: 'ashura_${year}_day',
        type: OccasionType.ashura,
        phase: EventPhase.onDay,
        civilDate: ashura,
        hour: 9,
        copy: _copyFor(OccasionType.ashura, EventPhase.onDay),
        status: status,
        hijriYear: year,
        hijriLabel: '10 Muharram $year AH',
      );
    }
  }

  void _addMawlidEvents({
    required Map<String, _EventSeed> seeds,
    required int year,
    required int month,
    required int hijriOffset,
    required Map<String, EventDateOverride> overrides,
  }) {
    if (month != 3) return;
    final mawlid = _hijriDate(year, 3, 12, hijriOffset);
    if (mawlid == null) return;
    final status = _statusForOffset(hijriOffset);
    _addSeed(
      seeds: seeds,
      key: 'mawlid_${year}_eve',
      type: OccasionType.mawlid,
      phase: EventPhase.dayBefore,
      civilDate: _addDays(mawlid, -1),
      hour: 9,
      copy: _copyFor(OccasionType.mawlid, EventPhase.dayBefore),
      status: status,
      hijriYear: year,
      hijriLabel: '12 Rabi al-Awwal $year AH',
    );
    _addSeed(
      seeds: seeds,
      key: 'mawlid_${year}_day',
      type: OccasionType.mawlid,
      phase: EventPhase.onDay,
      civilDate: mawlid,
      hour: 9,
      copy: _copyFor(OccasionType.mawlid, EventPhase.onDay),
      status: status,
      hijriYear: year,
      hijriLabel: '12 Rabi al-Awwal $year AH',
    );
  }

  void _addRamadanEvents({
    required Map<String, _EventSeed> seeds,
    required int year,
    required int month,
    required int hijriOffset,
    required Map<String, EventDateOverride> overrides,
  }) {
    if (month != 9) return;
    final ramadanStart = _effectiveRamadanStart(year, hijriOffset, overrides);
    final eidFitr = _effectiveEidFitr(year, hijriOffset, overrides);
    if (ramadanStart == null || eidFitr == null) return;

    final ramadanOverride = overrides['ramadan_$year'];
    final eidOverride = overrides['eid_fitr_$year'];
    final status = _statusForPrimary(
      primary: ramadanOverride ?? eidOverride,
      hijriOffset: hijriOffset,
    );
    final countdownDate = _addDays(ramadanStart, -3);
    _addSeed(
      seeds: seeds,
      key: 'ramadan_countdown_$year',
      type: OccasionType.ramadan,
      phase: EventPhase.threeDaysBefore,
      civilDate: countdownDate,
      hour: 9,
      copy: _copyFor(OccasionType.ramadan, EventPhase.threeDaysBefore),
      status: status,
      hijriYear: year,
      hijriLabel: '1 Ramadan $year AH',
      primaryOverrideKey: 'ramadan_$year',
    );

    // The last ten nights are always the ten nights leading to Eid al-Fitr,
    // which keeps the count correct whether Ramadan has 29 or 30 days.
    for (var night = 1; night <= 10; night++) {
      final date = _addDays(eidFitr, night - 11);
      _addSeed(
        seeds: seeds,
        key: 'last_ten_${year}_$night',
        type: OccasionType.lastTenNights,
        phase: EventPhase.night,
        civilDate: date,
        hour: 20,
        minute: 30,
        copy: _copyFor(
          OccasionType.lastTenNights,
          EventPhase.night,
          dayNumber: night,
        ),
        status: status,
        hijriYear: year,
        hijriLabel: 'Last ten nights of Ramadan $year AH',
        dayNumber: night,
      );
    }

    for (final ramadanDay in const <int>[21, 23, 25, 27, 29]) {
      final date = _addDays(ramadanStart, ramadanDay - 1);
      if (!date.isBefore(eidFitr)) continue;
      _addSeed(
        seeds: seeds,
        key: 'qadr_${year}_$ramadanDay',
        type: OccasionType.laylatAlQadr,
        phase: EventPhase.night,
        civilDate: date,
        hour: 21,
        minute: 30,
        copy: _copyFor(
          OccasionType.laylatAlQadr,
          EventPhase.night,
          dayNumber: ramadanDay,
        ),
        status: status,
        hijriYear: year,
        hijriLabel: '$ramadanDay Ramadan $year AH',
        dayNumber: ramadanDay,
      );
    }
  }

  void _addEidFitrEvents({
    required Map<String, _EventSeed> seeds,
    required int year,
    required int month,
    required int hijriOffset,
    required Map<String, EventDateOverride> overrides,
  }) {
    if (month != 10) return;
    final eid = _effectiveEidFitr(year, hijriOffset, overrides);
    if (eid == null) return;
    final override = overrides['eid_fitr_$year'];
    final status = _statusForPrimary(primary: override, hijriOffset: hijriOffset);
    _addEidTriplet(
      seeds: seeds,
      year: year,
      eidDate: eid,
      type: OccasionType.eidAlFitr,
      overrideKey: 'eid_fitr_$year',
      status: status,
      hijriLabel: '1 Shawwal $year AH',
    );
  }

  void _addDhulHijjahEvents({
    required Map<String, _EventSeed> seeds,
    required int year,
    required int month,
    required int hijriOffset,
    required Map<String, EventDateOverride> overrides,
  }) {
    if (month != 12) return;
    final eidOverride = overrides['eid_adha_$year'];
    final eid = eidOverride != null
        ? _shiftedCivil(eidOverride.date)
        : _hijriDate(year, 12, 10, hijriOffset);
    if (eid == null) return;
    final status = _statusForPrimary(
      primary: eidOverride,
      hijriOffset: hijriOffset,
    );
    _addEidTriplet(
      seeds: seeds,
      year: year,
      eidDate: eid,
      type: OccasionType.eidAlAdha,
      overrideKey: 'eid_adha_$year',
      status: status,
      hijriLabel: '10 Dhu al-Hijjah $year AH',
    );

    final arafah = _addDays(eid, -1);
    _addSeed(
      seeds: seeds,
      key: 'arafah_${year}_eve',
      type: OccasionType.arafah,
      phase: EventPhase.dayBefore,
      civilDate: _addDays(arafah, -1),
      hour: 9,
      copy: _copyFor(OccasionType.arafah, EventPhase.dayBefore),
      status: _statusForPrimary(
        primary: eidOverride,
        hijriOffset: hijriOffset,
      ),
      hijriYear: year,
      hijriLabel: '9 Dhu al-Hijjah $year AH',
    );
    _addSeed(
      seeds: seeds,
      key: 'arafah_${year}_day',
      type: OccasionType.arafah,
      phase: EventPhase.onDay,
      civilDate: arafah,
      hour: 9,
      copy: _copyFor(OccasionType.arafah, EventPhase.onDay),
      status: _statusForPrimary(
        primary: eidOverride,
        hijriOffset: hijriOffset,
      ),
      hijriYear: year,
      hijriLabel: '9 Dhu al-Hijjah $year AH',
    );
  }

  void _addWhiteDayEvents({
    required Map<String, _EventSeed> seeds,
    required int year,
    required int month,
    required int hijriOffset,
    required Map<String, EventDateOverride> overrides,
  }) {
    final monthLength = hijri.daysInMonth(year, month);
    if (monthLength == null) return;
    final status = _statusForOffset(hijriOffset);
    for (final day in const <int>[13, 14, 15]) {
      if (day > monthLength) continue;
      final date = _hijriDate(year, month, day, hijriOffset);
      if (date == null) continue;
      final monthLabel = hijriMonthNamesEnglish[month - 1];
      _addSeed(
        seeds: seeds,
        key: 'white_days_${year}_${month}_${day}_eve',
        type: OccasionType.whiteDays,
        phase: EventPhase.dayBefore,
        civilDate: _addDays(date, -1),
        hour: 20,
        copy: _copyFor(OccasionType.whiteDays, EventPhase.dayBefore),
        status: status,
        hijriYear: year,
        hijriLabel: '$day $monthLabel $year AH',
        dayNumber: day,
      );
      _addSeed(
        seeds: seeds,
        key: 'white_days_${year}_${month}_${day}_day',
        type: OccasionType.whiteDays,
        phase: EventPhase.onDay,
        civilDate: date,
        hour: 9,
        copy: _copyFor(OccasionType.whiteDays, EventPhase.onDay),
        status: status,
        hijriYear: year,
        hijriLabel: '$day $monthLabel $year AH',
        dayNumber: day,
      );
    }
  }

  void _addEidTriplet({
    required Map<String, _EventSeed> seeds,
    required int year,
    required DateTime eidDate,
    required OccasionType type,
    required String overrideKey,
    required EventDateStatus status,
    required String hijriLabel,
  }) {
    final phases = <EventPhase, DateTime>{
      EventPhase.threeDaysBefore: _addDays(eidDate, -3),
      EventPhase.dayBefore: _addDays(eidDate, -1),
      EventPhase.onDay: eidDate,
    };
    for (final entry in phases.entries) {
      _addSeed(
        seeds: seeds,
        key: '${type.key}_${year}_${entry.key.key}',
        type: type,
        phase: entry.key,
        civilDate: entry.value,
        hour: 9,
        copy: _copyFor(type, entry.key),
        status: status,
        hijriYear: year,
        hijriLabel: hijriLabel,
        primaryOverrideKey: overrideKey,
      );
    }
  }

  void _addSeed({
    required Map<String, _EventSeed> seeds,
    required String key,
    required OccasionType type,
    required EventPhase phase,
    required DateTime civilDate,
    required int hour,
    required _EventCopy copy,
    required EventDateStatus status,
    int minute = 0,
    int? hijriYear,
    String? hijriLabel,
    String? primaryOverrideKey,
    int? dayNumber,
  }) {
    seeds.putIfAbsent(
      key,
      () => _EventSeed(
        key: key,
        type: type,
        phase: phase,
        civilDate: civilDate,
        hour: hour,
        minute: minute,
        copy: copy,
        status: status,
        hijriYear: hijriYear,
        hijriLabel: hijriLabel,
        primaryOverrideKey: primaryOverrideKey,
        dayNumber: dayNumber,
      ),
    );
  }

  DateTime? _effectiveRamadanStart(
    int year,
    int offset,
    Map<String, EventDateOverride> overrides,
  ) {
    final override = overrides['ramadan_$year'];
    if (override != null) {
      return _shiftedCivil(override.date);
    }
    return _hijriDate(year, 9, 1, offset);
  }

  DateTime? _effectiveEidFitr(
    int year,
    int offset,
    Map<String, EventDateOverride> overrides,
  ) {
    final override = overrides['eid_fitr_$year'];
    if (override != null) {
      return _shiftedCivil(override.date);
    }
    return _hijriDate(year, 10, 1, offset);
  }

  DateTime? _hijriDate(int year, int month, int day, int offset) {
    final gregorian = hijri.dateFor(
      year,
      month,
      day,
      offsetDays: offset,
    );
    if (gregorian == null) return null;
    return DateTime(gregorian.year, gregorian.month, gregorian.day);
  }

  /// Stored override dates are already civil values chosen by the user. They
  /// must not have the global Hijri offset applied a second time.
  DateTime _shiftedCivil(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime? _monthEnd(int year, int month, int offset) {
    final length = hijri.daysInMonth(year, month);
    if (length == null) return null;
    return _hijriDate(year, month, length, offset);
  }

  DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  EventDateStatus _statusForOffset(int offset) => offset == 0
      ? EventDateStatus.estimated
      : EventDateStatus.adjusted;

  EventDateStatus _statusForPrimary({
    required EventDateOverride? primary,
    required int hijriOffset,
  }) {
    if (primary != null) return primary.status;
    return _statusForOffset(hijriOffset);
  }

  _EventCopy _copyFor(
    OccasionType type,
    EventPhase phase, {
    int? dayNumber,
  }) {
    switch (type) {
      case OccasionType.ramadan:
        return const _EventCopy(
          'Ramadan Is Almost Here! 🌙',
          'Only 3 days left until the expected beginning of Ramadan! Prepare '
              'your heart for a month of fasting, prayer, forgiveness and '
              'blessings.',
        );
      case OccasionType.eidAlFitr:
        switch (phase) {
          case EventPhase.threeDaysBefore:
            return const _EventCopy(
              'Eid Is Almost Here! 🌙',
              'Eid al-Fitr is expected in 3 days! Prepare to celebrate the '
                  'blessings of Allah and the end of Ramadan.',
            );
          case EventPhase.dayBefore:
            return const _EventCopy(
              'Tomorrow Is Eid! 🎉',
              'Tomorrow is expected to be Eid al-Fitr. May Allah accept your '
                  'fasting, prayers and good deeds.',
            );
          default:
            return const _EventCopy(
              'Eid Mubarak! 🎉',
              'Eid Mubarak! May Allah accept your fasting, prayers and good '
                  'deeds. May your home be filled with happiness, peace and '
                  'blessings.',
            );
        }
      case OccasionType.eidAlAdha:
        switch (phase) {
          case EventPhase.threeDaysBefore:
            return const _EventCopy(
              'Eid al-Adha Is Approaching!',
              'Eid al-Adha is expected in 3 days. Prepare your heart for this '
                  'blessed occasion.',
            );
          case EventPhase.dayBefore:
            return const _EventCopy(
              'Tomorrow Is Eid al-Adha!',
              'Tomorrow is expected to be Eid al-Adha. May Allah accept your '
                  'sacrifices and good deeds.',
            );
          default:
            return const _EventCopy(
              'Eid al-Adha Mubarak! 🐑',
              'May Allah accept your sacrifice, prayers and good deeds. '
                  'Wishing you and your family a blessed Eid.',
            );
        }
      case OccasionType.islamicNewYear:
        return phase == EventPhase.dayBefore
            ? const _EventCopy(
                'A New Hijri Year Is Approaching 🌙',
                'A new Islamic year is approaching. Take a moment to reflect, '
                    'renew your intentions and ask Allah for guidance.',
              )
            : const _EventCopy(
                'Happy Islamic New Year!',
                'May this new Hijri year bring you closer to Allah and fill '
                    'your life with peace, guidance and blessings.',
              );
      case OccasionType.ashura:
        return phase == EventPhase.dayBefore
            ? const _EventCopy(
                'Tomorrow Is Ashura',
                'Tomorrow is the day of Ashura. Consider fasting and remember '
                    'the blessings of Allah.',
              )
            : const _EventCopy(
                'The Day of Ashura',
                'Today is Ashura. Consider fasting and increasing your '
                    'remembrance and gratitude to Allah.',
              );
      case OccasionType.arafah:
        return phase == EventPhase.dayBefore
            ? const _EventCopy(
                'Tomorrow Is the Day of Arafah',
                'Tomorrow is the blessed Day of Arafah. Prepare yourself for '
                    'dua, remembrance and good deeds.',
              )
            : const _EventCopy(
                'The Day of Arafah 🤲',
                'Today is the Day of Arafah. Increase your supplications and '
                    'remembrance of Allah. Those not performing Hajj may '
                    'observe the recommended fast.',
              );
      case OccasionType.mawlid:
        return phase == EventPhase.dayBefore
            ? const _EventCopy(
                'Mawlid Is Approaching',
                'Tomorrow is a day when many Muslims remember the birth of '
                    'Prophet Muhammad ﷺ and reflect on his teachings and '
                    'character.',
              )
            : const _EventCopy(
                'Remember the Prophet ﷺ',
                'Remember the beautiful character and teachings of Prophet '
                    'Muhammad ﷺ. May peace and blessings be upon him.',
              );
      case OccasionType.whiteDays:
        return phase == EventPhase.dayBefore
            ? const _EventCopy(
                'The White Days Are Approaching 🌕',
                'Tomorrow is one of the White Days. Consider fasting and '
                    'following this recommended Sunnah.',
              )
            : const _EventCopy(
                'White Days Reminder',
                'Today is one of the White Days of the Hijri month. Consider '
                    'fasting and gaining the reward of this Sunnah.',
              );
      case OccasionType.lastTenNights:
        final night = dayNumber ?? 1;
        return _EventCopy(
          'The Last Ten Nights 🌙',
          'Night $night of the last ten nights of Ramadan. Increase your '
              'worship, Qur’an, charity and dua.',
        );
      case OccasionType.laylatAlQadr:
        final night = dayNumber ?? 21;
        return _EventCopy(
          'Seek Laylat al-Qadr ✨',
          'Tonight is the $night${_ordinalSuffix(night)} night of Ramadan, one '
              'of the odd nights of the last ten. The exact night is not known '
              '— increase worship, dua and Qur’an.',
        );
    }
  }

  String _ordinalSuffix(int value) {
    if (value >= 11 && value <= 13) return 'th';
    switch (value % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}

class _PrimarySeed {
  _PrimarySeed(
    this.type,
    this.year,
    this.month,
    this.day,
    this.overrideKey,
    Map<String, EventDateOverride> overrides,
    int hijriOffset,
  ) : override = overrides[overrideKey] {
    if (override != null) {
      civilDate = DateTime(
        override!.date.year,
        override!.date.month,
        override!.date.day,
      );
      status = override!.status;
      hijriLabel = _label(type, year);
    } else {
      final gregorian = const HijriCalendarService().dateFor(
        year,
        month,
        day,
        offsetDays: hijriOffset,
      );
      civilDate = gregorian == null
          ? null
          : DateTime(gregorian.year, gregorian.month, gregorian.day);
      status = hijriOffset == 0
          ? EventDateStatus.estimated
          : EventDateStatus.adjusted;
      hijriLabel = _label(type, year);
    }
  }

  final OccasionType type;
  final int year;
  final int month;
  final int day;
  final String overrideKey;
  final EventDateOverride? override;
  DateTime? civilDate;
  late EventDateStatus status;
  late String hijriLabel;

  String _label(OccasionType type, int year) {
    return switch (type) {
      OccasionType.ramadan => '1 Ramadan $year AH',
      OccasionType.eidAlFitr => '1 Shawwal $year AH',
      OccasionType.eidAlAdha => '10 Dhu al-Hijjah $year AH',
      _ => '$year AH',
    };
  }
}
