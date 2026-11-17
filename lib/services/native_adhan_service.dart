import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/notification_plan.dart';

/// Thin bridge to the native Android alarm + foreground-service adhan player.
/// The native implementation is required because a notification-channel sound
/// is not a reliable way to play a multi-minute recording.
class NativeAdhanService {
  static const MethodChannel _channel = MethodChannel('rafel/adhan');

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<NativeAdhanResult> scheduleAll(List<AdhanPlan> plans) async {
    if (!isSupported) {
      return const NativeAdhanResult(
        supported: false,
        scheduled: 0,
        message: 'Full background adhan playback is Android-only in Rpray.',
      );
    }
    try {
      final payload = plans
          .map(
            (plan) => <String, Object>{
              'id': plan.id,
              'triggerAtMillis': plan.time.millisecondsSinceEpoch,
              'prayer': plan.prayer.key,
              'title': plan.title,
              'body': plan.body,
            },
          )
          .toList(growable: false);
      await _channel.invokeMethod<void>('scheduleAdhan', payload);
      return NativeAdhanResult(
        supported: true,
        scheduled: payload.length,
        message: 'Scheduled ${payload.length} adhan alarms.',
      );
    } catch (error) {
      return NativeAdhanResult(
        supported: true,
        scheduled: 0,
        message: 'Native adhan scheduling failed: $error',
      );
    }
  }

  Future<void> cancelAll() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('cancelAllAdhan');
    } catch (_) {
      // The Dart side remains usable even if the native service is absent.
    }
  }

  Future<void> stopPlayback() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('stopAdhan');
    } catch (_) {
      // Ignore.
    }
  }

  Future<bool> isAlarmPermissionGranted() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ??
          false;
    } catch (_) {
      return false;
    }
  }
}

class NativeAdhanResult {
  const NativeAdhanResult({
    required this.supported,
    required this.scheduled,
    required this.message,
  });

  final bool supported;
  final int scheduled;
  final String message;
}
