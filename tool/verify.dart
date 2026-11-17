// ignore_for_file: avoid_print
import 'package:adhan/adhan.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Ref {
  final String name;
  final double lat;
  final double lng;
  final String tz;
  final int y, m, d;
  final CalculationMethod method;
  final Madhab madhab;
  final List<String> expected;
  const Ref(this.name, this.lat, this.lng, this.tz, this.y, this.m, this.d,
      this.method, this.madhab, this.expected);
}

String two(int v) => v.toString().padLeft(2, '0');

void main() {
  tzdata.initializeTimeZones();
  final refs = <Ref>[
    Ref('Tunis', 36.8065, 10.1815, 'Africa/Tunis', 2026, 7, 15,
        CalculationMethod.muslim_world_league, Madhab.shafi,
        ['03:24', '05:12', '12:25', '16:16', '19:38', '21:19']),
    Ref('Sfax', 34.7406, 10.7603, 'Africa/Tunis', 2026, 7, 15,
        CalculationMethod.muslim_world_league, Madhab.shafi,
        ['03:32', '05:15', '12:23', '16:10', '19:31', '21:07']),
    Ref('Sousse', 35.8256, 10.63699, 'Africa/Tunis', 2026, 7, 15,
        CalculationMethod.muslim_world_league, Madhab.shafi,
        ['03:28', '05:13', '12:23', '16:13', '19:34', '21:12']),
    Ref('Nabeul', 36.4513, 10.7357, 'Africa/Tunis', 2026, 7, 15,
        CalculationMethod.muslim_world_league, Madhab.shafi,
        ['03:24', '05:11', '12:23', '16:13', '19:35', '21:15']),
    Ref('Tunis-Dec', 36.8065, 10.1815, 'Africa/Tunis', 2026, 12, 15,
        CalculationMethod.muslim_world_league, Madhab.shafi,
        ['05:52', '07:25', '12:14', '14:46', '17:04', '18:32']),
    Ref('Tunis-UAQ-Hanafi', 36.8065, 10.1815, 'Africa/Tunis', 2026, 12, 15,
        CalculationMethod.umm_al_qura, Madhab.hanafi,
        ['05:49', '07:25', '12:14', '15:25', '17:04', '18:34']),
    Ref('London', 51.5072, -0.1276, 'Europe/London', 2026, 7, 15,
        CalculationMethod.muslim_world_league, Madhab.shafi,
        ['01:06', '05:01', '13:07', '17:25', '21:12', '00:53']),
    Ref('Oslo', 59.9139, 10.7522, 'Europe/Oslo', 2026, 7, 15,
        CalculationMethod.muslim_world_league, Madhab.shafi,
        ['01:23', '04:22', '13:23', '17:58', '22:24', '01:23']),
    Ref('Tunis-Leap', 36.8065, 10.1815, 'Africa/Tunis', 2028, 2, 29,
        CalculationMethod.muslim_world_league, Madhab.shafi,
        ['05:25', '06:51', '12:32', '15:43', '18:13', '19:34']),
  ];

  var failures = 0;
  for (final r in refs) {
    final params = r.method.getParameters();
    params.madhab = r.madhab;
    params.highLatitudeRule = HighLatitudeRule.middle_of_the_night;
    final pt = PrayerTimes.utc(Coordinates(r.lat, r.lng, validate: true),
        DateComponents(r.y, r.m, r.d), params);
    final loc = tz.getLocation(r.tz);
    String f(DateTime utc) {
      final l = tz.TZDateTime.from(utc, loc);
      return '${two(l.hour)}:${two(l.minute)}';
    }

    final got = <String>[
      f(pt.fajr),
      f(pt.sunrise),
      f(pt.dhuhr),
      f(pt.asr),
      f(pt.maghrib),
      f(pt.isha)
    ];
    final diffs = <String>[];
    for (var i = 0; i < got.length; i++) {
      if (got[i] != r.expected[i]) {
        diffs.add('$i:$got[i]!=$r.expected[i]');
        failures++;
      }
    }
    print('${r.name}: ${got.join(' ')} ${diffs.isEmpty ? 'OK' : diffs.join(' ')}');
    for (var i = 0; i < got.length; i++) {
      final l = tz.TZDateTime.from(
          [pt.fajr, pt.sunrise, pt.dhuhr, pt.asr, pt.maghrib, pt.isha][i], loc);
      print('   $i -> ${l.toIso8601String()}');
    }
  }
  print(failures == 0 ? 'ALL MATCH' : 'FAILURES: $failures');
}

