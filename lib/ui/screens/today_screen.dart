import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/prayer_controller.dart';
import '../../core/date_formats.dart';
import '../../core/rafel_theme.dart';
import '../../models/islamic_event.dart';
import '../../models/prayer_day.dart';
import '../../models/prayer_name.dart';
import '../../models/prayer_settings.dart';
import '../screens/city_picker_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../sheets/prayer_detail_sheet.dart';
import '../widgets/rafel_widgets.dart';

/// One place for the muted tone that was previously repeated as
/// `surfaceVariant.withValues(alpha: 0.72)` everywhere.
extension on RafelThemeData {
  Color get muted => surfaceVariant.withValues(alpha: 0.72);
}

// ─────────────────────────────────────────────────────────────────────────────
// Today screen
// ─────────────────────────────────────────────────────────────────────────────

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.onOpenOccasions,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenOccasions;
  final VoidCallback onOpenSettings;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late final PrayerController _controller;

  PrayerDay? _day;
  GeoLocation? _location;
  String _todayLabel = '';
  String? _hijriLabel;
  NextPrayer? _next;

  @override
  void initState() {
    super.initState();
    _controller = context.read<PrayerController>()
      ..addListener(_onControllerChanged);
    // No setState needed here: first build reads these fields directly.
    _readController();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _readController() {
    final c = _controller;
    _day = c.today;
    _location = c.settings.location;
    _todayLabel = formatGregorianDate(_day?.localDate ?? c.now);
    _hijriLabel = c.hijriToday?.formatted;
    _next = c.nextPrayer;
  }

  /// The controller ticks often; only rebuild the screen when something this
  /// screen actually shows has changed. The countdown owns its own timer.
  void _onControllerChanged() {
    if (!mounted) return;
    final c = _controller;
    final changed = c.today != _day ||
        c.hijriToday?.formatted != _hijriLabel ||
        c.nextPrayer?.prayer != _next?.prayer ||
        c.settings.location != _location;
    if (changed) setState(_readController);
  }

  Future<void> _onRefresh() async {
    HapticFeedback.selectionClick();
    await _controller.refresh();
  }

  Future<void> _changeLocation() async {
    final selection = await Navigator.of(context).push<LocationSelection>(
      MaterialPageRoute<LocationSelection>(
        builder: (_) => CityPickerScreen(current: _controller.settings.location),
      ),
    );
    if (selection == null) return;
    await _controller.applyLocation(
      selection.location,
      suggestedMethod: selection.suggestedMethod,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final theme = RafelTheme.of(context);
    final day = _day;
    final location = _location;
    final next = _next;

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: <Widget>[
          // Soft wash behind the header so the hero card doesn't float on flat
          // colour. Uses the existing accent at very low alpha.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 360,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      theme.activeAt(0.10),
                      theme.activeAt(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          RefreshIndicator(
            color: theme.active,
            backgroundColor: theme.surface,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      RafelSpace.lg,
                      RafelSpace.md,
                      RafelSpace.lg,
                      RafelSpace.xxl,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(<Widget>[
                        _HeaderRow(
                          location: location,
                          onChangeLocation: _changeLocation,
                        ),
                        const SizedBox(height: RafelSpace.lg),
                        _DateBlock(gregorian: _todayLabel, hijri: _hijriLabel),
                        const SizedBox(height: RafelSpace.md),
                        if (next != null && day != null)
                          _NextPrayerCard(
                            prayer: next.prayer,
                            time: next.time,
                            isTomorrow: next.isTomorrow,
                            lastPrayer: c.lastPrayer?.adjusted,
                            sunrise: day.sunrise,
                            sunset: _sunsetOf(day),
                          )
                        else
                          _MissingTimesCard(onChooseLocation: _changeLocation),
                        const SizedBox(height: RafelSpace.lg),
                        if (day != null && location != null) ...<Widget>[
                          _SectionHeader(
                            label: 'Today',
                            trailing: _TimezonePill(location.timezoneId),
                          ),
                          _PrayerList(
                            day: day,
                            now: c.now,
                            nextPrayer: next?.prayer,
                            onTap: (prayer) =>
                                showPrayerDetailSheet(context, prayer),
                          ),
                        ],
                        if (c.nextOccasion != null) ...<Widget>[
                          const SizedBox(height: RafelSpace.lg),
                          _NextOccasionCard(
                            event: c.nextOccasion!,
                            onTap: widget.onOpenOccasions,
                          ),
                        ],
                        const SizedBox(height: RafelSpace.md),
                        _NotificationNotice(
                          controller: c,
                          onOpenSettings: widget.onOpenSettings,
                        ),
                        const SizedBox(height: RafelSpace.lg),
                        _OfflineFooter(
                          label: c.settings.calculation.method.shortLabel,
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header row
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.location, required this.onChangeLocation});

  final GeoLocation? location;
  final VoidCallback onChangeLocation;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final loc = location;
    return Row(
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            'Welcome',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: theme.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
          ),
        ),
        if (loc != null) ...<Widget>[
          const SizedBox(width: RafelSpace.sm),
          // Takes the remaining width and pins the chip to the far right.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _LocationChip(location: loc, onTap: onChangeLocation),
            ),
          ),
        ],
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.location, required this.onTap});

  final GeoLocation location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Semantics(
      button: true,
      label: 'Change location. Current location: ${location.name}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RafelRadius.pill),
            border: Border.all(color: theme.outline),
            color: theme.elevated.withValues(alpha: 0.5),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      location.isDeviceLocation
                          ? Icons.near_me_outlined
                          : Icons.location_on_outlined,
                      size: 14,
                      color: theme.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        location.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: theme.onSurface.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: theme.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date block
// ─────────────────────────────────────────────────────────────────────────────

/// Font used for the date. Swap this one constant to try another family
/// (it must be declared in pubspec.yaml).
const String _kDateFont = 'IBMPlexSans';

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.gregorian, required this.hijri});

  final String gregorian;
  final String? hijri;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final hasHijri = hijri != null && hijri!.isNotEmpty;
    return Semantics(
      header: true,
      label: hasHijri ? '$gregorian, $hijri' : gregorian,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            gregorian,
            style: TextStyle(
              fontFamily: _kDateFont,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: theme.onSurface,
              height: 1.2,
              letterSpacing: -0.45,
            ),
          ),
          if (hasHijri) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              hijri!,
              style: TextStyle(
                fontFamily: _kDateFont,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.active,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: RafelSpace.sm),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: theme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _TimezonePill extends StatelessWidget {
  const _TimezonePill(this.timezoneId);

  final String timezoneId;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RafelRadius.pill),
        border: Border.all(color: theme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.public, size: 11, color: theme.muted),
          const SizedBox(width: 4),
          Text(
            timezoneId,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: theme.muted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Next prayer card — slim, with the sun where it is at that time
// ─────────────────────────────────────────────────────────────────────────────

/// Sunset for [day]. `prayerOrder` is fajr, dhuhr, asr, maghrib, isha, so
/// index 3 is maghrib, which sits right at sunset.
DateTime _sunsetOf(PrayerDay day) {
  if (prayerOrder.length > 3) return day.entry(prayerOrder[3]).calculated;
  return day.sunrise.add(const Duration(hours: 12));
}

class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({
    required this.prayer,
    required this.time,
    required this.isTomorrow,
    required this.lastPrayer,
    required this.sunrise,
    required this.sunset,
  });

  final PrayerName prayer;
  final DateTime time;
  final bool isTomorrow;
  final DateTime? lastPrayer;
  final DateTime sunrise;
  final DateTime sunset;

  /// Where the sun is at [time]: 0 at sunrise, 1 at sunset, below 0 before
  /// dawn and above 1 after dusk. Uses time of day only, so tomorrow's
  /// Fajr is placed against today's sunrise/sunset.
  double get _sunProgress {
    int minutes(DateTime d) => d.hour * 60 + d.minute;
    final rise = minutes(sunrise);
    final set = minutes(sunset);
    if (set <= rise) return 0.5;
    return (minutes(time) - rise) / (set - rise);
  }

  @override
  Widget build(BuildContext context) {
    const ink = Colors.white;
    final sky = RafelSky.gradient(prayer);
    final radius = BorderRadius.circular(RafelRadius.lg + 4);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final sunProgress = _sunProgress;

    // Plays once when the screen first appears; later rebuilds don't replay it.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
      ),
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: isTomorrow
            ? 'Next prayer tomorrow: ${prayer.englishLabel} at ${formatTime(time)}'
            : 'Next prayer: ${prayer.englishLabel} at ${formatTime(time)}',
        child: AnimatedContainer(
          duration: RafelDurations.pageTransition,
          curve: RafelAnimCurves.smooth,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: sky,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: sky.last.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      // The sun glides to its new spot when the prayer
                      // changes, and rises slightly on first load.
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: sunProgress - 0.12,
                          end: sunProgress,
                        ),
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 1400),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => CustomPaint(
                          painter: _SunScenePainter(progress: value, ink: ink),
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              PrayerIcon(prayer, size: 15, color: ink),
                              const SizedBox(width: 8),
                              Text(
                                isTomorrow
                                    ? 'Next prayer, tomorrow'
                                    : 'Next prayer',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: ink.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: Text(
                                        prayer.arabicLabel,
                                        style: const TextStyle(
                                          fontFamily: 'Amiri',
                                          fontSize: 44,
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      prayer.englishLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: ink.withValues(alpha: 0.9),
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: RafelSpace.sm),
                              Text(
                                formatTime(time),
                                style: RafelType.tabular.copyWith(
                                  fontFamily: 'IBMPlexSans',
                                  fontSize: 30,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.6,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // The countdown sits on the "ground" the painter draws.
                    SizedBox(
                      height: _kGroundHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Center(
                          child: _PrayerCountdown(
                            targetTime: time,
                            startTime: lastPrayer,
                            isFajr: prayer == PrayerName.fajr,
                            textColor: ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const double _kGroundHeight = 96;

/// Paints a small sky: the sun's arc, the sun at its position for the prayer
/// time, a dark ground strip, and stars plus a crescent moon at night.
class _SunScenePainter extends CustomPainter {
  const _SunScenePainter({required this.progress, required this.ink});

  /// 0 at sunrise, 1 at sunset; outside that range the sun is below the horizon.
  final double progress;
  final Color ink;

  // x as a fraction of width, y as a fraction of sky height, radius in px.
  static const List<(double, double, double)> _stars = <(double, double, double)>[
    (0.07, 0.20, 1.2),
    (0.20, 0.09, 0.9),
    (0.33, 0.30, 1.0),
    (0.47, 0.08, 1.3),
    (0.70, 0.18, 0.9),
    (0.80, 0.07, 1.2),
    (0.92, 0.26, 1.0),
    (0.13, 0.50, 0.8),
    (0.62, 0.46, 0.8),
    (0.88, 0.52, 0.9),
  ];

  static double _clamp01(double v) => v.clamp(0.0, 1.0).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final horizon = size.height - _kGroundHeight;
    if (horizon <= 0) return;

    final left = w * 0.10;
    final span = w * 0.80;
    final arcHeight = horizon * 0.80;
    final p = progress;

    Offset pointAt(double t) => Offset(
          left + span * t,
          horizon - math.sin(math.pi * t) * arcHeight,
        );

    // Stars and moon fade in before dawn and after dusk.
    final night = p < 0
        ? _clamp01(-p / 0.2)
        : p > 1
            ? _clamp01((p - 1) / 0.12)
            : 0.0;

    if (night > 0) {
      final star = Paint();
      for (final (dx, dy, r) in _stars) {
        star.color = ink.withValues(alpha: 0.7 * night);
        canvas.drawCircle(Offset(w * dx, horizon * dy), r, star);
      }
      final moonCenter = Offset(w * 0.56, horizon * 0.34);
      final moon = Path()
        ..addOval(Rect.fromCircle(center: moonCenter, radius: 10));
      final bite = Path()
        ..addOval(
          Rect.fromCircle(
            center: moonCenter + const Offset(6, -3),
            radius: 9.5,
          ),
        );
      canvas.drawPath(
        Path.combine(PathOperation.difference, moon, bite),
        Paint()..color = ink.withValues(alpha: 0.9 * night),
      );
    }

    // Dotted path the sun follows across the day.
    final dot = Paint()..color = ink.withValues(alpha: 0.22);
    for (var i = 0; i <= 28; i++) {
      canvas.drawCircle(pointAt(i / 28), 1.1, dot);
    }

    // Sun and glow. Below the horizon the disc is hidden, but the glow
    // lingers so dawn and dusk still read as warm light on the horizon.
    final sun = pointAt(p);
    final below = sun.dy - horizon;
    final strength = below <= 0 ? 1.0 : _clamp01(1 - below / (arcHeight * 0.45));
    if (strength > 0) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            ink.withValues(alpha: 0.34 * strength),
            ink.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: 120));
      canvas.drawCircle(sun, 120, glow);

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, w, horizon));
      canvas.drawCircle(
        sun,
        22,
        Paint()..color = ink.withValues(alpha: 0.22 * strength),
      );
      canvas.drawCircle(
        sun,
        14,
        Paint()..color = ink.withValues(alpha: 0.95 * strength),
      );
      canvas.restore();
    }

    // Ground and horizon line, drawn last so a setting sun slips behind it.
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, _kGroundHeight),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    canvas.drawLine(
      Offset(0, horizon),
      Offset(w, horizon),
      Paint()
        ..color = ink.withValues(alpha: 0.25)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SunScenePainter old) =>
      old.progress != progress || old.ink != ink;
}

// Countdown — own timer, rebuilds only itself every second.

class _PrayerCountdown extends StatefulWidget {
  const _PrayerCountdown({
    required this.targetTime,
    this.startTime,
    required this.isFajr,
    required this.textColor,
  });

  final DateTime targetTime;
  final DateTime? startTime;
  final bool isFajr;
  final Color textColor;

  @override
  State<_PrayerCountdown> createState() => _PrayerCountdownState();
}

class _PrayerCountdownState extends State<_PrayerCountdown>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late final AnimationController _progressTicker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Drives only the progress-bar subtree at display refresh rate. The
    // countdown text itself still updates once per second.
    _progressTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _startTicker();
  }

  @override
  void didUpdateWidget(_PrayerCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetTime != oldWidget.targetTime ||
        widget.startTime != oldWidget.startTime) {
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _progressTicker.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _computeValues();
    if (_remaining == Duration.zero) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(_computeValues);
      // Nothing left to count: stop waking up every second.
      if (_remaining == Duration.zero) timer.cancel();
    });
  }

  void _computeValues() {
    final diff = widget.targetTime.difference(DateTime.now());
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  /// Progress through the interval from the previous adjusted prayer to the
  /// next adjusted prayer. This is evaluated every animation frame so the
  /// indicator glides smoothly instead of visibly stepping once per second.
  double _progressAt(DateTime now) {
    final start = widget.startTime;
    if (start == null || !widget.targetTime.isAfter(start)) return 0.0;

    final totalMicros =
        widget.targetTime.difference(start).inMicroseconds;
    if (totalMicros <= 0) return 0.0;

    final elapsedMicros = now.difference(start).inMicroseconds;
    return (elapsedMicros / totalMicros).clamp(0.0, 1.0).toDouble();
  }

  static String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Fajr has no progress marker: use the whole countdown strip for the timer.
    if (widget.isFajr) {
      return SizedBox(
        width: double.infinity,
        height: _kGroundHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Time remaining',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: widget.textColor.withValues(alpha: 0.85),
                  ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _format(_remaining),
                style: RafelType.tabular.copyWith(
                  fontFamily: 'IBMPlexSans',
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  color: widget.textColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              'Time remaining',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: widget.textColor.withValues(alpha: 0.85),
                  ),
            ),
            const Spacer(),
            Text(
              _format(_remaining),
              style: RafelType.tabular.copyWith(
                fontFamily: 'IBMPlexSans',
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: widget.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _progressTicker,
          builder: (context, _) => _GlowProgressBar(
            value: _progressAt(DateTime.now()),
            color: widget.textColor,
          ),
        ),
      ],
    );
  }
}

