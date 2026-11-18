/// The five daily prayers. The [key] and [folder] values are part of the
/// audio contract: `assets/voices/<folder>/min_<minutes>_<key>.mp3`, which is
/// also the Android `res/raw` name used for the notification sound.
enum PrayerName {
  fajr('fajr', 'Fajr', 'الفجر', 'Fajr'),
  dhuhr('dhuhr', 'Dhuhr', 'الظهر', 'Dhuhr'),
  asr('asr', 'Asr', 'العصر', 'Asr'),
  maghrib('maghrib', 'Maghrib', 'المغرب', 'Maghrib'),
  isha('isha', 'Isha', 'العشاء', 'Isha');

  const PrayerName(this.key, this.englishLabel, this.arabicLabel, this.folder);

  final String key;
  final String englishLabel;
  final String arabicLabel;
  final String folder;

  static PrayerName? fromKey(String? key) {
    if (key == null) return null;
    for (final prayer in PrayerName.values) {
      if (prayer.key == key) return prayer;
    }
    return null;
  }
}

/// Explicit reminder intervals required by the product specification.
const List<int> reminderIntervals = <int>[5, 10, 15, 20, 25, 30];

/// Reminder intervals from longest to shortest (the natural UI order).
const List<int> reminderIntervalsDescending = <int>[30, 25, 20, 15, 10, 5];

const List<PrayerName> prayerOrder = PrayerName.values;
