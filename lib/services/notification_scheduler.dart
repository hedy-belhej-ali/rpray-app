import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/notification_plan.dart';
import '../models/prayer_day.dart';
import '../services/audio_asset_service.dart';
import '../services/islamic_events_service.dart';
import '../services/native_adhan_service.dart';
import '../services/notification_ids.dart';
import '../services/notification_service.dart';
import '../services/prayer_schedule_service.dart';
import '../services/prayer_times_service.dart';
import '../services/timezone_service.dart';

class ScheduleResult {
  const ScheduleResult({
    required this.plan,
    required this.scheduledNotifications,
    required this.scheduledAdhans,
    required this.errors,
    required this.warnings,
    required this.exactAlarms,
    required this.completedAt,
  });

  final NotificationPlan plan;
  final int scheduledNotifications;
  final int scheduledAdhans;
  final List<String> errors;
  final List<String> warnings;
  final bool exactAlarms;
  final DateTime completedAt;

  bool get success => errors.isEmpty;
}

/// Orchestrates prayer reminders, Islamic occasions and native adhan alarms.
/// A reschedule always cancels the previous Rpray notifications first, which
/// prevents duplicates and stale reminders after a settings/location change.
class NotificationScheduler {
  NotificationScheduler({
    required this.prayerTimes,
    required this.schedule,
    required this.events,
    required this.notifications,
    required this.adhan,
  });

  final PrayerTimesService prayerTimes;
  final PrayerScheduleService schedule;
  final IslamicEventsService events;
  final NotificationService notifications;
  final NativeAdhanService adhan;

  static const int androidNotificationCap = 450;
  static const int iosNotificationCap = 56;
  static const int prayerHorizonDays = 10;
  static const int occasionHorizonDays = 180;

  NotificationPlan buildPlan({
    required AppSettings settings,
    DateTime? now,
    int prayerDays = prayerHorizonDays,
    int occasionDays = occasionHorizonDays,
    bool exactAlarmsAllowed = true,
  }) {
    final generatedAt = now ?? DateTime.now();
    final location = settings.location;
    if (location == null) {
      return NotificationPlan(
        generatedAt: generatedAt,
        prayerHorizonEnd: generatedAt,
        reminders: const <ReminderPlan>[],
        adhans: const <AdhanPlan>[],
        events: const <EventPlan>[],
        warnings: const <String>[
          'Choose a location before Rpray can schedule notifications.',
        ],
        exactAlarmsAllowed: exactAlarmsAllowed,
      );
    }

    TimezoneService.initialize();
    final today = TimezoneService.todayAt(location.timezoneId, now: generatedAt);
    final days = <PrayerDay>[];
    final warnings = <String>[];
    for (var i = 0; i < prayerDays; i++) {
      final civil =
          DateTime(today.year, today.month, today.day + i);
      final outcome = prayerTimes.calculate(
        localDate: civil,
        location: location,
        config: settings.calculation,
        now: generatedAt,
      );
      if (outcome.day != null && outcome.day!.isValid) {
        days.add(outcome.day!);
      } else {
        final reason = outcome.errors.isEmpty
            ? 'unknown calculation error'
            : outcome.errors.first;
        warnings.add(
          'No notifications for ${TimezoneService.civilDateKey(civil)}: $reason',
        );
      }
    }

    final reminders = settings.notificationsEnabled
        ? schedule.buildReminderHorizon(
            days: days,
            settings: settings,
            now: generatedAt,
          )
        : <ReminderPlan>[];
    final adhans = settings.notificationsEnabled
        ? schedule.buildAdhanHorizon(
            days: days,
            settings: settings,
            now: generatedAt,
          )
        : <AdhanPlan>[];

    final fromLocal =
        TimezoneService.convert(generatedAt, location.timezoneId);
    final toLocal = fromLocal.add(Duration(days: occasionDays));
    final generatedEvents = events.upcoming(
      from: fromLocal,
      to: toLocal,
      timezoneId: location.timezoneId,
      hijriOffset: settings.hijriOffset,
      overrides: settings.dateOverrides,
    );

    final eventPlans = <EventPlan>[];
    for (final event in generatedEvents) {
      if (!settings.notificationsEnabled) continue;
      if (!settings.occasionEnabled(event.type)) continue;
      eventPlans.add(
        EventPlan(
          id: NotificationIds.event(event.key),
          event: event,
          channelId: AudioAssetService.occasionChannelId(event.type),
          soundRaw: event.audioRaw,
          dedupeKey: 'event|${event.key}',
        ),
      );
    }

    final horizonEnd = today.add(Duration(days: prayerDays));
    final plan = NotificationPlan(
      generatedAt: generatedAt,
      prayerHorizonEnd: horizonEnd,
      reminders: reminders,
      adhans: adhans,
      events: eventPlans,
      warnings: <String>[
        ...warnings,
        for (final day in days) ...day.warnings,
      ],
      exactAlarmsAllowed: exactAlarmsAllowed,
    );
    return _dedupe(plan);
  }