class _GlowProgressBar extends StatelessWidget {
  const _GlowProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary keeps each frame's raster work inside this bar instead
    // of invalidating the whole prayer card underneath it.
    return RepaintBoundary(
      child: SizedBox(
        height: 20,
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            const dotSize = 12.0;
            final progress = value.clamp(0.0, 1.0).toDouble();

            // Keep the complete dot visible at both ends of the timeline.
            final travelWidth = (width - dotSize).clamp(0.0, width);
            final dotLeft = travelWidth * progress;
            final dotCenter = dotLeft + dotSize / 2;

            return Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: <Widget>[
                // The entire track represents 100% of the interval
                // from the previous prayer to the next prayer.
                Positioned(
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(RafelRadius.pill),
                    ),
                  ),
                ),

                // Filled portion represents elapsed time.
                Positioned(
                  left: 0,
                  child: Container(
                    width: dotCenter.clamp(0.0, width).toDouble(),
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(RafelRadius.pill),
                    ),
                  ),
                ),

                // The dot marks the elapsed-time percentage.
                Positioned(
                  left: dotLeft,
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: color.withValues(alpha: 0.55),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Missing times card
// ─────────────────────────────────────────────────────────────────────────────

class _MissingTimesCard extends StatelessWidget {
  const _MissingTimesCard({required this.onChooseLocation});

  final VoidCallback onChooseLocation;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final controller = context.read<PrayerController>();
    return RafelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.error_outline, size: 18, color: theme.active),
              const SizedBox(width: RafelSpace.xs),
              Text(
                'No valid times for this date',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: theme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: RafelSpace.xs),
          Text(
            controller.error ??
                'Choose a location to calculate prayer times. Rpray will not '
                    'invent or schedule a time it cannot calculate.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: theme.muted,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: RafelSpace.md),
          Wrap(
            spacing: RafelSpace.xs,
            runSpacing: RafelSpace.xs,
            children: <Widget>[
              FilledButton.icon(
                onPressed: onChooseLocation,
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: const Text('Choose location'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DiagnosticsScreen(),
                  ),
                ),
                child: const Text('Open diagnostics'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prayer list
// ─────────────────────────────────────────────────────────────────────────────

class _PrayerList extends StatelessWidget {
  const _PrayerList({
    required this.day,
    required this.now,
    required this.nextPrayer,
    required this.onTap,
  });

  final PrayerDay day;
  final DateTime now;
  final PrayerName? nextPrayer;
  final ValueChanged<PrayerName> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < prayerOrder.length; i++) {
      final prayer = prayerOrder[i];
      // Indent lines up with the text, past the 36px icon badge.
      if (i > 0) rows.add(const RafelDivider(indent: 66));
      final entry = day.entry(prayer);
      rows.add(
        _PrayerRow(
          prayer: prayer,
          time: entry.adjusted,
          calculated: entry.calculated,
          isNext: prayer == nextPrayer,
          isPast: entry.adjusted.isBefore(now),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap(prayer);
          },
        ),
      );
      if (prayer == PrayerName.fajr) {
        rows.add(_SunriseRow(sunrise: day.sunrise));
      }
    }
    return RafelCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: rows),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.prayer,
    required this.time,
    required this.calculated,
    required this.isNext,
    required this.isPast,
    required this.onTap,
  });

  final PrayerName prayer;
  final DateTime time;
  final DateTime calculated;
  final bool isNext;
  final bool isPast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final deltaMinutes = time.difference(calculated).inMinutes;
    final textColor = isPast ? theme.muted : theme.onSurface;
    final rowRadius = BorderRadius.circular(RafelRadius.lg);

    final status = isNext
        ? 'next prayer'
        : isPast
            ? 'passed'
            : 'upcoming';

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${prayer.englishLabel}, ${formatTime(time)}, $status'
          '${deltaMinutes != 0 ? ', adjusted by $deltaMinutes minutes' : ''}',
      child: AnimatedContainer(
        duration: RafelDurations.quick,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: rowRadius,
          color: isNext ? theme.activeAt(0.10) : Colors.transparent,
          border: Border.all(
            color: isNext ? theme.activeAt(0.35) : Colors.transparent,
          ),
        ),
        // Material + InkWell sit *inside* the decorated container so the
        // ripple paints above the highlight instead of being hidden by it.
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: rowRadius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: <Widget>[
                  _PrayerBadge(prayer: prayer, isNext: isNext, isPast: isPast),
                  const SizedBox(width: RafelSpace.sm),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            prayer.englishLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontSize: 15,
                                      fontWeight: isNext
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: textColor,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          prayer.arabicLabel,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 14,
                            color: theme.muted,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (deltaMinutes != 0) ...<Widget>[
                    _AdjustmentChip(minutes: deltaMinutes),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    formatTime(time),
                    style: RafelType.tabular.copyWith(
                      fontFamily: 'IBMPlexSans',
                      fontSize: 17,
                      fontWeight: isNext ? FontWeight.w600 : FontWeight.w500,
                      color: isNext ? theme.active : textColor,
                    ),
                  ),
                  if (isNext) ...<Widget>[
                    const SizedBox(width: 8),
                    _PulsingDot(color: theme.active),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 36px icon badge. Passed prayers get a small check so progress through the
/// day reads at a glance instead of only through dimmed text.
class _PrayerBadge extends StatelessWidget {
  const _PrayerBadge({
    required this.prayer,
    required this.isNext,
    required this.isPast,
  });

  final PrayerName prayer;
  final bool isNext;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isNext ? theme.activeAt(0.16) : theme.elevated,
                border: Border.all(
                  color: isNext ? theme.activeAt(0.4) : theme.outline,
                ),
              ),
              child: Center(
                child: PrayerIcon(
                  prayer,
                  size: 18,
                  color: isNext
                      ? theme.active
                      : isPast
                          ? theme.muted
                          : theme.onSurface,
                ),
              ),
            ),
          ),
          if (isPast && !isNext)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.active,
                  border: Border.all(color: theme.surface, width: 1.5),
                ),
                child: Icon(Icons.check_rounded, size: 9, color: theme.background),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdjustmentChip extends StatelessWidget {
  const _AdjustmentChip({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final sign = minutes > 0 ? '+' : '\u2212';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RafelRadius.pill),
        border: Border.all(color: theme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.tune, size: 10, color: theme.muted),
          const SizedBox(width: 3),
          Text(
            '$sign${minutes.abs()}m',
            style: RafelType.tabular.copyWith(
              fontFamily: 'IBMPlexSans',
              fontSize: 10.5,
              color: theme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl
        ..stop()
        ..value = 1;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _scale,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
      ),
    );
  }
}

class _SunriseRow extends StatelessWidget {
  const _SunriseRow({required this.sunrise});

