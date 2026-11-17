import 'package:material_ui/material_ui.dart';

import '../models/prayer_name.dart';

abstract final class RafelStrings {
  static const String appName = 'Rpray';
  static const String appNameArabic = 'ربراي';
  static const String tagline = 'Prayer, remembered.';
  static const String taglineArabic = 'الصلاة، دائماً.';
}

abstract final class RafelDurations {
  static const Duration countdownTick = Duration(seconds: 1);
  static const Duration previewMax = Duration(minutes: 6);
  static const Duration enter = Duration(milliseconds: 420);
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration splash = Duration(milliseconds: 650);
  static const Duration pageTransition = Duration(milliseconds: 380);
}

abstract final class RafelSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class RafelRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;
}

abstract final class RafelAnimCurves {
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve smooth = Curves.easeInOutCubic;
}

/// Semantic colors resolved from the active theme mode.
class RafelThemeData {
  const RafelThemeData({
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.outline,
    required this.active,
    required this.elevated,
  });

  final Color background;
  final Color surface;
  final Color onSurface;
  final Color surfaceVariant;
  final Color outline;
  final Color active;

  /// Third surface tier — slightly lifted above [surface].
  final Color elevated;

  Color surfaceAt(double alpha) => surface.withValues(alpha: alpha);
  Color onSurfaceAt(double alpha) => onSurface.withValues(alpha: alpha);
  Color outlineAt(double alpha) => outline.withValues(alpha: alpha);
  Color activeAt(double alpha) => active.withValues(alpha: alpha);
}

/// Light and dark palettes. Both modes are anchored on the brand pair —
/// ink `#100E09` and paper `#E6E6E6` — with warm neutrals in between and a
/// single brass/gold accent used for anything interactive or highlighted.
abstract final class RafelPalette {
  /// Light mode — brand paper background, ink text, deep brass accent.

  static const Color lightBackground = Color(0xFFE6E6E6); // brand paper
  static const Color lightSurface = Color(0xFFFAFAF8); // cards above paper
  static const Color lightOnSurface = Color(0xFF100E09); // brand ink
  static const Color lightSurfaceVariant = Color(0xFF6E6960); // muted text
  static const Color lightOutline = Color(0xFFC8C6C0); // hairlines
  static const Color lightActive = Color(0xFF8A6A21); // deep brass
  static const Color lightElevated = Color(0xFFEFEFEA); // badges, chips

  /// Dark mode — brand ink background, paper text, warm gold accent.

  static const Color darkBackground = Color(0xFF100E09); // brand ink
  static const Color darkSurface = Color(0xFF1A1610); // cards above ink
  static const Color darkOnSurface = Color(0xFFE6E6E6); // brand paper
  static const Color darkSurfaceVariant = Color(0xFFA59D8E); // muted text
  static const Color darkOutline = Color(0xFF332D22); // hairlines
  static const Color darkActive = Color(0xFFD9B76A); // warm gold
  static const Color darkElevated = Color(0xFF242017); // badges, chips
}

/// Sky colours for each prayer. The next-prayer card is painted with the
/// light of that hour. Every pair keeps white text above 4.5:1 contrast.
abstract final class RafelSky {
  static List<Color> gradient(PrayerName prayer) => switch (prayer) {
        PrayerName.fajr => const <Color>[Color(0xFF1B2A5C), Color(0xFF6A58A8)],
        PrayerName.dhuhr => const <Color>[Color(0xFF1B5A9E), Color(0xFF3F7FC2)],
        PrayerName.asr => const <Color>[Color(0xFF7C4510), Color(0xFFB0722A)],
        PrayerName.maghrib => const <Color>[Color(0xFF55193F), Color(0xFFB84A3A)],
        PrayerName.isha => const <Color>[Color(0xFF0B1230), Color(0xFF26306E)],
      };
}

/// Resolves the current semantic colors from the theme brightness.
class RafelTheme {
  RafelTheme._();

  static RafelThemeData of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _data(isDark);
  }

  static RafelThemeData _data(bool isDark) {
    if (isDark) {
      return const RafelThemeData(
        background: RafelPalette.darkBackground,
        surface: RafelPalette.darkSurface,
        onSurface: RafelPalette.darkOnSurface,
        surfaceVariant: RafelPalette.darkSurfaceVariant,
        outline: RafelPalette.darkOutline,
        active: RafelPalette.darkActive,
        elevated: RafelPalette.darkElevated,
      );
    }
    return const RafelThemeData(
      background: RafelPalette.lightBackground,
      surface: RafelPalette.lightSurface,
      onSurface: RafelPalette.lightOnSurface,
      surfaceVariant: RafelPalette.lightSurfaceVariant,
      outline: RafelPalette.lightOutline,
      active: RafelPalette.lightActive,
      elevated: RafelPalette.lightElevated,
    );
  }
}

/// ThemeData factories for light and dark modes.
abstract final class RafelThemeScheme {
  static ThemeData light() => _build(false);

  static ThemeData dark() => _build(true);

