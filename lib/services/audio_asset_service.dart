import '../models/islamic_event.dart';
import '../models/prayer_name.dart';

/// Centralised audio contract. Flutter assets are used for in-app preview and
/// Android `res/raw` resources for notification-channel sounds.
class AudioAssetService {
  AudioAssetService._();

  static const String adhanRaw = 'adhan';
  static const String adhanAsset = 'assets/voices/adhan.mp3';

  /// Path used with `AssetSource`, which is relative to the `assets/` root.
  static const String adhanPreviewAsset = 'voices/adhan.mp3';

  static String reminderAsset(PrayerName prayer, int minutes) =>
      'assets/voices/${prayer.folder}/$minutes-min-${prayer.key}.mp3';

  static String reminderPreviewAsset(PrayerName prayer, int minutes) =>
      'voices/${prayer.folder}/$minutes-min-${prayer.key}.mp3';

  static String reminderRaw(PrayerName prayer, int minutes) =>
      'min_${minutes}_${prayer.key}';

  static String? occasionRaw(OccasionType type) => type.audioRaw;

  static String? occasionAsset(OccasionType type) {
    final raw = type.audioRaw;
    if (raw == null) return null;
    return 'assets/${occasionPreviewAsset(type)}';
  }

  static String? occasionPreviewAsset(OccasionType type) {
    final raw = type.audioRaw;
    if (raw == null) return null;
    return switch (type) {
      OccasionType.eidAlFitr => 'voices/eid-fitr.mp3',
      OccasionType.eidAlAdha => 'voices/eid-eidhha.mp3',
      OccasionType.islamicNewYear => 'voices/new-hijri-year.mp3',
      OccasionType.ashura => 'voices/tmrw-ashura.mp3',
      OccasionType.arafah => 'voices/tmr-arafa.mp3',
      OccasionType.mawlid => 'voices/mawled-nabawi.mp3',
      OccasionType.whiteDays => 'voices/notif-ayam-lbidh.mp3',
      OccasionType.lastTenNights => 'voices/10-awakhr.mp3',
      OccasionType.laylatAlQadr => 'voices/laylt-elkadr.mp3',
      OccasionType.ramadan => 'voices/ramadhan-notifa.mp3',
    };
  }

  static String reminderChannelId(PrayerName prayer, int minutes) =>
      'rafel_rem_${prayer.key}_$minutes';

  static String reminderChannelName(PrayerName prayer, int minutes) =>
      '${prayer.englishLabel} · $minutes min reminder';

  static String occasionChannelId(OccasionType type) {
    final raw = type.audioRaw;
    if (raw == null) return 'rafel_occasions';
    return 'rafel_event_$raw';
  }

  static String occasionChannelName(OccasionType type) =>
      '${type.label} · Rpray';
}
