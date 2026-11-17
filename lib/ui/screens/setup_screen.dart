import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/prayer_controller.dart';
import '../../core/rafel_theme.dart';
import '../../models/prayer_name.dart';
import '../sheets/calculation_sheets.dart';
import '../widgets/rafel_widgets.dart';
import 'city_picker_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final PageController _page = PageController();
  int _currentPage = 0;
  bool _continuing = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    _page.nextPage(
      duration: RafelDurations.pageTransition,
      curve: RafelAnimCurves.smooth,
    );
  }

  void _prev() {
    _page.previousPage(
      duration: RafelDurations.pageTransition,
      curve: RafelAnimCurves.smooth,
    );
  }

  Future<void> _chooseCity(PrayerController controller) async {
    final selection = await Navigator.of(context).push<LocationSelection>(
      MaterialPageRoute<LocationSelection>(
        builder: (_) => CityPickerScreen(
          current: controller.settings.location,
        ),
      ),
    );
    if (selection == null || !mounted) return;
    await controller.applyLocation(
      selection.location,
      suggestedMethod: selection.suggestedMethod,
    );
  }

  Future<void> _finish(PrayerController controller) async {
    if (!controller.hasLocation) {
      showRafelSnack(
        context,
        'Choose your location first so Rpray knows where and when.',
      );
      // Go back to location step if needed.
      _page.animateToPage(
        1,
        duration: RafelDurations.pageTransition,
        curve: RafelAnimCurves.smooth,
      );
      return;
    }
    setState(() => _continuing = true);
    try {
      if (controller.settings.notificationsEnabled) {
        await controller.requestNotificationPermissions(enableOnGrant: true);
      }
      await controller.setOnboardingComplete(true);
      await controller.scheduleNow();
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerController>();
    final theme = RafelTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Progress dots
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RafelSpace.lg,
                RafelSpace.md,
                RafelSpace.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < 4; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 6),
                    _StepDot(active: i == _currentPage, done: i < _currentPage),
                  ],
                  const Spacer(),
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: _prev,
                      icon: Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: theme.onSurface.withValues(alpha: 0.6),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: <Widget>[
                  // Page 0 — Welcome
                  _WelcomePage(onNext: _next),

                  // Page 1 — Location
                  _LocationPage(
                    controller: controller,
                    onChooseCity: () => _chooseCity(controller),
                    onNext: _next,
                  ),

                  // Page 2 — Calculation
                  _CalculationPage(
                    controller: controller,
                    onNext: _next,
                  ),

                  // Page 3 — Notifications + Launch
                  _NotificationsPage(
                    controller: controller,
                    continuing: _continuing,
                    onFinish: () => _finish(controller),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step dot indicator
// ─────────────────────────────────────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  const _StepDot({required this.active, required this.done});

  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return AnimatedContainer(
      duration: RafelDurations.quick,
      curve: RafelAnimCurves.smooth,
      width: active ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RafelRadius.pill),
        color: active
            ? theme.onSurface
            : done
                ? theme.onSurface.withValues(alpha: 0.4)
                : theme.onSurface.withValues(alpha: 0.15),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page layout helper
// ─────────────────────────────────────────────────────────────────────────────

class _PageLayout extends StatelessWidget {
  const _PageLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        RafelSpace.lg,
        RafelSpace.xl,
        RafelSpace.lg,
        RafelSpace.xxl,
      ),
      children: children,
    );
  }
}

Widget _pageTitle(BuildContext context, String title) {
  final theme = RafelTheme.of(context);
  return Text(
    title,
    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: theme.onSurface,
          fontWeight: FontWeight.w600,
        ),
  );
}

