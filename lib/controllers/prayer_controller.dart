import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../data/city_database.dart';
import '../models/app_settings.dart';
import '../models/islamic_event.dart';
import '../models/prayer_day.dart';
import '../models/prayer_name.dart';
import '../models/prayer_settings.dart';
import '../services/audio_asset_service.dart';
import '../services/audio_preview_service.dart';
import '../services/device_timezone_service.dart';
import '../services/hijri_calendar_service.dart';
import '../services/islamic_events_service.dart';
import '../services/native_adhan_service.dart';
import '../services/notification_scheduler.dart';
import '../services/notification_service.dart';
import '../services/prayer_schedule_service.dart';
import '../services/prayer_times_service.dart';
import '../services/settings_repository.dart';
import '../services/timezone_service.dart';

class NextPrayer {
  const NextPrayer({
    required this.prayer,
    required this.time,
    required this.day,
    required this.isTomorrow,
  });

  final PrayerName prayer;
  final DateTime time;
  final PrayerDay day;
  final bool isTomorrow;
}

/// Owns the live app state: persisted settings, the displayed prayer day,
/// countdown clock, Hijri date, occasions, permission state and scheduling.
class PrayerController extends ChangeNotifier {
  PrayerController({
    SettingsRepository? repository,
    PrayerTimesService? prayerTimes,
    PrayerScheduleService? prayerSchedule,
    IslamicEventsService? events,
    HijriCalendarService? hijri,
    NotificationService? notifications,
    NativeAdhanService? nativeAdhan,
    AudioPreviewService? preview,
    NotificationScheduler? scheduler,
    DateTime Function()? clock,
  })  : _repository = repository ?? SettingsRepository(),
        _prayerTimes = prayerTimes ?? PrayerTimesService(),
        _events = events ?? const IslamicEventsService(),
        _hijri = hijri ?? const HijriCalendarService(),
        _notifications = notifications ?? NotificationService(),
        _nativeAdhan = nativeAdhan ?? NativeAdhanService(),
        _preview = preview ?? AudioPreviewService(),
        _clock = clock ?? DateTime.now {
    _scheduler = scheduler ??
        NotificationScheduler(
          prayerTimes: _prayerTimes,
          schedule: prayerSchedule ?? PrayerScheduleService(),
          events: _events,
          notifications: _notifications,
          adhan: _nativeAdhan,
        );
  }

  final SettingsRepository _repository;
  final PrayerTimesService _prayerTimes;
  final IslamicEventsService _events;
  final HijriCalendarService _hijri;
  final NotificationService _notifications;
  final NativeAdhanService _nativeAdhan;
  final AudioPreviewService _preview;
  final DateTime Function() _clock;
  late final NotificationScheduler _scheduler;

  AppSettings _settings = AppSettings();
  bool _initialized = false;
  bool _loading = true;
  bool _busy = false;
  bool _locating = false;
  bool _scheduling = false;
  bool _scheduleQueued = false;
  bool _disposed = false;

  String? _error;
  String? _locationError;
  DateTime _now = DateTime.now();
  PrayerDay? _today;
  PrayerDay? _tomorrow;
  HijriDate? _hijriToday;
  HijriDate? _hijriTomorrow;
  List<IslamicEvent> _occasions = const <IslamicEvent>[];
  List<PrimaryOccasionDate> _primaryDates = const <PrimaryOccasionDate>[];
  NotificationPermissionState? _permission;
  ScheduleResult? _lastSchedule;
  bool _nativeExactAlarms = false;
  String _dayKey = '';
  String _deviceTimezoneId = 'UTC';
  PrayerName? _lastNextPrayerName;
  Timer? _ticker;
  Timer? _scheduleDebounce;

