import 'dart:io';

import 'package:test/test.dart';
import 'package:rafel/models/app_settings.dart';
import 'package:rafel/models/islamic_event.dart';
import 'package:rafel/models/prayer_day.dart';
import 'package:rafel/models/prayer_name.dart';
import 'package:rafel/models/prayer_settings.dart';
import 'package:rafel/services/audio_asset_service.dart';
import 'package:rafel/services/islamic_events_service.dart';
import 'package:rafel/services/notification_ids.dart';
import 'package:rafel/services/prayer_schedule_service.dart';
import 'package:rafel/services/prayer_times_service.dart';
import 'package:rafel/services/timezone_service.dart';

const _tunis = GeoLocation(
  name: 'Tunis',
  latitude: 36.8065,
  longitude: 10.1815,
  timezoneId: 'Africa/Tunis',
  country: 'Tunisia',
);

final PrayerDay _day = PrayerTimesService()
    .calculate(
      localDate: DateTime(2026, 7, 15),
      location: _tunis,
      config: const CalculationConfig(),
    )
    .day!;

DateTime get _midnight =>
    TimezoneService.civilMidnight('Africa/Tunis', DateTime(2026, 7, 15));

void main() {
  final scheduler = PrayerScheduleService();

  group('advance reminders', () {
    test('five prayers produce six reminders each, sorted into the future', () {
      final settings = AppSettings(location: _tunis);
      final reminders = scheduler.buildRemindersForDay(
        day: _day,
        settings: settings,
        now: _midnight,
      );
      expect(reminders, hasLength(30));
      expect(
        reminders.map((reminder) => reminder.minutesBefore).toSet(),
        <int>{5, 10, 15, 20, 25, 30},
      );
      for (var index = 1; index < reminders.length; index++) {
        expect(
          reminders[index].time.isBefore(reminders[index - 1].time),
          isFalse,
        );
      }
      for (final reminder in reminders) {
        expect(reminder.time.isAfter(_midnight), isTrue);
        expect(
          reminder.prayerTime.difference(reminder.time).inMinutes,
          reminder.minutesBefore,
        );
        expect(reminder.soundRaw, isNotNull);
        expect(reminder.title, contains('${reminder.minutesBefore} minutes'));
      }
    });

    test('every reminder plays its own prayer voice on its own channel', () {
      final settings = AppSettings(location: _tunis);
      final reminders = scheduler.buildRemindersForDay(
        day: _day,
        settings: settings,
        now: _midnight,
      );
      expect(reminders, hasLength(30));

      final seen = <String>{};
      for (final reminder in reminders) {
        final key = '${reminder.prayer.key}|${reminder.minutesBefore}';
        expect(seen.add(key), isTrue, reason: 'duplicate plan for $key');
        // The 5-minute Fajr reminder must play the Fajr recording — not
        // another prayer's voice — on its own notification channel.
        expect(
          reminder.channelId,
          AudioAssetService.reminderChannelId(
            reminder.prayer,
            reminder.minutesBefore,
          ),
          reason: 'wrong channel for $key',
        );
        expect(
          reminder.soundRaw,
          AudioAssetService.reminderRaw(reminder.prayer, reminder.minutesBefore),
          reason: 'wrong recorded voice for $key',
        );
      }

      // Full matrix: every prayer x every interval, nothing missing.
      expect(seen, hasLength(30));
      for (final prayer in PrayerName.values) {
        for (final minutes in const <int>[5, 10, 15, 20, 25, 30]) {
          expect(seen, contains('${prayer.key}|$minutes'),
              reason: 'missing $minutes-min reminder for ${prayer.key}');
        }
      }
    });

    test('every reminder id is unique and 31-bit safe', () {
      final settings = AppSettings(location: _tunis);
      final reminders = scheduler.buildRemindersForDay(
        day: _day,
        settings: settings,
        now: _midnight,
      );
      final ids = reminders.map((reminder) => reminder.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.every((id) => id > 0 && id < 0x7FFFFFFF), isTrue);
      expect(
        reminders.map((reminder) => reminder.dedupeKey).toSet(),
        hasLength(reminders.length),
      );
    });

    test('disabled prayer and disabled interval are both respected', () {
      final settings = AppSettings(location: _tunis).withPrayerPref(
        PrayerName.fajr,
        const PrayerNotificationPref(
          enabledIntervals: <int>{5, 30},
        ),
      );
      final reminders = scheduler.buildRemindersForDay(
        day: _day,
        settings: settings,
        now: _midnight,
      );
      expect(reminders.where((reminder) => reminder.prayer == PrayerName.fajr),
          hasLength(2));
      expect(reminders, hasLength(26));

      final noFajr = AppSettings(location: _tunis).withPrayerPref(
        PrayerName.fajr,
        const PrayerNotificationPref(prayerEnabled: false),
      );
      final withoutFajr = scheduler.buildRemindersForDay(
        day: _day,
        settings: noFajr,
        now: _midnight,
      );
      expect(withoutFajr, hasLength(24));
      expect(
        withoutFajr.any((reminder) => reminder.prayer == PrayerName.fajr),
        isFalse,
      );
    });

    test('master notification switch silences reminders and adhan', () {
      final settings = AppSettings(location: _tunis)
          .copyWith(notificationsEnabled: false);
      expect(
        scheduler.buildRemindersForDay(
          day: _day,
          settings: settings,
          now: _midnight,
        ),
        isEmpty,
      );
      expect(
        scheduler.buildAdhansForDay(
          day: _day,
          settings: settings,
          now: _midnight,
        ),
        isEmpty,
      );
    });

    test('past reminders are skipped and never shifted later', () {
      final settings = AppSettings(location: _tunis);
      final noon = TimezoneService.atCivilTime(
        'Africa/Tunis',
        DateTime(2026, 7, 15),
        12,
        30,
      );
      final reminders = scheduler.buildRemindersForDay(
        day: _day,
        settings: settings,
        now: noon,
      );
      // Fajr and Dhuhr have already passed all six reminders.
      expect(reminders, hasLength(18));
      expect(
        reminders.any((reminder) =>
            reminder.prayer == PrayerName.fajr ||
            reminder.prayer == PrayerName.dhuhr),
        isFalse,
      );
      expect(
        reminders.every((reminder) => reminder.time.isAfter(noon)),
        isTrue,
      );
    });
  });

  group('full adhan', () {
    test('one adhan per enabled prayer at the adjusted prayer time', () {
      final settings = AppSettings(location: _tunis);
      final adhans = scheduler.buildAdhansForDay(
        day: _day,
        settings: settings,
        now: _midnight,
      );
      expect(adhans, hasLength(5));
      for (final adhan in adhans) {
        expect(adhan.time, _day.adjustedTime(adhan.prayer));
      }
      final ids = adhans.map((adhan) => adhan.id).toList();
      expect(ids.toSet(), hasLength(5));
      expect(ids.every((id) => id > 0 && id < 0x7FFFFFFF), isTrue);
      // Adhan ids must not collide with reminder ids.
      final reminders = scheduler.buildRemindersForDay(
        day: _day,
        settings: settings,
        now: _midnight,
      );
      expect(
        reminders.any((reminder) => ids.contains(reminder.id)),
        isFalse,
      );
    });

    test('adhan can be disabled per prayer', () {
      final settings = AppSettings(location: _tunis).withPrayerPref(
        PrayerName.fajr,
        const PrayerNotificationPref(adhanEnabled: false),
      );
      final adhans = scheduler.buildAdhansForDay(
        day: _day,
        settings: settings,
        now: _midnight,
      );
      expect(adhans, hasLength(4));
      expect(
        adhans.any((adhan) => adhan.prayer == PrayerName.fajr),
        isFalse,
      );
    });

    test('a multi-day horizon is de-duplicated and ordered', () {
      final secondDay = PrayerTimesService()
          .calculate(
            localDate: DateTime(2026, 7, 16),
            location: _tunis,
            config: const CalculationConfig(),
          )
          .day!;
      final settings = AppSettings(location: _tunis);
      final reminders = scheduler.buildReminderHorizon(
        days: <PrayerDay>[_day, secondDay],
        settings: settings,
        now: _midnight,
      );
      expect(reminders, hasLength(60));
      expect(
        reminders.map((reminder) => reminder.dedupeKey).toSet(),
        hasLength(60),
      );
      final adhans = scheduler.buildAdhanHorizon(
        days: <PrayerDay>[_day, secondDay],
        settings: settings,
        now: _midnight,
      );
      expect(adhans, hasLength(10));
      expect(
        adhans.map((adhan) => adhan.dedupeKey).toSet(),
        hasLength(10),
      );
    });
  });

  group('occasion sounds on their dates', () {
    // Mirrors NotificationScheduler.buildPlan's event pipeline. That class
    // imports package:flutter/foundation.dart and cannot run as a pure Dart
    // test; the contract below is exactly what the scheduler consumes.
    test('every scheduled occasion carries its own recorded sound', () {
      final events = IslamicEventsService().upcoming(
        from: DateTime.utc(2026, 1, 1),
        to: DateTime.utc(2026, 12, 31),
        timezoneId: 'Africa/Tunis',
      );
      expect(events, isNotEmpty);

      final dedupeKeys = <String>{};
      for (final event in events) {
        final raw = event.audioRaw;
        expect(raw, isNotNull,
            reason: '${event.type.label} (${event.key}) has no recorded sound');
        expect(
          File('android/app/src/main/res/raw/$raw.mp3').existsSync(),
          isTrue,
          reason: 'res/raw/$raw.mp3 is missing for ${event.key}',
        );
        expect(
          AudioAssetService.occasionChannelId(event.type),
          'rafel_event_$raw',
          reason: '${event.key} must play on its own channel',
        );
        expect(
          File(
            'assets/${AudioAssetService.occasionPreviewAsset(event.type)}',
          ).existsSync(),
          isTrue,
          reason: 'preview asset is missing for ${event.key}',
        );

        final id = NotificationIds.event(event.key);
        expect(id, greaterThan(0));
        expect(id, lessThan(0x7FFFFFFF));
        dedupeKeys.add('event|${event.key}');
      }
      // One plan per event occurrence — never a duplicate notification.
      expect(dedupeKeys, hasLength(events.length));
    });

    test('the Ramadan countdown is armed with the ramadhan_notifa sound', () {
      final events = IslamicEventsService().upcoming(
        from: DateTime.utc(2026, 1, 1),
        to: DateTime.utc(2026, 12, 31),
        timezoneId: 'Africa/Tunis',
      );
      final countdown =
          events.where((event) => event.type == OccasionType.ramadan).single;
      expect(countdown.key, 'ramadan_countdown_1447');
      expect(countdown.audioRaw, 'ramadhan_notifa');
      expect(
        AudioAssetService.occasionChannelId(OccasionType.ramadan),
        'rafel_event_ramadhan_notifa',
      );
    });
  });

  group('notification identifiers', () {
    test('ids are deterministic across runs and days', () {
      final one = NotificationIds.reminder(
        prayerDay: DateTime(2026, 7, 15),
        prayerIndex: 0,
        minutesBefore: 5,
      );
      final two = NotificationIds.reminder(
        prayerDay: DateTime(2026, 7, 15),
        prayerIndex: 0,
        minutesBefore: 5,
      );
      expect(one, two);
      expect(NotificationIds.event('eid_fitr_1447'),
          NotificationIds.event('eid_fitr_1447'));
      expect(NotificationIds.event('eid_fitr_1447'),
          isNot(NotificationIds.event('eid_adha_1447')));
    });

    test('event ids stay in the Android/iOS 31-bit range', () {
      for (final key in <String>[
        'ramadan_countdown_1447',
        'eid_fitr_1447_on_day',
        'white_days_1448_1_13_eve',
        'last_ten_1447_10',
      ]) {
        final id = NotificationIds.event(key);
        expect(id, greaterThan(0));
        expect(id, lessThan(0x7FFFFFFF));
      }
    });
  });
}
