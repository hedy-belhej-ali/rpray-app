import 'islamic_event.dart';
import 'prayer_name.dart';

/// A scheduled advance reminder. [id] is a stable Android/iOS notification id.
class ReminderPlan {
  const ReminderPlan({
    required this.id,
    required this.prayer,
    required this.minutesBefore,
    required this.time,
    required this.title,
    required this.body,
    required this.channelId,
    required this.soundRaw,
    required this.prayerTime,
    required this.dedupeKey,
  });

  final int id;
  final PrayerName prayer;
  final int minutesBefore;
  final DateTime time;
  final String title;
  final String body;
  final String channelId;
  final String? soundRaw;
  final DateTime prayerTime;
  final String dedupeKey;
}

/// A full-adhan alarm handled by the native Android foreground service.
class AdhanPlan {
  const AdhanPlan({
    required this.id,
    required this.prayer,
    required this.time,
    required this.title,
    required this.body,
    required this.dedupeKey,
  });

  final int id;
  final PrayerName prayer;
  final DateTime time;
  final String title;
  final String body;
  final String dedupeKey;
}

class EventPlan {
  const EventPlan({
    required this.id,
    required this.event,
    required this.channelId,
    required this.soundRaw,
    required this.dedupeKey,
  });

  final int id;
  final IslamicEvent event;
  final String channelId;
  final String? soundRaw;
  final String dedupeKey;

  DateTime get time => event.date;
}

/// A complete, de-duplicated scheduling snapshot produced before touching the
/// platform APIs. Keeping this pure makes the schedule testable.
class NotificationPlan {
  NotificationPlan({
    required this.generatedAt,
    required this.prayerHorizonEnd,
    required this.reminders,
    required this.adhans,
    required this.events,
    this.warnings = const <String>[],
    this.exactAlarmsAllowed = true,
  });

  final DateTime generatedAt;
  final DateTime prayerHorizonEnd;
  final List<ReminderPlan> reminders;
  final List<AdhanPlan> adhans;
  final List<EventPlan> events;
  final List<String> warnings;
  final bool exactAlarmsAllowed;

  int get notificationCount => reminders.length + events.length;
  int get adhanCount => adhans.length;

  List<String> get allDedupeKeys => <String>[
        ...reminders.map((item) => item.dedupeKey),
        ...adhans.map((item) => item.dedupeKey),
        ...events.map((item) => item.dedupeKey),
      ];

  /// Sanity check used before scheduling and by tests.
  bool get hasUniqueKeys =>
      allDedupeKeys.toSet().length == allDedupeKeys.length;
}