  AppSettings get settings => _settings;
  bool get isInitialized => _initialized;
  bool get isLoading => _loading;
  bool get isBusy => _busy;
  bool get isLocating => _locating;
  bool get isScheduling => _scheduling;
  String? get error => _error;
  String? get locationError => _locationError;
  DateTime get now => _now;
  PrayerDay? get today => _today;
  PrayerDay? get tomorrow => _tomorrow;
  HijriDate? get hijriToday => _hijriToday;
  HijriDate? get hijriTomorrow => _hijriTomorrow;
  List<IslamicEvent> get occasions => _occasions;
  List<PrimaryOccasionDate> get primaryDates => _primaryDates;
  NotificationPermissionState? get permission => _permission;
  ScheduleResult? get lastSchedule => _lastSchedule;
  bool get nativeExactAlarms => _nativeExactAlarms;
  String get deviceTimezoneId => _deviceTimezoneId;
  bool get hasLocation => _settings.location != null;
  bool get needsSetup => !_settings.onboardingComplete || !hasLocation;
  bool get notificationsSupported => _notifications.isSupported;
  AudioPreviewService get preview => _preview;
  ThemeMode get themeMode => _settings.isDarkTheme ? ThemeMode.dark : ThemeMode.light;

  NextPrayer? get nextPrayer {
    final day = _today;
    if (day != null) {
      final entry = day.nextAfter(_now);
      if (entry != null) {
        return NextPrayer(
          prayer: entry.prayer,
          time: entry.adjusted,
          day: day,
          isTomorrow: false,
        );
      }
    }
    final nextDay = _tomorrow;
    if (nextDay != null) {
      final entry = nextDay.entries[PrayerName.fajr];
      if (entry != null) {
        return NextPrayer(
          prayer: PrayerName.fajr,
          time: entry.adjusted,
          day: nextDay,
          isTomorrow: true,
        );
      }
    }
    return null;
  }

  Duration get countdown {
    final next = nextPrayer;
    if (next == null) return Duration.zero;
    final difference = next.time.difference(_now);
    return difference.isNegative ? Duration.zero : difference;
  }

  PrayerName? get nextPrayerName => nextPrayer?.prayer;

  PrayerTimeEntry? get lastPrayer {
    final day = _today;
    if (day == null) return null;
    return day.lastAtOrBefore(_now);
  }

  /// The next occasion that is still ahead, if any.
  IslamicEvent? get nextOccasion {
    for (final event in _occasions) {
      if (event.date.isAfter(_now)) return event;
    }
    return null;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    TimezoneService.initialize();
    _now = _clock();
    await _notifications.initialize();
    _deviceTimezoneId = await DeviceTimezoneService.deviceTimezoneId();
    _settings = await _repository.load();
    _permission = await _notifications.permissionState();
    _initialized = true;
    _loading = false;
    _recalculate();
    _startTicker();
    if (_settings.location != null) {
      unawaited(scheduleNow());
    }
    _notify();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_disposed) return;
    _now = _clock();
    final location = _settings.location;
    if (location != null) {
      final today =
          TimezoneService.todayAt(location.timezoneId, now: _now);
      final key = TimezoneService.civilDateKey(today);
      if (key != _dayKey) {
        _recalculate();
        _scheduleSoon();
        _notify();
        return;
      }
    }

