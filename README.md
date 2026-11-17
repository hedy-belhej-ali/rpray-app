<p align="center">
  <img src="assets/logo.png" width="140" alt="Rpray logo">
</p>

<h1 align="center">Rpray · ربراي</h1>

<p align="center">
  <em>Prayer, remembered.</em><br/>
  An offline-first Muslim prayer-times app for Android &amp; iOS, built with Flutter.
</p>

---

## What it is

Rpray calculates prayer times **entirely on-device** — no network calls, no silent
defaults. Give it your coordinates and timezone, and every time it shows or
schedules is one it actually computed and can explain.

### Features

- **Precise offline calculation** — from explicit coordinates, an IANA timezone,
  a chosen calculation method, the Asr madhab, a high-latitude rule and
  per-prayer minute adjustments. No hardcoded times anywhere.
- **Next-prayer countdown** — live, smooth progress through the interval, with a
  painted sky scene where the sun sits where it will at that prayer.
- **Six advance reminders per prayer** — at 5/10/15/20/25/30 minutes before,
  each using its own bundled recorded voice (`voices/<Prayer>/<N>-min-<prayer>.mp3`).
- **Full adhan at prayer time** — a native Android `AlarmManager` alarm plus a
  foreground service playing the complete adhan through `MediaPlayer`, restored
  after reboot and after package replacement.
- **Hijri date** — computed independently of the prayer calculation
  (Umm al-Qura based), with a ±2-day manual offset and explicit
  estimated/confirmed/adjusted states.
- **Islamic occasions** — Eid al-Fitr & al-Adha, Islamic New Year, Ashura,
  Arafah, optional Mawlid, the White Days, the last ten nights and Laylat
  al-Qadr — with local Ramadan/Eid overrides. Never duplicated.
- **Diagnostics screen** — a plain record of exactly what the app calculated
  and scheduled. Nothing simulated.
- **Two themes, one brand** — light and dark built on the exact pair
  ink `#100E09` / paper `#E6E6E6` with a warm brass accent.

## Tech stack

| Piece | Choice |
| --- | --- |
| Framework | Flutter (Material 3) · Dart |
| Prayer times | [`adhan`](https://pub.dev/packages/adhan) ^2.0.0+1 |
| Hijri calendar | [`hijri`](https://pub.dev/packages/hijri) ^3.0.1 |
| Notifications | `flutter_local_notifications` + `timezone` + `flutter_timezone` |
| Audio | `audioplayers` (previews) · native `MediaPlayer` (full adhan) |
| Location | `geolocator` (one-shot; coordinates are user-editable) |
| State | `provider` + `ChangeNotifier` |

Notification channels carry the six recorded reminder sounds; the full adhan
deliberately bypasses notification sounds entirely (native alarm + service).

## Getting started

Prerequisites: Flutter 3.50+ / Dart 3.14+, Android SDK (compile/target 37).

```bash
git clone https://github.com/hedy-belhej-ali/rpray-app.git
cd rpray-app
flutter pub get
flutter run
```

### Analysis & tests

```bash
flutter analyze   # static analysis
dart test         # pure calculation, Hijri, event, scheduling and asset tests
```

The calculation/scheduling/Hijri/audio/ID test suites run as pure Dart tests
(no device needed). Widget tests additionally require a native-assets
toolchain (MSVC on Windows).

## Project layout

```
lib/
├── main.dart            # app root, provider, splash
├── core/                # theme, typography, date formatting
├── controllers/         # PrayerController — live state, timers, scheduling
├── data/                # bundled city database
├── models/              # settings, prayer day, events, notification plan
├── services/            # calculation, Hijri, occasions, notifications,
│                         # native adhan bridge, audio, timezone, storage
└── ui/
    ├── screens/         # today, occasions, settings, setup, pickers, diagnostics
    ├── sheets/          # prayer detail, calculation pickers
    └── widgets/         # shared Rafel* widgets
android/…/kotlin/com/rafel/rafel/   # AdhanScheduler, AdhanReceiver,
                                     # AdhanBootReceiver, AdhanService, AdhanStore
```

## Platform notes

- **Android** — requests notification permission, uses exact alarms with a
  fallback path when denied, and restores full-adhan alarms after reboot,
  package replacement and timezone/time changes.
- **iOS** — fully supported for calculation and reminders; iOS cannot use the
  bundled MP3s as notification sounds (system limitation), so reminders fall
  back to the default sound there.

## Status

- [x] Offline calculation verified against AlAdhan reference fixtures (±2 min)
- [x] 63 pure logic tests passing (`dart test`)
- [x] Full UI: setup, today, prayer detail, occasions, adjustments, settings, diagnostics
- [x] Signed release APK — signed with the developer's own key, verified with `apksigner`
- [x] **Reboot restore verified on device** — after a full reboot, with the app never
      opened, the boot receiver re-armed 60 exact adhan alarms (`RTC_WAKEUP`,
      `window=0`); the next restored alarm was the same-day Fajr
- [ ] On-device audible check of the full adhan at prayer time (armed; checked at
      the next prayer with the app closed)

## Release signing

`flutter build apk --release` signs with the release key configured in
`android/key.properties` (keystore: `android/rafel-release-key.jks`). Both files
are gitignored and must never be committed — losing them means no update can
ever be installed over a signed release. A fresh clone without these files
falls back to the debug key so `flutter run --release` still works.

## Developer

Built by **hedy belhej ali**.

- GitHub — https://github.com/hedy-belhej-ali
- LinkedIn — https://www.linkedin.com/in/hedy-belhej-ali-291ab532a
- Instagram — https://www.instagram.com/hedyy69/

## License

All rights reserved © 2026.