  final DateTime sunrise;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);

    // Informational row only: no tap handler, InkWell, selection state,
    // next-prayer highlight, or active-prayer indicator.
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 12, 18, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.wb_sunny_outlined, size: 16, color: theme.muted),
          const SizedBox(width: 10),
          Text(
            'Sunrise',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: theme.muted,
                ),
          ),
          const Spacer(),
          Text(
            formatTime(sunrise),
            style: RafelType.tabular.copyWith(
              fontFamily: 'IBMPlexSans',
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: theme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Next occasion card
// ─────────────────────────────────────────────────────────────────────────────

class _NextOccasionCard extends StatelessWidget {
  const _NextOccasionCard({required this.event, required this.onTap});

  final IslamicEvent event;
  final VoidCallback onTap;

  /// Whole calendar days until [date]. Comparing dates (not instants) means an
  /// event tomorrow at 00:00 reads "1 day", not "0 days", and DST can't skew it.
  static int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final target = DateTime.utc(date.year, date.month, date.day);
    return target.difference(today).inDays.clamp(0, 999);
  }

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final daysUntil = _daysUntil(event.date);
    final countdown = switch (daysUntil) {
      0 => 'Today',
      1 => '1 day',
      _ => '$daysUntil days',
    };

    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${event.title}, ${formatShortGregorianDate(event.date)}, $countdown',
      child: RafelCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.outline),
                color: theme.elevated,
              ),
              child: Center(
                child: RafelCrescentIcon(
                  size: 20,
                  color: theme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
            const SizedBox(width: RafelSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: theme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatShortGregorianDate(event.date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: theme.muted,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: RafelSpace.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(RafelRadius.pill),
                color: theme.activeAt(0.12),
              ),
              child: Text(
                countdown,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: theme.active,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: theme.muted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification notice
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationNotice extends StatelessWidget {
  const _NotificationNotice({
    required this.controller,
    required this.onOpenSettings,
  });

  final PrayerController controller;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final permission = controller.permission;

    final String? message;
    if (!controller.settings.notificationsEnabled) {
      message = 'Notifications are off.';
    } else if (permission != null && !permission.notificationsGranted) {
      message = 'Notification permission is not granted.';
    } else if (permission != null && !permission.exactAlarmsGranted) {
      message = 'Exact alarms are not allowed; timing may drift.';
    } else if (controller.error != null) {
      message = 'A calculation warning needs attention.';
    } else {
      message = null;
    }
    if (message == null) return const SizedBox.shrink();

    final radius = BorderRadius.circular(RafelRadius.lg);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$message Open settings.',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: theme.activeAt(0.08),
            border: Border.all(color: theme.activeAt(0.28)),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onOpenSettings,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: RafelSpace.md,
                vertical: 12,
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline, size: 16, color: theme.active),
                  const SizedBox(width: RafelSpace.xs),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: theme.onSurface.withValues(alpha: 0.85),
                          ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: theme.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineFooter extends StatelessWidget {
  const _OfflineFooter({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.cloud_off_outlined, size: 12, color: theme.muted),
        const SizedBox(width: 6),
        Text(
          'Calculated offline with $label',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: theme.muted,
                letterSpacing: 0.3,
              ),
        ),
      ],
    );
  }
}