  Future<ScheduleResult> rescheduleAll({
    required AppSettings settings,
    DateTime? now,
    bool force = false,
  }) async {
    final startedAt = now ?? DateTime.now();
    final errors = <String>[];
    final warnings = <String>[];
    final platformSupported = notifications.isSupported;

    await notifications.cancelAllPending();
    await adhan.cancelAll();

    if (!settings.notificationsEnabled) {
      return ScheduleResult(
        plan: buildPlan(settings: settings, now: startedAt),
        scheduledNotifications: 0,
        scheduledAdhans: 0,
        errors: const <String>[],
        warnings: const <String>['Notifications are turned off.'],
        exactAlarms: false,
        completedAt: startedAt,
      );
    }
    if (settings.location == null) {
      return ScheduleResult(
        plan: buildPlan(settings: settings, now: startedAt),
        scheduledNotifications: 0,
        scheduledAdhans: 0,
        errors: const <String>[],
        warnings: const <String>[
          'Choose a location before Rpray can schedule notifications.',
        ],
        exactAlarms: false,
        completedAt: startedAt,
      );
    }

    await notifications.initialize();
    await notifications.ensureChannels();
    final permission = await notifications.permissionState();
    var exact = permission.exactAlarmsGranted;
    if (!permission.notificationsGranted) {
      warnings.add(
        'Notification permission is not granted. Enable it so reminders can '
        'appear.',
      );
    }
    if (!exact && defaultTargetPlatform == TargetPlatform.android) {
      warnings.add(
        'Exact alarms are not allowed. Notifications are scheduled '
        'inexactly until the permission is granted.',
      );
    }

    var plan = buildPlan(
      settings: settings,
      now: startedAt,
      exactAlarmsAllowed: exact,
    );
    plan = _applyPlatformLimit(plan, warnings);

    var notificationsScheduled = 0;
    var sinceYield = 0;
    Future<void> breathe() async {
      if (++sinceYield < 12) return;
      sinceYield = 0;
      // Yield to the UI isolate so re-arming hundreds of alarms never blocks
      // scrolling or the first taps after launch.
      await Future<void>.delayed(Duration.zero);
    }

    if (platformSupported) {
      for (final reminder in plan.reminders) {
        try {
          await notifications.scheduleReminder(reminder, exact: exact);
          notificationsScheduled++;
        } catch (error) {
          errors.add('Reminder ${reminder.dedupeKey}: $error');
        }
        await breathe();
      }
      for (final event in plan.events) {
        try {
          await notifications.scheduleEvent(event, exact: exact);
          notificationsScheduled++;
        } catch (error) {
          errors.add('Occasion ${event.dedupeKey}: $error');
        }
        await breathe();
      }
    } else {
      warnings.add(notifications.initializationError ??
          'Scheduled notifications are not available on this platform.');
    }

    var adhansScheduled = 0;
    if (plan.adhans.isNotEmpty) {
      final nativeResult = await adhan.scheduleAll(plan.adhans);
      adhansScheduled = nativeResult.scheduled;
      if (!nativeResult.supported) {
        warnings.add(nativeResult.message);
      } else if (nativeResult.scheduled != plan.adhans.length) {
        warnings.add(nativeResult.message);
      }
    }

    if (defaultTargetPlatform == TargetPlatform.iOS && plan.events.isNotEmpty) {
      warnings.add(
        'iOS cannot use the MP3 recordings as notification sounds. Rpray '
        'uses the system notification sound on iOS.',
      );
    }

    return ScheduleResult(
      plan: plan,
      scheduledNotifications: notificationsScheduled,
      scheduledAdhans: adhansScheduled,
      errors: errors,
      warnings: <String>[...plan.warnings, ...warnings],
      exactAlarms: exact,
      completedAt: DateTime.now(),
    );
  }