    final currentNext = nextPrayer?.prayer;
    if (currentNext != _lastNextPrayerName) {
      _lastNextPrayerName = currentNext;
      _notify();
    }
  }

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    _notify();
    try {
      _now = _clock();
      _recalculate();
      await scheduleNow();
    } finally {
      _busy = false;
      _notify();
    }
  }

  void onAppResumed() {
    _now = _clock();
    _recalculate();
    _notify();
    if (_settings.location != null) {
      unawaited(scheduleNow());
    }
  }

  void onAppPaused() {
    unawaited(_preview.stop());
  }

  void _recalculate() {
    final location = _settings.location;
    if (location == null || !location.isValid) {
      _today = null;
      _tomorrow = null;
      _hijriToday = null;
      _hijriTomorrow = null;
      _occasions = const <IslamicEvent>[];
      _primaryDates = const <PrimaryOccasionDate>[];
      _dayKey = '';
      _error = null;
      _lastNextPrayerName = null;
      return;
    }
    TimezoneService.initialize();
    final todayCivil =
        TimezoneService.todayAt(location.timezoneId, now: _now);
    final today = DateTime(todayCivil.year, todayCivil.month, todayCivil.day);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    _dayKey = TimezoneService.civilDateKey(today);

    final todayOutcome = _prayerTimes.calculate(
      localDate: today,
      location: location,
      config: _settings.calculation,
      now: _now,
    );
    final tomorrowOutcome = _prayerTimes.calculate(
      localDate: tomorrow,
      location: location,
      config: _settings.calculation,
      now: _now,
    );
    _today = todayOutcome.day;
    _tomorrow = tomorrowOutcome.day;

    final errors = <String>[
      ...todayOutcome.errors,
      if (tomorrowOutcome.errors.isNotEmpty &&
          todayOutcome.errors.isEmpty)
        'Tomorrow: ${tomorrowOutcome.errors.first}',
    ];
    _error = errors.isEmpty ? null : errors.join('\n');

    _hijriToday = _hijri.fromGregorian(
      today,
      offsetDays: _settings.hijriOffset,
    );
    _hijriTomorrow = _hijri.fromGregorian(
      tomorrow,
      offsetDays: _settings.hijriOffset,
    );

    final from = TimezoneService.convert(_now, location.timezoneId);
    final to = TimezoneService.addCivilDays(
      location.timezoneId,
      from,
      366,
    );
    _occasions = _events.upcoming(
      from: from,
      to: to,
      timezoneId: location.timezoneId,
      hijriOffset: _settings.hijriOffset,
      overrides: _settings.dateOverrides,
    );
    _primaryDates = _events.primaryDates(
      from: from,
      to: TimezoneService.addCivilDays(location.timezoneId, from, 420),
      timezoneId: location.timezoneId,
      hijriOffset: _settings.hijriOffset,
      overrides: _settings.dateOverrides,
    );
    _lastNextPrayerName = nextPrayer?.prayer;
  }

  Future<void> updateSettings(
    AppSettings next, {
    bool recalculate = true,
    bool reschedule = true,
  }) async {
    _settings = next;
    await _repository.save(next);
    if (recalculate) {
      _prayerTimes.clearCache();
      _recalculate();
    }
    _notify();
    if (reschedule) _scheduleSoon();
  }

  Future<void> applyCity(CityInfo city) async {
    await applyLocation(
      city.toLocation(),
      suggestedMethod: city.suggestedMethod,
    );
  }

  Future<void> applyLocation(
    GeoLocation location, {
    PrayerCalculationMethod? suggestedMethod,
  }) async {
    _prayerTimes.clearCache();
    await updateSettings(
      _settings.copyWith(
        location: location,
        calculation: suggestedMethod == null
            ? _settings.calculation
            : _settings.calculation.copyWith(method: suggestedMethod),
        locationPermissionDenied: false,
      ),
    );
  }

  Future<void> setLocation(GeoLocation location) =>
      applyLocation(location);

  Future<bool> useDeviceLocation() async {
    if (_locating) return false;
    _locating = true;
    _locationError = null;
    _notify();
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationError =
            'Location services are switched off. Turn them on, or choose a '
            'city manually.';
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationError = permission == LocationPermission.deniedForever
            ? 'Location permission is blocked in system settings. Choose a '
                'city manually, or enable it in Settings.'
            : 'Location permission was not granted. You can still choose a '
                'city manually.';
        await updateSettings(
          _settings.copyWith(locationPermissionDenied: true),
          recalculate: false,
          reschedule: false,
        );
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );
      final timezoneId = await DeviceTimezoneService.deviceTimezoneId();

      // Resolve the coordinates to a real city name (e.g. Kelibia, not Tunis).
      String resolvedName = 'Current location';
      String? resolvedCountry;
      try {
        final resolved = await _reverseGeocode(position.latitude, position.longitude);
        if (resolved != null) {
          resolvedName = resolved['name'] as String;
          resolvedCountry = resolved['country'] as String?;
        }
      } catch (_) {
        // Reverse geocoding is optional; fall back gracefully.
      }

      final location = GeoLocation(
        name: resolvedName,
        country: resolvedCountry,
        latitude: position.latitude,
        longitude: position.longitude,
        timezoneId: timezoneId,
        isDeviceLocation: true,
      );
      _prayerTimes.clearCache();
      await updateSettings(
        _settings.copyWith(
          location: location,
          locationPermissionDenied: false,
        ),
      );
      return true;
    } on TimeoutException {
      _locationError =
          'The location fix timed out. Move to an open area and try again, '
          'or choose a city manually.';
      return false;
    } catch (error) {
      _locationError = 'Could not read the device location. $error';
      return false;
    } finally {
      _locating = false;
      _notify();
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await updateSettings(
      _settings.copyWith(notificationsEnabled: enabled),
      recalculate: false,
    );
  }

  /// Reverse-geocodes [latitude]/[longitude] via Nominatim (OpenStreetMap).
  /// Returns the city/town name and country, or null on failure.
  Future<Map<String, dynamic>?> _reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse',
    ).replace(
      queryParameters: <String, String>{
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
      },
    );
    try {
      final response = await http.get(
        uri,
        headers: <String, String>{
          'User-Agent': 'Rpray/1.0.0 (prayer-times app)',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) return null;
      final displayName = data['display_name']?.toString();
      final name = address['city'] ??
          address['town'] ??
          address['village'] ??
          address['municipality'] ??
          address['county'] ??
          (displayName?.split(',').first.trim());
      final country = address['country'] as String?;
      if (name == null || name is! String || name.isEmpty) return null;
      return <String, dynamic>{
        'name': name,
        'country': country,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> setPrayerEnabled(PrayerName prayer, bool enabled) async {
    final pref = _settings.prefFor(prayer).copyWith(prayerEnabled: enabled);
    await updateSettings(
      _settings.withPrayerPref(prayer, pref),
      recalculate: false,
    );
  }

  Future<void> setReminderEnabled(
    PrayerName prayer,
    int minutes,
    bool enabled,
  ) async {
    final pref = _settings.prefFor(prayer);
    final intervals = Set<int>.from(pref.enabledIntervals);
    if (enabled) {
      intervals.add(minutes);
    } else {
      intervals.remove(minutes);
    }
    await updateSettings(
      _settings.withPrayerPref(
        prayer,
        pref.copyWith(enabledIntervals: intervals),
      ),
      recalculate: false,
    );
  }

  Future<void> setAdhanEnabled(PrayerName prayer, bool enabled) async {
    final pref = _settings.prefFor(prayer).copyWith(adhanEnabled: enabled);
    await updateSettings(
      _settings.withPrayerPref(prayer, pref),
      recalculate: false,
    );
  }

  Future<void> setOccasionEnabled(OccasionType type, bool enabled) async {
    await updateSettings(
      _settings.withOccasion(type, enabled),
      recalculate: false,
    );
  }

  Future<void> setMethod(PrayerCalculationMethod method) async {
    await updateSettings(
      _settings.copyWith(
        calculation: _settings.calculation.copyWith(method: method),
      ),
    );
  }

  Future<void> setMadhab(AsrMadhab madhab) async {
    await updateSettings(
      _settings.copyWith(
        calculation: _settings.calculation.copyWith(madhab: madhab),
      ),
    );
  }

  Future<void> setHighLatitude(HighLatitudeMethod method) async {
    await updateSettings(
      _settings.copyWith(
        calculation: _settings.calculation.copyWith(highLatitudeMethod: method),
      ),
    );
  }

  Future<void> setAdjustment(PrayerName prayer, int minutes) async {
    final adjustments =
        _settings.calculation.adjustments.withAdjustment(prayer, minutes);
    await updateSettings(
      _settings.copyWith(
        calculation: _settings.calculation.copyWith(adjustments: adjustments),
      ),
    );
  }

  Future<void> resetAdjustments() async {
    await updateSettings(
      _settings.copyWith(
        calculation: _settings.calculation
            .copyWith(adjustments: const PrayerAdjustments()),
      ),
    );
  }

  Future<void> setHijriOffset(int offset) async {
    await updateSettings(_settings.copyWith(hijriOffset: offset));
  }

  Future<void> setOverride(EventDateOverride override) async {
    await updateSettings(_settings.withOverride(override));
  }

  Future<void> clearOverride(String key) async {
    await updateSettings(_settings.withoutOverride(key));
  }

  Future<void> setOnboardingComplete(bool complete) async {
    await updateSettings(
      _settings.copyWith(onboardingComplete: complete),
      reschedule: false,
    );
  }

  Future<void> setThemeMode(bool isDark) async {
    await updateSettings(
      _settings.copyWith(isDarkTheme: isDark),
      reschedule: false,
    );
  }

  Future<NotificationPermissionState> requestNotificationPermissions({
    bool enableOnGrant = false,
  }) async {
    final state = await _notifications.requestPermissions();
    _permission = state;
    _nativeExactAlarms = await _nativeAdhan.isAlarmPermissionGranted();
    if (enableOnGrant && state.notificationsGranted) {
      await updateSettings(
        _settings.copyWith(notificationsEnabled: true),
        recalculate: false,
        reschedule: false,
      );
    }
    _notify();
    return state;
  }

  Future<void> refreshPermissionState() async {
    _permission = await _notifications.permissionState();
    _nativeExactAlarms = await _nativeAdhan.isAlarmPermissionGranted();
    _notify();
  }

  Future<void> openNotificationSettings() =>
      _notifications.openNotificationSettings();

  Future<ScheduleResult?> scheduleNow() async {
    if (_disposed) return null;
    if (_scheduling) {
      _scheduleQueued = true;
      return null;
    }
    _scheduling = true;
    _notify();
    try {
      final result = await _scheduler.rescheduleAll(
        settings: _settings,
        now: _now,
      );
      _lastSchedule = result;
      _permission = await _notifications.permissionState();
      _nativeExactAlarms = await _nativeAdhan.isAlarmPermissionGranted();
      return result;
    } catch (error) {
      _error = 'Scheduling failed: $error';
      return null;
    } finally {
      _scheduling = false;
      _notify();
      if (_scheduleQueued && !_disposed) {
        _scheduleQueued = false;
        unawaited(scheduleNow());
      }
    }
  }

  Future<void> sendTestNotification() => _notifications.showTestNotification();

  Future<int> pendingNotificationCount() => _notifications.pendingCount();

  void _scheduleSoon() {
    _scheduleDebounce?.cancel();
    _scheduleDebounce = Timer(const Duration(milliseconds: 900), () {
      unawaited(scheduleNow());
    });
  }

  Future<void> togglePreview(String asset) async {
    if (_preview.playingAsset.value == asset) {
      await _preview.stop();
    } else {
      await _preview.playAsset(asset);
    }
  }

  Future<void> previewReminder(PrayerName prayer, int minutes) =>
      togglePreview(AudioAssetService.reminderPreviewAsset(prayer, minutes));

  Future<void> previewAdhan() =>
      togglePreview(AudioAssetService.adhanPreviewAsset);

  Future<void> previewOccasion(OccasionType type) async {
    final asset = AudioAssetService.occasionPreviewAsset(type);
    if (asset == null) return;
    await togglePreview(asset);
  }

  Future<void> stopPreview() => _preview.stop();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _scheduleDebounce?.cancel();
    unawaited(_preview.dispose());
    super.dispose();
  }
}