Widget _pageSubtitle(BuildContext context, String text) {
  final theme = RafelTheme.of(context);
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: theme.surfaceVariant.withValues(alpha: 0.72),
            height: 1.55,
          ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 0 — Welcome
// ─────────────────────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return _PageLayout(children: <Widget>[
      // Large crescent + wordmark
      Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
          ),
          child: Column(
            children: <Widget>[
              RafelCrescentIcon(
                size: 72,
                color: theme.onSurface.withValues(alpha: 0.85),
              ),
              const SizedBox(height: RafelSpace.lg),
              Text(
                RafelStrings.appName,
                style: TextStyle(
                  fontFamily: 'IBMPlexSans',
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                  color: theme.onSurface,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                RafelStrings.appNameArabic,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 22,
                  color: theme.surfaceVariant.withValues(alpha: 0.72),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: RafelSpace.xxl),
      _pageTitle(context, 'Welcome'),
      _pageSubtitle(
        context,
        'Accurate prayer times, six advance reminders and one quiet space '
        'for the day.\n\nSet up takes about two minutes.',
      ),
      const SizedBox(height: RafelSpace.xl),
      FilledButton(
        onPressed: onNext,
        child: const Text('Get started'),
      ),
      const SizedBox(height: RafelSpace.sm),
      Center(
        child: Text(
          'Location stays on this device. Prayer times are calculated offline.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: theme.surfaceVariant.withValues(alpha: 0.72),
              ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1 — Location
// ─────────────────────────────────────────────────────────────────────────────

class _LocationPage extends StatelessWidget {
  const _LocationPage({
    required this.controller,
    required this.onChooseCity,
    required this.onNext,
  });

  final PrayerController controller;
  final VoidCallback onChooseCity;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final location = controller.settings.location;

    return _PageLayout(children: <Widget>[
      _pageTitle(context, 'Where you pray'),
      _pageSubtitle(
        context,
        'Rpray uses your coordinates and an IANA timezone. There is no '
        'silent default city.',
      ),
      const SizedBox(height: RafelSpace.lg),
      RafelCard(
        padding: const EdgeInsets.all(RafelSpace.md),
        borderColor: location == null
            ? theme.outline
            : theme.surfaceVariant.withValues(alpha: 0.72),
        child: location == null
            ? Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.outline),
                          color: theme.elevated,
                        ),
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: theme.surfaceVariant.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(width: RafelSpace.sm),
                      Text(
                        'No location chosen yet',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: theme.onSurface,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RafelSpace.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: RafelActionTile(
                          label: 'Use my location',
                          icon: Icons.near_me_outlined,
                          filled: true,
                          onTap: controller.isLocating
                              ? null
                              : () => controller.useDeviceLocation(),
                        ),
                      ),
                      const SizedBox(width: RafelSpace.xs),
                      Expanded(
                        child: RafelActionTile(
                          label: 'Choose a city',
                          icon: Icons.travel_explore,
                          onTap: onChooseCity,
                        ),
                      ),
                    ],
                  ),
                  if (controller.isLocating) ...<Widget>[
                    const SizedBox(height: RafelSpace.md),
                    const LinearProgressIndicator(minHeight: 1.5),
                  ],
                  if (controller.locationError != null) ...<Widget>[
                    const SizedBox(height: RafelSpace.md),
                    Text(
                      controller.locationError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: theme.surfaceVariant.withValues(alpha: 0.72),
                          ),
                    ),
                  ],
                ],
              )
            : Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.outline),
                      color: theme.elevated,
                    ),
                    child: Icon(Icons.location_on, size: 18, color: theme.onSurface),
                  ),
                  const SizedBox(width: RafelSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          location.displayName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: theme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${location.coordinateLabel} · ${location.timezoneId}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: theme.surfaceVariant.withValues(alpha: 0.72),
                              ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onChooseCity,
                    child: const Text('Change'),
                  ),
                ],
              ),
      ),
      const SizedBox(height: RafelSpace.xl),
      FilledButton(
        onPressed: location != null ? onNext : null,
        child: const Text('Continue'),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 2 — Calculation
// ─────────────────────────────────────────────────────────────────────────────

class _CalculationPage extends StatelessWidget {
  const _CalculationPage({
    required this.controller,
    required this.onNext,
  });

  final PrayerController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    final location = settings.location;
    final method = settings.calculation.method;
    final highLatitude =
        location != null && location.latitude.abs() >= 48;

    return _PageLayout(children: <Widget>[
      _pageTitle(context, 'Calculation'),
      _pageSubtitle(
        context,
        'Choose the convention followed by your community. You can refine '
        'every prayer later.',
      ),
      const SizedBox(height: RafelSpace.lg),
      RafelCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            RafelSettingRow(
              leading: Icons.calculate_outlined,
              title: 'Method',
              subtitle: method.label,
              onTap: () async {
                final result = await showMethodSheet(context, method);
                if (result != null) await controller.setMethod(result);
              },
            ),
            const RafelDivider(indent: 60),
            RafelSettingRow(
              leading: Icons.balance_outlined,
              title: 'Asr',
              subtitle: settings.calculation.madhab.label,
              onTap: () async {
                final result = await showMadhabSheet(
                  context,
                  settings.calculation.madhab,
                );
                if (result != null) await controller.setMadhab(result);
              },
            ),
            if (highLatitude) ...<Widget>[
              const RafelDivider(indent: 60),
              RafelSettingRow(
                leading: Icons.nights_stay_outlined,
                title: 'High-latitude rule',
                subtitle: settings.calculation.highLatitudeMethod.label,
                onTap: () async {
                  final result = await showHighLatitudeSheet(
                    context,
                    settings.calculation.highLatitudeMethod,
                  );
                  if (result != null) {
                    await controller.setHighLatitude(result);
                  }
                },
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: RafelSpace.xl),
      FilledButton(
        onPressed: onNext,
        child: const Text('Continue'),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 3 — Notifications + Finish
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage({
    required this.controller,
    required this.continuing,
    required this.onFinish,
  });

  final PrayerController controller;
  final bool continuing;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final settings = controller.settings;

    return _PageLayout(children: <Widget>[
      _pageTitle(context, 'Reminders'),
      _pageSubtitle(
        context,
        'Six advance reminders per prayer, from 30 minutes down to 5. '
        'The full adhan plays at prayer time.',
      ),
      const SizedBox(height: RafelSpace.lg),
      RafelCard(
        padding: const EdgeInsets.symmetric(
          horizontal: RafelSpace.md,
          vertical: 12,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    controller.notificationsSupported
                        ? 'Prayer notifications'
                        : 'Notifications unavailable',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: theme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.notificationsSupported
                        ? 'Reminders and occasions on this device'
                        : 'Scheduled notifications need Android or iOS',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: theme.surfaceVariant.withValues(alpha: 0.72),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Switch(
              value: settings.notificationsEnabled,
              onChanged: controller.notificationsSupported
                  ? controller.setNotificationsEnabled
                  : null,
            ),
          ],
        ),
      ),
      const SizedBox(height: RafelSpace.sm),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final minutes in reminderIntervalsDescending)
            RafelPill(label: '$minutes min', compact: true),
        ],
      ),
      const SizedBox(height: RafelSpace.xl),
      FilledButton(
        onPressed: continuing ? null : onFinish,
        child: continuing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: Colors.white,
                ),
              )
            : const Text('Begin with Rpray'),
      ),
      const SizedBox(height: RafelSpace.sm),
      Center(
        child: Text(
          'Location stays on this device. Prayer times are calculated offline.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: theme.surfaceVariant.withValues(alpha: 0.72),
              ),
        ),
      ),
    ]);
  }
}