  NotificationPlan _applyPlatformLimit(
    NotificationPlan plan,
    List<String> warnings,
  ) {
    final cap = defaultTargetPlatform == TargetPlatform.iOS
        ? iosNotificationCap
        : androidNotificationCap;
    final total = plan.reminders.length + plan.events.length;
    if (total <= cap) return plan;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS allows at most 64 pending notifications; keep the closest ones.
      final combined = <_SortableNotification>[
        ...plan.reminders.map(
          (item) => _SortableNotification(item.time, reminder: item),
        ),
        ...plan.events.map(
          (item) => _SortableNotification(item.time, event: item),
        ),
      ]..sort((a, b) => a.time.compareTo(b.time));
      final kept = combined.take(cap).toList(growable: false);
      warnings.add(
        'iOS keeps only the $cap nearest notifications; Rpray will refresh '
        'them when the app opens.',
      );
      return NotificationPlan(
        generatedAt: plan.generatedAt,
        prayerHorizonEnd: plan.prayerHorizonEnd,
        reminders: kept
            .where((item) => item.reminder != null)
            .map((item) => item.reminder!)
            .toList(),
        adhans: plan.adhans,
        events: kept
            .where((item) => item.event != null)
            .map((item) => item.event!)
            .toList(),
        warnings: plan.warnings,
        exactAlarmsAllowed: plan.exactAlarmsAllowed,
      );
    }

    // Android: prayer reminders take priority; only fill the remaining space
    // with the nearest occasion notifications.
    final trimmedReminders = plan.reminders.take(cap).toList(growable: false);
    final available = cap - trimmedReminders.length;
    final trimmedEvents = plan.events.take(available).toList(growable: false);
    warnings.add(
      'Notification limit applied: the nearest $cap reminders were kept.',
    );
    return NotificationPlan(
      generatedAt: plan.generatedAt,
      prayerHorizonEnd: plan.prayerHorizonEnd,
      reminders: trimmedReminders,
      adhans: plan.adhans,
      events: trimmedEvents,
      warnings: plan.warnings,
      exactAlarmsAllowed: plan.exactAlarmsAllowed,
    );
  }

  NotificationPlan _dedupe(NotificationPlan plan) {
    final keys = <String>{};
    final ids = <int>{};
    final reminders = <ReminderPlan>[];
    final adhans = <AdhanPlan>[];
    final events = <EventPlan>[];

    for (final item in plan.reminders) {
      if (keys.add(item.dedupeKey) && ids.add(item.id)) reminders.add(item);
    }
    for (final item in plan.adhans) {
      if (keys.add(item.dedupeKey) && ids.add(item.id)) adhans.add(item);
    }
    for (final item in plan.events) {
      if (keys.add(item.dedupeKey) && ids.add(item.id)) events.add(item);
    }

    return NotificationPlan(
      generatedAt: plan.generatedAt,
      prayerHorizonEnd: plan.prayerHorizonEnd,
      reminders: reminders,
      adhans: adhans,
      events: events,
      warnings: plan.warnings,
      exactAlarmsAllowed: plan.exactAlarmsAllowed,
    );
  }

  Future<void> cancelEverything() async {
    await notifications.cancelAllPending();
    await adhan.cancelAll();
  }
}

class _SortableNotification {
  _SortableNotification(this.time, {this.reminder, this.event});

  final DateTime time;
  final ReminderPlan? reminder;
  final EventPlan? event;
}