  static ThemeData _build(bool isDark) {
    final bg = isDark ? RafelPalette.darkBackground : RafelPalette.lightBackground;
    final surface = isDark ? RafelPalette.darkSurface : RafelPalette.lightSurface;
    final onSurface = isDark ? RafelPalette.darkOnSurface : RafelPalette.lightOnSurface;
    final surfaceVariant = isDark ? RafelPalette.darkSurfaceVariant : RafelPalette.lightSurfaceVariant;
    final outline = isDark ? RafelPalette.darkOutline : RafelPalette.lightOutline;
    final active = isDark ? RafelPalette.darkActive : RafelPalette.lightActive;

    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: active,
      onPrimary: isDark ? RafelPalette.darkBackground : RafelPalette.lightBackground,
      primaryContainer: bg,
      onPrimaryContainer: active,
      secondary: surfaceVariant,
      onSecondary: onSurface,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: bg,
      onSurfaceVariant: surfaceVariant,
      error: isDark ? const Color(0xFFCF6679) : const Color(0xFFB3261E),
      onError: isDark ? RafelPalette.darkBackground : RafelPalette.lightBackground,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.5),
      inverseSurface: isDark ? RafelPalette.lightSurface : RafelPalette.darkSurface,
      inversePrimary: isDark ? RafelPalette.lightActive : RafelPalette.darkActive,
    );

    final textTheme = _textTheme(onSurface, surfaceVariant);

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RafelRadius.pill),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      fontFamily: 'IBMPlexSans',
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      // InkSparkle is the most expensive splash effect and stutters on
      // entry-level GPUs; the standard ripple reads the same and is cheap.
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'IBMPlexSans',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RafelRadius.lg),
          side: BorderSide(color: outline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: onSurface, size: 22),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: active,
          foregroundColor: isDark ? RafelPalette.darkBackground : RafelPalette.lightBackground,
          disabledBackgroundColor: surfaceVariant.withValues(alpha: 0.3),
          disabledForegroundColor: onSurface.withValues(alpha: 0.4),
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          shape: buttonShape,
          textStyle: const TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: BorderSide(color: outline),
          shape: buttonShape,
          textStyle: const TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onSurface,
          textStyle: const TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return isDark
                ? RafelPalette.darkSurfaceVariant.withValues(alpha: 0.4)
                : RafelPalette.lightSurfaceVariant.withValues(alpha: 0.4);
          }
          if (states.contains(WidgetState.selected)) {
            return isDark ? RafelPalette.darkBackground : Colors.white;
          }
          return isDark ? RafelPalette.darkSurfaceVariant : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return outline.withValues(alpha: 0.3);
          }
          if (states.contains(WidgetState.selected)) {
            return active;
          }
          return isDark
              ? RafelPalette.darkElevated
              : RafelPalette.lightElevated;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return outline;
        }),
        trackOutlineWidth: WidgetStateProperty.all(1.0),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: active,
        inactiveTrackColor: outline,
        thumbColor: active,
        overlayColor: active.withValues(alpha: 0.12),
        valueIndicatorColor: active,
        valueIndicatorTextStyle: TextStyle(
          color: isDark ? RafelPalette.darkBackground : RafelPalette.lightBackground,
          fontWeight: FontWeight.w600,
        ),
        trackHeight: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: surfaceVariant.withValues(alpha: 0.8)),
        labelStyle: TextStyle(color: surfaceVariant.withValues(alpha: 0.7)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RafelRadius.md),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RafelRadius.md),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RafelRadius.md),
          borderSide: BorderSide(color: active, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        modalBarrierColor: const Color(0xB3000000),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(RafelRadius.lg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RafelRadius.lg),
          side: BorderSide(color: outline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle: TextStyle(
          color: isDark ? Colors.black : Colors.white,
          fontFamily: 'IBMPlexSans',
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RafelRadius.md),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bg,
        selectedColor: active,
        disabledColor: bg,
        labelStyle: TextStyle(
          color: onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: isDark ? RafelPalette.darkBackground : RafelPalette.lightBackground,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RafelRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? active : surfaceVariant,
            letterSpacing: 0.1,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? active : surfaceVariant,
          );
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: active,
        linearTrackColor: surfaceVariant.withValues(alpha: 0.25),
        circularTrackColor: surfaceVariant.withValues(alpha: 0.25),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface,
        textColor: onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          // FadeForwards instead of PredictiveBack: the predictive-back
          // transition scales the page with rounded corners and briefly
          // exposes the chrome behind it, which read as a white flash on
          // mid-range phones. FadeForwards is cheaper and opaque.
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(Color onSurface, Color surfaceVariant) {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w400,
        height: 1.02,
        letterSpacing: -2.4,
      ),
      displayMedium: TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.w400,
        height: 1.05,
        letterSpacing: -1.6,
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w500,
        height: 1.15,
        letterSpacing: -0.6,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.25,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.55),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
      bodySmall: TextStyle(fontSize: 13, height: 1.45),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.25,
        letterSpacing: 0.1,
      ),
    ).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );
  }
}

/// Typography helpers resolved from the current theme.
abstract final class RafelType {
  static TextStyle arabic(BuildContext context, {
    double size = 20,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.4,
  }) {
    final theme = RafelTheme.of(context);
    return TextStyle(
      fontFamily: 'Amiri',
      fontSize: size,
      fontWeight: weight,
      color: color ?? theme.onSurface,
      height: height,
    );
  }

  static const TextStyle tabular = TextStyle(
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}
