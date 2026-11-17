import '../core/date_formats.dart';
import '../models/app_settings.dart';
import '../models/notification_plan.dart';
import '../models/prayer_day.dart';
import '../models/prayer_name.dart';
import 'audio_asset_service.dart';
import 'notification_ids.dart';
import 'timezone_service.dart';

/// Pure scheduling logic for advance reminders and full-adhan alarms. No
/// platform calls happen here, so the entire schedule can be unit tested.
class PrayerScheduleService {
  List<ReminderPlan> buildRemindersForDay({
    required PrayerDay day,
    required AppSettings settings,
    required DateTime now,
  }) {
    if (!day.isValid || !settings.notificationsEnabled) {
      return const <ReminderPlan>[];
    }
    final output = <ReminderPlan>[];
    final seen = <String>{};
    final cutoff = now.add(const Duration(seconds: 1));

    for (final prayer in PrayerName.values) {
      final pref = settings.prefFor(prayer);
      if (!pref.prayerEnabled) continue;
      final prayerTime =
          TimezoneService.convert(day.adjustedTime(prayer), day.location.timezoneId);
      for (final minutes in reminderIntervalsDescending) {
        if (!pref.enabledIntervals.contains(minutes)) continue;
        final time = TimezoneService.convert(
          prayerTime.subtract(Duration(minutes: minutes)),
          day.location.timezoneId,
        );
        // Never move a missed reminder to a later time.
        if (!time.isAfter(cutoff)) continue;
        final key = 'reminder|${day.dateKey}|${prayer.key}|$minutes';
        if (!seen.add(key)) continue;
        output.add(
          ReminderPlan(
            id: NotificationIds.reminder(
              prayerDay: day.localDate,
              prayerIndex: prayer.index,
              minutesBefore: minutes,
            ),
            prayer: prayer,
            minutesBefore: minutes,
            time: time,
            title: '${prayer.englishLabel} in $minutes minutes',
            body: '${prayer.arabicLabel} · ${formatTime(prayerTime)} · '
                '${day.location.name}',
            channelId:
                AudioAssetService.reminderChannelId(prayer, minutes),
            soundRaw: AudioAssetService.reminderRaw(prayer, minutes),
            prayerTime: prayerTime,
            dedupeKey: key,
          ),
        );
      }
    }

    output.sort((a, b) => a.time.compareTo(b.time));
    return output;
  }

  List<ReminderPlan> buildReminderHorizon({
    required List<PrayerDay> days,
    required AppSettings settings,
    required DateTime now,
  }) {
    final seen = <String>{};
    final all = <ReminderPlan>[];
    for (final day in days) {
      for (final reminder in buildRemindersForDay(
        day: day,
        settings: settings,
        now: now,
      )) {
        if (seen.add(reminder.dedupeKey)) all.add(reminder);
      }
    }
    all.sort((a, b) => a.time.compareTo(b.time));
    return all;
  }

  List<AdhanPlan> buildAdhansForDay({
    required PrayerDay day,
    required AppSettings settings,
    required DateTime now,
  }) {
    if (!day.isValid || !settings.notificationsEnabled) {
      return const <AdhanPlan>[];
    }
    final cutoff = now.add(const Duration(seconds: 1));
    final output = <AdhanPlan>[];
    for (final prayer in PrayerName.values) {
      if (!settings.isAdhanEnabled(prayer)) continue;
      final time = TimezoneService.convert(
        day.adjustedTime(prayer),
        day.location.timezoneId,
      );
      if (!time.isAfter(cutoff)) continue;
      output.add(
        AdhanPlan(
          id: NotificationIds.adhan(
            prayerDay: day.localDate,
            prayerIndex: prayer.index,
          ),
          prayer: prayer,
          time: time,
          title: '${prayer.englishLabel} adhan',
          body: '${prayer.arabicLabel} · ${formatTime(time)} · '
              '${day.location.name}',
          dedupeKey: 'adhan|${day.dateKey}|${prayer.key}',
        ),
      );
    }
    output.sort((a, b) => a.time.compareTo(b.time));
    return output;
  }

  List<AdhanPlan> buildAdhanHorizon({
    required List<PrayerDay> days,
    required AppSettings settings,
    required DateTime now,
  }) {
    final seen = <String>{};
    final all = <AdhanPlan>[];
    for (final day in days) {
      for (final adhan in buildAdhansForDay(
        day: day,
        settings: settings,
        now: now,
      )) {
        if (seen.add(adhan.dedupeKey)) all.add(adhan);
      }
    }
    all.sort((a, b) => a.time.compareTo(b.time));
    return all;
  }
}
