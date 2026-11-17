import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/prayer_controller.dart';
import '../../core/date_formats.dart';
import '../../core/rafel_theme.dart';
import '../../models/prayer_name.dart';
import '../../services/timezone_service.dart';
import '../widgets/rafel_widgets.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late Future<int> _pendingCount;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _pendingCount = context.read<PrayerController>().pendingNotificationCount();
  }

  Future<void> _runCheck() async {
    if (_running) return;
    setState(() => _running = true);
    final controller = context.read<PrayerController>();
    await controller.scheduleNow();
    await controller.refreshPermissionState();
    if (!mounted) return;
    setState(() {
      _pendingCount = controller.pendingNotificationCount();
      _running = false;
    });
    showRafelSnack(context, 'Scheduling check complete.');
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerController>();
    final theme = RafelTheme.of(context);
    final settings = controller.settings;
    final location = settings.location;
    final day = controller.today;
    final schedule = controller.lastSchedule;
    final permission = controller.permission;
    final localNow = location == null
        ? controller.now
        : TimezoneService.convert(controller.now, location.timezoneId);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: const Text('Diagnostics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          RafelSpace.lg,
          RafelSpace.xs,
          RafelSpace.lg,
          RafelSpace.xxl,
        ),
        children: <Widget>[
          Text(
            'A plain record of what Rpray calculated and scheduled. Nothing '
            'here is simulated.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: theme.surfaceVariant.withValues(alpha: 0.72),
                ),
          ),
          const SizedBox(height: RafelSpace.md),
          FilledButton.icon(
            onPressed: _running ? null : _runCheck,
            icon: _running
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: theme.background,
                    ),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(_running ? 'Checking…' : 'Run schedule check'),
          ),
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('Environment'),
          RafelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _Row(label: 'Platform', value: _platformLabel),
                const RafelDivider(indent: 16),
                _Row(
                  label: 'Device timezone',
                  value: controller.deviceTimezoneId,
                ),
                const RafelDivider(indent: 16),
                _Row(
                  label: 'Location timezone',
                  value: location?.timezoneId ?? 'Not set',
                ),
                if (location != null) ...<Widget>[
                  const RafelDivider(indent: 16),
                  _Row(
                    label: 'Coordinates',
                    value: location.coordinateLabel,
                  ),
                  const RafelDivider(indent: 16),
                  _Row(
                    label: 'UTC offset',
                    value: TimezoneService.offsetLabel(localNow),
                  ),
                ],
                const RafelDivider(indent: 16),
                _Row(
                  label: 'Local time',
                  value:
                      '${formatGregorianDate(localNow)} · ${formatTime(localNow)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('Calculation'),
          RafelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _Row(
                  label: 'Method',
                  value: settings.calculation.method.label,
                ),
                const RafelDivider(indent: 16),
                _Row(
                  label: 'Asr',
                  value: settings.calculation.madhab.label,
                ),
                const RafelDivider(indent: 16),
                _Row(
                  label: 'High latitude',
                  value: settings.calculation.highLatitudeMethod.label,
                ),
                const RafelDivider(indent: 16),
                _Row(
                  label: 'Adjustments',
                  value: settings.calculation.adjustments.isEmpty
                      ? 'None'
                      : <String>[
                          for (final prayer in PrayerName.values)
                            if (settings.calculation.adjustments
                                    .forPrayer(prayer) !=
                                0)
                              '${prayer.englishLabel} '
                                  '${settings.calculation.adjustments.forPrayer(prayer) > 0 ? '+' : ''}'
                                  '${settings.calculation.adjustments.forPrayer(prayer)}',
                        ].join(' · '),
                ),
                const RafelDivider(indent: 16),
                _Row(
                  label: 'Hijri offset',
                  value: '${settings.hijriOffset} day(s)',
                ),
                const RafelDivider(indent: 16),
                _Row(
                  label: 'Hijri date',
                  value: controller.hijriToday?.formatted ?? 'Unavailable',
                ),
              ],
            ),
          ),
          if (day != null) ...<Widget>[
            const SizedBox(height: RafelSpace.xl),
            RafelSectionLabel(
              'Times for ${TimezoneService.civilDateKey(day.localDate)}',
            ),
            RafelCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < PrayerName.values.length; i++) ...<
                      Widget>[
                    _TimeRow(
                      label: PrayerName.values[i].englishLabel,
                      calculated: formatTime(
                        day.entry(PrayerName.values[i]).calculated,
                      ),
                      adjusted: formatTime(
                        day.entry(PrayerName.values[i]).adjusted,
                      ),
                    ),
                    if (i < PrayerName.values.length - 1)
                      const RafelDivider(indent: 16),
                  ],
                  const RafelDivider(indent: 16),
                  _Row(
                    label: 'Sunrise',
                    value: formatTime(day.sunrise),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('Scheduling'),
          RafelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _Row(
                  label: 'Notifications supported',
                  value: controller.notificationsSupported ? 'Yes' : 'No',
                ),
                const RafelDivider(indent: 16),
                _Row(
                  label: 'Permission',
                  value: permission == null
                      ? 'Unknown'
                      : permission.notificationsGranted
                          ? 'Granted'
                          : 'Not granted',
                ),
                const RafelDivider(indent: 16),
                _Row(
                  label: 'Exact alarms',
                  value: controller.nativeExactAlarms ||
                          permission?.exactAlarmsGranted == true
                      ? 'Allowed'
                      : 'Not allowed / inexact',
                ),
                const RafelDivider(indent: 16),
                _Row(
                  label: 'Last schedule',
                  value: schedule == null
                      ? 'Not run'
                      : '${formatTime(schedule.completedAt)} '
                          '(${schedule.plan.reminders.length} reminders, '
                          '${schedule.plan.events.length} occasions, '
                          '${schedule.scheduledAdhans} adhan)',
                ),
                const RafelDivider(indent: 16),
                FutureBuilder<int>(
                  future: _pendingCount,
                  builder: (context, snapshot) => _Row(
                    label: 'Pending in platform',
                    value: snapshot.hasData
                        ? '${snapshot.data}'
                        : snapshot.hasError
                            ? 'Unavailable'
                            : 'Checking…',
                  ),
                ),
              ],
            ),
          ),
          if (controller.error != null ||
              (schedule?.errors.isNotEmpty ?? false) ||
              (schedule?.warnings.isNotEmpty ?? false)) ...<Widget>[
            const SizedBox(height: RafelSpace.xl),
            const RafelSectionLabel('Warnings and errors'),
            RafelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (controller.error != null)
                    _Bullet(
                      text: controller.error!,
                      strong: true,
                    ),
                  if (schedule != null)
                    for (final error in schedule.errors)
                      _Bullet(text: error, strong: true),
                  if (schedule != null)
                    for (final warning in schedule.warnings)
                      _Bullet(text: warning),
                  if (day != null)
                    for (final warning in day.warnings)
                      _Bullet(text: warning),
                ],
              ),
            ),
          ],
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('Known limits'),
          RafelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                _Bullet(
                  text: 'Android full adhan uses a native AlarmManager and '
                      'foreground media service. It still requires verification '
                      'on a physical device.',
                ),
                _Bullet(
                  text: 'iOS cannot use MP3 files as notification sounds. '
                      'Reminders use the system sound; full adhan playback is '
                      'Android-only.',
                ),
                _Bullet(
                  text: 'Exact alarms are a user-granted Android permission. '
                      'Without it, delivery may be inexact.',
                ),
                _Bullet(
                  text: 'Some manufacturers delay background alarms under '
                      'battery optimisation. Rpray cannot override that from '
                      'inside the app.',
                ),
                _Bullet(
                  text: 'High-latitude Isha can differ from AlAdhan by more '
                      'than two minutes depending on the rule. This is a method '
                      'difference, not a hidden correction.',
                ),
                _Bullet(
                  text: 'Observed Hijri dates vary by locality. Confirm the '
                      'primary dates on the Occasions screen when your '
                      'community announces them.',
                ),
              ],
            ),
          ),
          const SizedBox(height: RafelSpace.md),
          Text(
            'Development verification used AlAdhan references offline. Rpray '
            'does not call AlAdhan at runtime.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: theme.surfaceVariant.withValues(alpha: 0.72),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  String get _platformLabel {
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RafelSpace.md,
        vertical: 13,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: theme.surfaceVariant.withValues(alpha: 0.72),
                  ),
            ),
          ),
          const SizedBox(width: RafelSpace.sm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: theme.onSurface.withValues(alpha: 0.82),
                    fontFeatures: RafelType.tabular.fontFeatures,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.calculated,
    required this.adjusted,
  });

  final String label;
  final String calculated;
  final String adjusted;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final differs = calculated != adjusted;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RafelSpace.md,
        vertical: 13,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: theme.surfaceVariant.withValues(alpha: 0.72),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              differs ? '$calculated → $adjusted' : calculated,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: theme.onSurface.withValues(alpha: 0.82),
                    fontFeatures: RafelType.tabular.fontFeatures,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: theme.onSurface.withValues(alpha: strong ? 0.9 : 0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: theme.onSurface.withValues(alpha: strong ? 0.85 : 0.48),
                    height: 1.55,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
