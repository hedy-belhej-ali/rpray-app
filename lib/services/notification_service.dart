import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/islamic_event.dart';
import '../models/notification_plan.dart';
import '../models/prayer_name.dart';
import 'audio_asset_service.dart';
import 'notification_ids.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _supported = true;
  String? _initializationError;

  bool get isInitialized => _initialized;
  bool get isSupported => _supported;
  String? get initializationError => _initializationError;

  bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_initialized) return;
    if (!isMobile) {
      _supported = false;
      _initializationError =
          'Reliable scheduled notifications are implemented for Android and iOS.';
      return;
    }
    try {
      const android = AndroidInitializationSettings('@drawable/ic_stat_rafel');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
      await _createChannels();
      _initialized = true;
    } catch (error) {
      _initialized = false;
      _supported = false;
      _initializationError = error.toString();
    }
  }

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    for (final prayer in PrayerName.values) {
      for (final minutes in const <int>[5, 10, 15, 20, 25, 30]) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            AudioAssetService.reminderChannelId(prayer, minutes),
            AudioAssetService.reminderChannelName(prayer, minutes),
            description: 'Advance reminder recorded for '
                '${prayer.englishLabel.toLowerCase()} at $minutes minutes.',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(
              AudioAssetService.reminderRaw(prayer, minutes),
            ),
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.notification,
          ),
        );
      }
    }

    for (final type in OccasionType.values) {
      final raw = type.audioRaw;
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          AudioAssetService.occasionChannelId(type),
          raw == null ? 'Islamic occasions · Rpray' : '${type.label} · Rpray',
          description: raw == null
              ? 'Ramadan countdown and occasion reminders with the default sound.'
              : 'Notifications for ${type.label}.',
          importance: Importance.high,
          playSound: true,
          sound: raw == null
              ? null
              : RawResourceAndroidNotificationSound(raw),
          enableVibration: true,
        ),
      );
    }

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'rafel_test',
        'Rpray test notifications',
        description: 'Used only when you send a test notification.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  Future<NotificationPermissionState> requestPermissions() async {
    if (!isMobile) {
      return const NotificationPermissionState(
        notificationsGranted: false,
        exactAlarmsGranted: false,
        supported: false,
      );
    }
    if (!_initialized) await initialize();
    var notifications = false;
    var exact = false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        notifications = granted ?? false;
        exact = await android?.canScheduleExactNotifications() ?? false;
        if (!exact) {
          exact = await android?.requestExactAlarmsPermission() ?? false;
        }
      } else {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        notifications = await ios?.requestPermissions(
              sound: true,
              alert: true,
              badge: true,
            ) ??
            false;
        exact = true;
      }
    } catch (_) {
      // Permission errors are reported through the returned state.
    }
    return NotificationPermissionState(
      notificationsGranted: notifications,
      exactAlarmsGranted: exact,
      supported: _supported,
    );
  }

  Future<NotificationPermissionState> permissionState() async {
    if (!isMobile) {
      return const NotificationPermissionState(
        notificationsGranted: false,
        exactAlarmsGranted: false,
        supported: false,
      );
    }
    if (!_initialized) await initialize();
    var notifications = false;
    var exact = false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        notifications = await android?.areNotificationsEnabled() ?? false;
        exact = await android?.canScheduleExactNotifications() ?? false;
      } else {
        notifications = true;
        exact = true;
      }
    } catch (_) {
      // Keep conservative defaults.
    }
    return NotificationPermissionState(
      notificationsGranted: notifications,
      exactAlarmsGranted: exact,
      supported: _supported,
    );
  }

  Future<void> scheduleReminder(
    ReminderPlan plan, {
    required bool exact,
  }) async {
    if (!_initialized || !_supported) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        plan.channelId,
        AudioAssetService.reminderChannelName(plan.prayer, plan.minutesBefore),
        channelDescription: 'Advance prayer reminders.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: plan.soundRaw == null
            ? null
            : RawResourceAndroidNotificationSound(plan.soundRaw!),
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        icon: 'ic_stat_rafel',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _schedule(
      id: plan.id,
      title: plan.title,
      body: plan.body,
      time: plan.time,
      details: details,
      exact: exact,
      payload: plan.dedupeKey,
    );
  }

  Future<void> scheduleEvent(EventPlan plan, {required bool exact}) async {
    if (!_initialized || !_supported) return;
    final raw = plan.soundRaw;
    final type = plan.event.type;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        plan.channelId,
        raw == null
            ? 'Islamic occasions · Rpray'
            : AudioAssetService.occasionChannelName(type),
        channelDescription: 'Islamic occasion notifications.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: raw == null ? null : RawResourceAndroidNotificationSound(raw),
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        icon: 'ic_stat_rafel',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _schedule(
      id: plan.id,
      title: plan.event.title,
      body: plan.event.message,
      time: plan.time,
      details: details,
      exact: exact,
      payload: plan.dedupeKey,
    );
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime time,
    required NotificationDetails details,
    required bool exact,
    required String payload,
  }) async {
    final localTime = tz.TZDateTime.from(time, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: localTime,
      notificationDetails: details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelAllPending() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAllPendingNotifications();
    } catch (_) {
      // Cancellation is best-effort during teardown/reconfigure.
    }
  }

  Future<int> pendingCount() async {
    if (!_initialized) return 0;
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();
    if (!_supported) return;
    await _plugin.show(
      id: NotificationIds.testId,
      title: 'Rpray is ready 🌙',
      body: 'Notifications are working on this device.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'rafel_test',
          'Rpray test notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_rafel',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> openNotificationSettings() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.openAppNotificationSettings();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.openAppNotificationSettings();
      }
    } catch (_) {
      // Not all platforms expose this.
    }
  }
}

class NotificationPermissionState {
  const NotificationPermissionState({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
    required this.supported,
  });

  final bool notificationsGranted;
  final bool exactAlarmsGranted;
  final bool supported;
}
