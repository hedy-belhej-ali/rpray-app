import 'package:test/test.dart';
import 'package:rafel/models/islamic_event.dart';
import 'package:rafel/services/islamic_events_service.dart';

const _timezone = 'Africa/Tunis';
const _service = IslamicEventsService();

final _from = DateTime.utc(2026, 1, 1);
final _to = DateTime.utc(2026, 12, 31);

List<IslamicEvent> _events({
  Map<String, EventDateOverride> overrides = const {},
  int hijriOffset = 0,
}) {
  return _service.upcoming(
    from: _from,
    to: _to,
    timezoneId: _timezone,
    hijriOffset: hijriOffset,
    overrides: overrides,
  );
}

DateTime _civil(DateTime value) =>
    DateTime(value.year, value.month, value.day);

IslamicEvent _byKey(List<IslamicEvent> events, String key) {
  final matches = events.where((event) => event.key == key).toList();
  expect(matches, hasLength(1), reason: 'expected exactly one $key');
  return matches.single;
}

void main() {
  group('Ramadan countdown', () {
    test('there is exactly one Ramadan event and it is exactly 3 days before',
        () {
      final events = _events();
      final ramadan = events
          .where((event) => event.type == OccasionType.ramadan)
          .toList();
      expect(ramadan, hasLength(1));
      expect(ramadan.single.key, 'ramadan_countdown_1447');
      expect(ramadan.single.phase, EventPhase.threeDaysBefore);

      final primary = _service.primaryDates(
        from: _from,
        to: _to,
        timezoneId: _timezone,
      );
      final start = primary
          .firstWhere((date) => date.type == OccasionType.ramadan)
          .date;
      expect(
        _civil(ramadan.single.date),
        DateTime(start.year, start.month, start.day - 3),
      );
    });

    test('there are no 7-day, 30-day or 1-day Ramadan countdowns', () {
      final events = _events();
      final keys = events
          .where((event) => event.type == OccasionType.ramadan)
          .map((event) => event.key)
          .toList();
      expect(keys, <String>['ramadan_countdown_1447']);
      expect(events.every((event) => event.type != OccasionType.ramadan ||
          event.phase == EventPhase.threeDaysBefore), isTrue);
    });
  });

  group('Eid and Arafah', () {
    test('Eid al-Fitr has exactly three phases and lands on 1 Shawwal', () {
      final events = _events();
      final eid = events
          .where((event) => event.type == OccasionType.eidAlFitr)
          .toList();
      expect(eid, hasLength(3));
      expect(
        eid.map((event) => event.phase).toSet(),
        <EventPhase>{
          EventPhase.threeDaysBefore,
          EventPhase.dayBefore,
          EventPhase.onDay,
        },
      );
      final onDay = _byKey(events, 'eid_fitr_1447_on_day');
      final primary = _service
          .primaryDates(from: _from, to: _to, timezoneId: _timezone)
          .firstWhere((date) => date.type == OccasionType.eidAlFitr);
      expect(_civil(onDay.date), _civil(primary.date));
      expect(onDay.audioRaw, 'eid_fitr');
    });

    test('Eid al-Adha has three phases and Arafah is the day before', () {
      final events = _events();
      final eid = events
          .where((event) => event.type == OccasionType.eidAlAdha)
          .toList();
      expect(eid, hasLength(3));

      final eidDay = _byKey(events, 'eid_adha_1447_on_day');
      final arafahDay = _byKey(events, 'arafah_1447_day');
      final arafahEve = _byKey(events, 'arafah_1447_eve');
      expect(
        _civil(eidDay.date).difference(_civil(arafahDay.date)).inDays,
        1,
      );
      expect(
        _civil(arafahDay.date).difference(_civil(arafahEve.date)).inDays,
        1,
      );
      expect(arafahDay.type, OccasionType.arafah);
      expect(arafahDay.audioRaw, 'tmr_arafa');
    });

    test('Muharram events (new year and Ashura) have eve and day', () {
      final events = _events();
      for (final type in const <OccasionType>[
        OccasionType.islamicNewYear,
        OccasionType.ashura,
      ]) {
        final items = events.where((event) => event.type == type).toList();
        expect(items, hasLength(2), reason: type.label);
        expect(
          items.map((event) => event.phase).toSet(),
          <EventPhase>{EventPhase.dayBefore, EventPhase.onDay},
        );
      }
    });

    test('Mawlid can be generated and carries its own audio', () {
      final events = _events();
      final mawlid =
          events.where((event) => event.type == OccasionType.mawlid).toList();
      expect(mawlid, hasLength(2));
      expect(mawlid.first.audioRaw, 'mawlid_nabawi');
    });
  });

  group('White Days, last ten nights and Laylat al-Qadr', () {
    test('White Days are only 13, 14 and 15 with an eve and a day each', () {
      final events = _events();
      final white = events
          .where((event) => event.type == OccasionType.whiteDays)
          .toList();
      expect(white, isNotEmpty);
      expect(
        white.every((event) =>
            const <int>{13, 14, 15}.contains(event.dayNumber)),
        isTrue,
      );

      final groups = <String, List<IslamicEvent>>{};
      for (final event in white) {
        final key = '${event.hijriYear}|${event.hijriLabel}';
        groups.putIfAbsent(key, () => <IslamicEvent>[]).add(event);
      }
      for (final entry in groups.entries) {
        expect(entry.value, hasLength(2), reason: entry.key);
        expect(
          entry.value.map((event) => event.phase).toSet(),
          <EventPhase>{EventPhase.dayBefore, EventPhase.onDay},
        );
      }
      // Twelve-plus months, three days each: no month may be missing.
      expect(groups.length, greaterThanOrEqualTo(36));
    });

    test('the last ten nights are ten consecutive nightly reminders', () {
      final events = _events();
      final nights = events
          .where((event) => event.type == OccasionType.lastTenNights)
          .toList();
      expect(nights, hasLength(10));
      expect(
        nights.map((event) => event.dayNumber).toSet(),
        <int>{1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
      );
      for (var index = 1; index < nights.length; index++) {
        expect(
          _civil(nights[index].date)
              .difference(_civil(nights[index - 1].date))
              .inDays,
          1,
        );
      }
    });

    test('Laylat al-Qadr is announced on the odd nights only', () {
      final events = _events();
      final qadr = events
          .where((event) => event.type == OccasionType.laylatAlQadr)
          .toList();
      expect(qadr, hasLength(5));
      expect(
        qadr.map((event) => event.dayNumber).toSet(),
        <int>{21, 23, 25, 27, 29},
      );
      expect(qadr.every((event) => event.phase == EventPhase.night), isTrue);
      expect(qadr.every((event) => event.audioRaw == 'laylat_al_qadr'), isTrue);
    });
  });

  group('status, overrides and duplicates', () {
    test('calculated dates are marked estimated and offset dates adjusted', () {
      final estimated = _events();
      expect(
        estimated.every((event) => event.status == EventDateStatus.estimated),
        isTrue,
      );
      final adjusted = _events(hijriOffset: 1);
      expect(
        adjusted.every((event) => event.status == EventDateStatus.adjusted),
        isTrue,
      );
    });

    test('a confirmed Eid al-Fitr override moves the whole triplet', () {
      final base = _events();
      final baseOnDay = _byKey(base, 'eid_fitr_1447_on_day');
      final override = EventDateOverride(
        key: 'eid_fitr_1447',
        date: DateTime(
          baseOnDay.date.year,
          baseOnDay.date.month,
          baseOnDay.date.day + 1,
        ),
        status: EventDateStatus.confirmed,
      );

      final events = _events(overrides: <String, EventDateOverride>{
        override.key: override,
      });
      final onDay = _byKey(events, 'eid_fitr_1447_on_day');
      final dayBefore = _byKey(events, 'eid_fitr_1447_day_before');
      final threeDays = _byKey(events, 'eid_fitr_1447_three_days_before');
      expect(_civil(onDay.date), override.date);
      expect(_civil(dayBefore.date), override.date.subtract(const Duration(days: 1)));
      expect(_civil(threeDays.date), override.date.subtract(const Duration(days: 3)));
      expect(onDay.status, EventDateStatus.confirmed);
      expect(dayBefore.status, EventDateStatus.confirmed);

      final primary = _service.primaryDates(
        from: _from,
        to: _to,
        timezoneId: _timezone,
        overrides: <String, EventDateOverride>{override.key: override},
      );
      final eid = primary.firstWhere((date) => date.type == OccasionType.eidAlFitr);
      expect(eid.status, EventDateStatus.confirmed);
      expect(eid.isOverridden, isTrue);
      expect(_civil(eid.date), override.date);
    });

    test('a Ramadan override drives the countdown and last ten nights', () {
      final primary = _service.primaryDates(
        from: _from,
        to: _to,
        timezoneId: _timezone,
      );
      final eid = primary.firstWhere((date) => date.type == OccasionType.eidAlFitr);
      final start = primary.firstWhere((date) => date.type == OccasionType.ramadan);
      // Force a 29-day Ramadan by confirming Eid one day earlier.
      final override = EventDateOverride(
        key: 'eid_fitr_1447',
        date: DateTime(eid.date.year, eid.date.month, eid.date.day - 1),
        status: EventDateStatus.confirmed,
      );
      final events = _events(overrides: <String, EventDateOverride>{
        override.key: override,
      });
      final countdown = _byKey(events, 'ramadan_countdown_1447');
      expect(
        _civil(countdown.date),
        DateTime(start.date.year, start.date.month, start.date.day - 3),
      );
      final nights = events
          .where((event) => event.type == OccasionType.lastTenNights)
          .toList();
      expect(nights, hasLength(10));
      expect(
        _civil(nights.last.date),
        DateTime(override.date.year, override.date.month, override.date.day - 1),
      );
    });

    test('no event key is generated twice in the same window', () {
      final events = _events();
      final keys = events.map((event) => event.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
    });
  });
}
