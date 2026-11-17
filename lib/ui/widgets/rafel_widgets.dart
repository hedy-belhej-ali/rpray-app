import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/date_formats.dart';
import '../../core/rafel_theme.dart';
import '../../models/islamic_event.dart';
import '../../models/prayer_name.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RafelCard
// ─────────────────────────────────────────────────────────────────────────────

class RafelCard extends StatelessWidget {
  const RafelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(RafelSpace.md),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = RafelRadius.lg,
    this.animate = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  /// Whether to animate the card entrance with fade + slide.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final borderRadius = BorderRadius.circular(radius);
    final card = Material(
      color: color ?? theme.surface,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: theme.onSurface.withValues(alpha: 0.06),
        highlightColor: theme.onSurface.withValues(alpha: 0.03),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: borderColor ?? theme.outline),
          ),
          child: child,
        ),
      ),
    );

    if (!animate) return card;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: RafelDurations.enter,
      curve: RafelAnimCurves.enter,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: card,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelSectionLabel
// ─────────────────────────────────────────────────────────────────────────────

class RafelSectionLabel extends StatelessWidget {
  const RafelSectionLabel(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: RafelSpace.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: theme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelPill
// ─────────────────────────────────────────────────────────────────────────────

class RafelPill extends StatelessWidget {
  const RafelPill({
    super.key,
    required this.label,
    this.icon,
    this.filled = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final foreground = filled
        ? (Theme.of(context).brightness == Brightness.dark
            ? RafelPalette.darkBackground
            : RafelPalette.lightBackground)
        : theme.active;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: filled ? theme.active : theme.activeAt(0.10),
        borderRadius: BorderRadius.circular(RafelRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: compact ? 11 : 13, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBMPlexSans',
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w600,
              color: foreground,
              height: 1.1,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelStatusPill
// ─────────────────────────────────────────────────────────────────────────────

class RafelStatusPill extends StatelessWidget {
  const RafelStatusPill(this.status, {super.key, this.compact = false});

  final EventDateStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      EventDateStatus.estimated => Icons.auto_awesome_outlined,
      EventDateStatus.adjusted => Icons.tune,
      EventDateStatus.confirmed => Icons.check_circle_outline,
    };
    return RafelPill(
      label: status.label,
      icon: icon,
      compact: compact,
      filled: status == EventDateStatus.confirmed,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelSettingRow
// ─────────────────────────────────────────────────────────────────────────────

class RafelSettingRow extends StatelessWidget {
  const RafelSettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RafelSpace.md,
        vertical: 14,
      ),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.activeAt(0.10),
              ),
              child: Icon(
                leading,
                size: 18,
                color: theme.active,
              ),
            ),
            const SizedBox(width: RafelSpace.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: theme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: theme.surfaceVariant.withValues(alpha: 0.72),
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: RafelSpace.sm),
              child: trailing,
            )
          else if (onTap != null && showChevron)
            Icon(
              Icons.chevron_right,
              color: theme.surfaceVariant.withValues(alpha: 0.72),
              size: 18,
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      splashColor: theme.onSurface.withValues(alpha: 0.04),
      child: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelActionTile
// ─────────────────────────────────────────────────────────────────────────────

class RafelActionTile extends StatelessWidget {
  const RafelActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final fgColor = filled
        ? (Theme.of(context).brightness == Brightness.dark
            ? RafelPalette.darkBackground
            : RafelPalette.lightBackground)
        : theme.onSurface;
    return Material(
      color: filled ? theme.active : Colors.transparent,
      borderRadius: BorderRadius.circular(RafelRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RafelRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RafelRadius.md),
            border: Border.all(
              color: filled ? theme.active : theme.outline,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 17, color: fgColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PrayerIcon
// ─────────────────────────────────────────────────────────────────────────────

class PrayerIcon extends StatelessWidget {
  const PrayerIcon(
    this.prayer, {
    super.key,
    this.size = 20,
    this.color,
  });

  final PrayerName prayer;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final icon = switch (prayer) {
      PrayerName.fajr => Icons.wb_twilight,
      PrayerName.dhuhr => Icons.light_mode_outlined,
      PrayerName.asr => Icons.wb_sunny_outlined,
      PrayerName.maghrib => Icons.nightlight_outlined,
      PrayerName.isha => Icons.dark_mode_outlined,
    };
    return Icon(icon, size: size, color: color ?? theme.onSurface);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelCrescentIcon — custom painted monochrome crescent
// ─────────────────────────────────────────────────────────────────────────────

class RafelCrescentIcon extends StatelessWidget {
  const RafelCrescentIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return CustomPaint(
      size: Size(size, size),
      painter: _CrescentPainter(color: color ?? theme.onSurface),
    );
  }
}

class _CrescentPainter extends CustomPainter {
  _CrescentPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.44;

    // Draw the outer circle.
    final outerPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    // Subtract an offset inner circle to create the crescent shape.
    final cutRadius = r * 0.84;
    final cutOffset = r * 0.26;
    final cutPath = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(cx + cutOffset, cy - cutOffset * 0.3),
        radius: cutRadius,
      ));

    final crescent = Path.combine(PathOperation.difference, outerPath, cutPath);
    canvas.drawPath(crescent, paint);
  }

  @override
  bool shouldRepaint(_CrescentPainter oldDelegate) => oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelArcProgress — animated arc showing prayer period progress
// ─────────────────────────────────────────────────────────────────────────────

class RafelArcProgress extends StatelessWidget {
  const RafelArcProgress({
    super.key,
    required this.fraction,
    this.size = 60,
    this.strokeWidth = 2.0,
    this.color,
    this.trackColor,
  });

  final double fraction;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => CustomPaint(
        size: Size(size, size),
        painter: _ArcPainter(
          fraction: value,
          strokeWidth: strokeWidth,
          color: color ?? theme.onSurface,
          trackColor: trackColor ?? theme.onSurface.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.fraction,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2; // top
    const sweepMax = 2 * math.pi;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepMax,
      false,
      trackPaint,
    );

    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepMax * fraction,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelDivider
// ─────────────────────────────────────────────────────────────────────────────

class RafelDivider extends StatelessWidget {
  const RafelDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Divider(height: 1, color: theme.outline),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelSheetHandle
// ─────────────────────────────────────────────────────────────────────────────

class RafelSheetHandle extends StatelessWidget {
  const RafelSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Center(
      child: Container(
        width: 36,
        height: 3.5,
        margin: const EdgeInsets.only(top: 10, bottom: 20),
        decoration: BoxDecoration(
          color: theme.onSurface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(RafelRadius.pill),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelEmptyState
// ─────────────────────────────────────────────────────────────────────────────

class RafelEmptyState extends StatelessWidget {
  const RafelEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RafelSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.outline),
              ),
              child: Icon(
                icon,
                size: 24,
                color: theme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: RafelSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: theme.onSurface,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: theme.surfaceVariant.withValues(alpha: 0.72),
                  ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: RafelSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelLogo
// ─────────────────────────────────────────────────────────────────────────────

class RafelLogo extends StatelessWidget {
  const RafelLogo({super.key, this.size = 120, this.radius = 28});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // The master asset is 1200×1200; decode it at the size actually drawn
    // (× device pixel ratio) so no multi-megabyte bitmap lingers in the
    // image cache for a 44px tile.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        cacheWidth: (size * dpr).round(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelWordmark — Rpray + Arabic with optional crescent
// ─────────────────────────────────────────────────────────────────────────────

class RafelWordmark extends StatelessWidget {
  const RafelWordmark({
    super.key,
    this.compact = false,
    this.showCrescent = false,
  });

  final bool compact;
  final bool showCrescent;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (showCrescent) ...<Widget>[
          RafelCrescentIcon(
            size: compact ? 14 : 18,
            color: theme.onSurface.withValues(alpha: 0.7),
          ),
          SizedBox(width: compact ? 6 : 8),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              RafelStrings.appName,
              style: TextStyle(
                fontFamily: 'IBMPlexSans',
                fontSize: compact ? 16 : 20,
                fontWeight: FontWeight.w700,
                letterSpacing: compact ? 5 : 7,
                color: theme.onSurface,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              RafelStrings.appNameArabic,
              style: RafelType.arabic(
                context,
                size: compact ? 12 : 14,
                color: theme.surfaceVariant.withValues(alpha: 0.72),
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelDateLine
// ─────────────────────────────────────────────────────────────────────────────

class RafelDateLine extends StatelessWidget {
  const RafelDateLine({
    super.key,
    required this.gregorian,
    required this.hijri,
    this.align = CrossAxisAlignment.start,
  });

  final String gregorian;
  final String? hijri;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          gregorian,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: theme.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
        ),
        if (hijri != null && hijri!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            hijri!,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 14,
              color: theme.surfaceVariant.withValues(alpha: 0.72),
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelCountdownText — animated digit transitions
// ─────────────────────────────────────────────────────────────────────────────

class RafelCountdownText extends StatelessWidget {
  const RafelCountdownText(
    this.duration, {
    super.key,
    this.large = true,
    this.textColor,
  });

  final Duration duration;
  final bool large;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final color = textColor ?? theme.onSurface;
    final total = duration.isNegative ? Duration.zero : duration;
    final hours = total.inHours;
    final minutes = total.inMinutes % 60;
    final seconds = total.inSeconds % 60;
    final parts = <String>[
      if (hours > 0) twoDigits(hours),
      twoDigits(minutes),
      twoDigits(seconds),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        for (var i = 0; i < parts.length; i++) ...<Widget>[
          if (i > 0)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: large ? 5 : 3,
              ),
              child: Text(
                ':',
                style: TextStyle(
                  fontFamily: 'IBMPlexSans',
                  fontSize: large ? 36 : 16,
                  fontWeight: FontWeight.w300,
                  color: color.withValues(alpha: 0.45),
                  height: 1,
                ),
              ),
            ),
          _AnimatedDigitPair(
            value: parts[i],
            large: large,
            color: color,
          ),
        ],
        if (hours == 0)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              'min',
              style: TextStyle(
                fontSize: large ? 12 : 10,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.75),
                letterSpacing: 0.2,
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedDigitPair extends StatelessWidget {
  const _AnimatedDigitPair({
    required this.value,
    required this.large,
    required this.color,
  });

  final String value;
  final bool large;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        value,
        key: ValueKey<String>(value),
        style: RafelType.tabular.copyWith(
          fontFamily: 'IBMPlexSans',
          fontSize: large ? 52 : 21,
          fontWeight: FontWeight.w500,
          letterSpacing: large ? -1.5 : -0.4,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelScaffoldBody
// ─────────────────────────────────────────────────────────────────────────────

class RafelScaffoldBody extends StatelessWidget {
  const RafelScaffoldBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      RafelSpace.lg,
      RafelSpace.sm,
      RafelSpace.lg,
      RafelSpace.xl,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(padding: padding, child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RafelSheetTitle
// ─────────────────────────────────────────────────────────────────────────────

class RafelSheetTitle extends StatelessWidget {
  const RafelSheetTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: theme.onSurface,
                    ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: theme.surfaceVariant.withValues(alpha: 0.72),
                      ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility functions
// ─────────────────────────────────────────────────────────────────────────────

void showRafelSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmRafel(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
}) async {
  final theme = RafelTheme.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: theme.surface,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: theme.onSurface,
            ),
      ),
      content: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: theme.surfaceVariant.withValues(alpha: 0.75),
            ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel, style: TextStyle(color: theme.onSurface)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel, style: TextStyle(color: theme.onSurface)),
        ),
      ],
    ),
  );
  return result ?? false;
}
