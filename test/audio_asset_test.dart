import 'dart:io';

import 'package:test/test.dart';
import 'package:rafel/models/islamic_event.dart';
import 'package:rafel/models/prayer_name.dart';
import 'package:rafel/services/audio_asset_service.dart';

void main() {
  group('packaged voice assets', () {
    test('all 30 advance reminders and the full adhan are present', () {
      expect(File(AudioAssetService.adhanAsset).existsSync(), isTrue);
      expect(
        File('android/app/src/main/res/raw/${AudioAssetService.adhanRaw}.mp3')
            .existsSync(),
        isTrue,
      );

      final assets = <String>{};
      final raws = <String>{};
      for (final prayer in PrayerName.values) {
        for (final minutes in const <int>[5, 10, 15, 20, 25, 30]) {
          final asset = AudioAssetService.reminderAsset(prayer, minutes);
          expect(File(asset).existsSync(), isTrue, reason: asset);
          assets.add(asset);

          final raw = AudioAssetService.reminderRaw(prayer, minutes);
          raws.add(raw);
          final rawFile = File('android/app/src/main/res/raw/$raw.mp3');
          expect(rawFile.existsSync(), isTrue, reason: rawFile.path);
        }
      }
      expect(assets, hasLength(30));
      expect(raws, hasLength(30));
    });

    test('every occasion with audio has a preview asset and a raw resource',
        () {
      var withAudio = 0;
      for (final type in OccasionType.values) {
        final raw = AudioAssetService.occasionRaw(type);
        if (raw == null) continue;
        withAudio++;
        expect(
          File('android/app/src/main/res/raw/$raw.mp3').existsSync(),
          isTrue,
          reason: '$raw.mp3 is missing',
        );
        final preview = AudioAssetService.occasionPreviewAsset(type);
        expect(preview, isNotNull);
        expect(
          File('assets/$preview').existsSync(),
          isTrue,
          reason: 'assets/$preview is missing',
        );
        expect(AudioAssetService.occasionAsset(type), 'assets/$preview');
      }
      // Every occasion, including the Ramadan countdown, carries its own
      // recorded voice and raw resource.
      expect(withAudio, OccasionType.values.length);
    });
  });

  group('audio contract', () {
    test('paths follow voices/<Prayer>/min_<minutes>_<key>.mp3', () {
      for (final prayer in PrayerName.values) {
        for (final minutes in const <int>[5, 10, 15, 20, 25, 30]) {
          expect(
            AudioAssetService.reminderAsset(prayer, minutes),
            'assets/voices/${prayer.folder}/min_${minutes}_${prayer.key}.mp3',
          );
          expect(
            AudioAssetService.reminderPreviewAsset(prayer, minutes),
            'voices/${prayer.folder}/min_${minutes}_${prayer.key}.mp3',
          );
          expect(
            AudioAssetService.reminderRaw(prayer, minutes),
            'min_${minutes}_${prayer.key}',
          );
        }
      }
    });

    test('every raw sound name is a legal Android resource name', () {
      final names = <String>[
        AudioAssetService.adhanRaw,
        for (final prayer in PrayerName.values)
          for (final minutes in const <int>[5, 10, 15, 20, 25, 30])
            AudioAssetService.reminderRaw(prayer, minutes),
        for (final type in OccasionType.values)
          if (AudioAssetService.occasionRaw(type) != null)
            AudioAssetService.occasionRaw(type)!,
      ];
      final legal = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final name in names) {
        expect(legal.hasMatch(name), isTrue, reason: name);
      }
    });

    test('every prayer/interval pair has a distinct notification channel', () {
      final ids = <String>{};
      final names = <String>{};
      for (final prayer in PrayerName.values) {
        for (final minutes in const <int>[5, 10, 15, 20, 25, 30]) {
          ids.add(AudioAssetService.reminderChannelId(prayer, minutes));
          names.add(AudioAssetService.reminderChannelName(prayer, minutes));
        }
      }
      expect(ids, hasLength(30));
      expect(names, hasLength(30));
    });

    test('occasion channels use their raw sound names', () {
      final ids = <String>{};
      for (final type in OccasionType.values) {
        final id = AudioAssetService.occasionChannelId(type);
        ids.add(id);
        final raw = AudioAssetService.occasionRaw(type);
        if (raw == null) {
          expect(id, 'rafel_occasions');
        } else {
          expect(id, 'rafel_event_$raw');
        }
      }
      expect(ids, hasLength(OccasionType.values.length));
    });
  });
}
