import 'package:test/test.dart';
import 'package:rafel/models/app_settings.dart';
import 'package:rafel/models/islamic_event.dart';
import 'package:rafel/models/prayer_name.dart';
import 'package:rafel/models/prayer_settings.dart';

void main() {
  group('settings defaults', () {
    test('there is no built-in city or silent timezone default', () {
      final settings = AppSettings();
      expect(settings.location, isNull);
      expect(settings.hasLocation, isFalse);
      expect(settings.onboardingComplete, isFalse);
      expect(settings.hijriOffset, 0);
    });

    test('all five prayers default to every reminder and adhan', () {
      final settings = AppSettings();
      for (final prayer in PrayerName.values) {
        final pref = settings.prefFor(prayer);
        expect(pref.prayerEnabled, isTrue);
        expect(pref.adhanEnabled, isTrue);
        expect(pref.enabledIntervals, <int>{5, 10, 15, 20, 25, 30});
      }
    });

    test('the optional Mawlid occasion is off by default', () {
      final settings = AppSettings();
      expect(settings.occasionEnabled(OccasionType.mawlid), isFalse);
      expect(settings.occasionEnabled(OccasionType.ramadan), isTrue);
      expect(settings.occasionEnabled(OccasionType.eidAlFitr), isTrue);
    });

    test('the sighting offset is clamped to plus or minus two days', () {
      final settings = AppSettings();
      expect(settings.copyWith(hijriOffset: 5).hijriOffset, 2);
      expect(settings.copyWith(hijriOffset: -9).hijriOffset, -2);
      expect(settings.copyWith(hijriOffset: 1).hijriOffset, 1);
    });
  });

  group('settings persistence', () {
    test('a full settings object round-trips through JSON', () {
      final location = const GeoLocation(
        name: 'Tunis',
        latitude: 36.8065,
        longitude: 10.1815,
        timezoneId: 'Africa/Tunis',
        country: 'Tunisia',
        isDeviceLocation: true,
      );
      final override = EventDateOverride(
        key: 'eid_fitr_1447',
        date: DateTime(2026, 3, 21),
        status: EventDateStatus.confirmed,
        note: 'Local announcement',
      );
      final settings = AppSettings(
        location: location,
        hijriOffset: -1,
        onboardingComplete: true,
        locationPermissionDenied: true,
        calculation: const CalculationConfig(
          method: PrayerCalculationMethod.ummAlQura,
          madhab: AsrMadhab.hanafi,
          highLatitudeMethod: HighLatitudeMethod.seventhOfTheNight,
          adjustments: PrayerAdjustments(<PrayerName, int>{
            PrayerName.fajr: 3,
            PrayerName.maghrib: -2,
          }),
        ),
        prayerPrefs: <PrayerName, PrayerNotificationPref>{
          for (final prayer in PrayerName.values)
            prayer: PrayerNotificationPref(
              prayerEnabled: prayer != PrayerName.fajr,
              enabledIntervals: prayer == PrayerName.asr
                  ? const <int>{5, 30}
                  : const <int>{5, 10, 15, 20, 25, 30},
              adhanEnabled: prayer != PrayerName.maghrib,
            ),
        },
        occasionPrefs: <OccasionType, bool>{
          for (final type in OccasionType.values)
            type: type == OccasionType.mawlid,
        },
        dateOverrides: <String, EventDateOverride>{override.key: override},
      );

      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.location?.name, 'Tunis');
      expect(restored.location?.timezoneId, 'Africa/Tunis');
      expect(restored.location?.isDeviceLocation, isTrue);
      expect(restored.hijriOffset, -1);
      expect(restored.onboardingComplete, isTrue);
      expect(restored.locationPermissionDenied, isTrue);
      expect(restored.calculation.method, PrayerCalculationMethod.ummAlQura);
      expect(restored.calculation.madhab, AsrMadhab.hanafi);
      expect(restored.calculation.highLatitudeMethod,
          HighLatitudeMethod.seventhOfTheNight);
      expect(restored.calculation.adjustments.forPrayer(PrayerName.fajr), 3);
      expect(
          restored.calculation.adjustments.forPrayer(PrayerName.maghrib), -2);
      expect(restored.prefFor(PrayerName.fajr).prayerEnabled, isFalse);
      expect(restored.prefFor(PrayerName.asr).enabledIntervals,
          <int>{5, 30});
      expect(restored.prefFor(PrayerName.maghrib).adhanEnabled, isFalse);
      expect(restored.occasionEnabled(OccasionType.mawlid), isTrue);
      expect(restored.overrideFor('eid_fitr_1447')?.dateKey, '2026-03-21');
      expect(restored.overrideFor('eid_fitr_1447')?.status,
          EventDateStatus.confirmed);
    });

    test('unknown interval values are dropped, not persisted', () {
      final pref = PrayerNotificationPref.fromJson(<String, dynamic>{
        'prayerEnabled': false,
        'adhanEnabled': false,
        'intervals': <int>[5, 60, 10, 0, -5],
      });
      expect(pref.enabledIntervals, <int>{5, 10});
      expect(pref.prayerEnabled, isFalse);
      expect(pref.adhanEnabled, isFalse);
    });

    test('invalid saved locations are rejected on load', () {
      expect(
        GeoLocation.fromJson(<String, dynamic>{
          'name': 'Broken',
          'latitude': 200,
          'longitude': 10,
          'timezoneId': 'UTC',
        }),
        isNull,
      );
      expect(
        GeoLocation.fromJson(<String, dynamic>{
          'name': 'No timezone',
          'latitude': 36.8,
          'longitude': 10.1,
          'timezoneId': '',
        }),
        isNull,
      );
    });

    test('an estimated override cannot be persisted as confirmed', () {
      expect(
        EventDateOverride.fromJson(<String, dynamic>{
          'key': 'eid_fitr_1447',
          'date': '2026-03-21',
          'status': 'estimated',
        }),
        isNull,
      );
      final confirmed = EventDateOverride.fromJson(<String, dynamic>{
        'key': 'eid_fitr_1447',
        'date': '2026-03-21',
        'status': 'confirmed',
      });
      expect(confirmed, isNotNull);
      expect(confirmed!.dateKey, '2026-03-21');
      expect(confirmed.status, EventDateStatus.confirmed);
    });

    test('prayer adjustments clamp to plus or minus sixty minutes', () {
      final adjustments = const PrayerAdjustments()
          .withAdjustment(PrayerName.fajr, 90)
          .withAdjustment(PrayerName.isha, -90)
          .withAdjustment(PrayerName.dhuhr, 0);
      expect(adjustments.forPrayer(PrayerName.fajr), 60);
      expect(adjustments.forPrayer(PrayerName.isha), -60);
      expect(adjustments.forPrayer(PrayerName.dhuhr), 0);
      expect(adjustments.toJson(), <String, dynamic>{
        'fajr': 60,
        'isha': -60,
      });
    });
  });
}
