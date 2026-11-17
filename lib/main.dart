import 'dart:async';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'controllers/prayer_controller.dart';
import 'core/rafel_theme.dart';
import 'services/timezone_service.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/widgets/rafel_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TimezoneService.initialize();
  Intl.defaultLocale = 'en';
  await initializeDateFormatting('en');
  runApp(
    ChangeNotifierProvider<PrayerController>(
      create: (_) {
        final controller = PrayerController();
        unawaited(controller.initialize());
        return controller;
      },
      child: const RafelApp(),
    ),
  );
}

class RafelApp extends StatelessWidget {
  const RafelApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the user's saved theme preference from the controller.
    final themeMode = context.select<PrayerController, ThemeMode>(
      (c) => c.themeMode,
    );
    return MaterialApp(
      title: RafelStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: RafelThemeScheme.light(),
      darkTheme: RafelThemeScheme.dark(),
      themeMode: themeMode,
      home: const RafelRoot(),
    );
  }
}

class RafelRoot extends StatelessWidget {
  const RafelRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<PrayerController, bool>((c) => c.isLoading);
    final needsSetup = context.select<PrayerController, bool>((c) => c.needsSetup);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Own the system chrome so Android never paints its default white
    // navigation/status bars between route changes.
    final SystemUiOverlayStyle chrome = isLoading
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: RafelPalette.darkBackground,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarContrastEnforced: false,
          )
        : SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor:
                Theme.of(context).scaffoldBackgroundColor,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: chrome,
      child: isLoading
          ? const _RafelSplash()
          : (needsSetup ? const SetupScreen() : const HomeShell()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Splash Screen
// ─────────────────────────────────────────────────────────────────────────────

/// The loading screen paints the brand ink in both theme modes so it blends
/// seamlessly with the native launch window, which also stays ink.
class _RafelSplash extends StatefulWidget {
  const _RafelSplash();

  @override
  State<_RafelSplash> createState() => _RafelSplashState();
}

class _RafelSplashState extends State<_RafelSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _loaderOpacity;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Logo: 0–45%
    _logoOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    // Loader: 55–85%
    _loaderOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Honour the platform "remove animations" accessibility setting.
    if (MediaQuery.disableAnimationsOf(context)) _ctrl.duration = Duration.zero;
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = RafelPalette.darkBackground;
    return Scaffold(
      backgroundColor: ink,
      body: Stack(
        children: <Widget>[
          // The app mark, exactly in the middle.
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Opacity(
                opacity: _logoOpacity.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: const _SplashLogo(),
                ),
              ),
            ),
          ),
          // The loading loop sits at the bottom of the screen, lifted well
          // above the very edge (and above the gesture bar).
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewPaddingOf(context).bottom + 72,
              ),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => Opacity(
                  opacity: _loaderOpacity.value,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: RafelPalette.darkOnSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app mark with softly rounded corners and a layered drop shadow so it
/// visibly lifts off the ink background.
class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    const radius = 30.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          // Crisp contact shadow right under the tile.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
          // Wide, soft shadow that reads at a distance.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 40,
            offset: const Offset(0, 18),
            spreadRadius: 6,
          ),
        ],
      ),
      child: const RafelLogo(size: 140, radius: radius),
    );
  }
}
