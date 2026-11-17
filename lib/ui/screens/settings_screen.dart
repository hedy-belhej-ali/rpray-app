import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/prayer_controller.dart';
import '../../core/rafel_theme.dart';
import '../../services/audio_asset_service.dart';
import '../screens/adjustments_screen.dart';
import '../screens/city_picker_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/occasion_settings_screen.dart';
import '../sheets/calculation_sheets.dart';
import '../widgets/rafel_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerController>();
    final theme = RafelTheme.of(context);
    final settings = controller.settings;
    final location = settings.location;
    final calculation = settings.calculation;
    final permission = controller.permission;
    final schedule = controller.lastSchedule;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: theme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          RafelSpace.lg,
          RafelSpace.lg,
          RafelSpace.lg,
          RafelSpace.xxl,
        ),
        children: <Widget>[
          // ── Page header ────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: theme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Location, calculation and notifications.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: theme.surfaceVariant.withValues(alpha: 0.72),
                      ),
                ),
              ],
            ),
          ),

          // ── Appearance ──────────────────────────────────────────────────────
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('Appearance'),
          RafelCard(
            padding: EdgeInsets.zero,
            child: _ThemeSegmentRow(controller: controller),
          ),

          // ── Location ───────────────────────────────────────────────────────
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('Location'),
          RafelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                RafelSettingRow(
                  leading: Icons.location_on_outlined,
                  title: location?.displayName ?? 'No location',
                  subtitle: location == null
                      ? 'Choose a city or use the device location'
                      : '${location.coordinateLabel} · ${location.timezoneId}',
                  trailing: TextButton(
                    onPressed: () => _chooseCity(context, controller),
                    child: const Text('Change'),
                  ),
                  showChevron: false,
                ),
                const RafelDivider(indent: 60),
                RafelSettingRow(
                  leading: Icons.near_me_outlined,
                  title: 'Use my location',
                  subtitle: controller.isLocating
                      ? 'Finding a fix…'
                      : 'Read the device coordinates once',
                  trailing: controller.isLocating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : null,
                  onTap: controller.isLocating
                      ? null
                      : () => _useDeviceLocation(context, controller),
                ),
              ],
            ),
          ),
          if (settings.locationPermissionDenied)
            Padding(
              padding: const EdgeInsets.only(top: RafelSpace.xs),
              child: Text(
                'Location permission was denied. Manual city selection works '
                'without it.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: theme.surfaceVariant.withValues(alpha: 0.72),
                    ),
              ),
            ),

          // ── Prayer times ───────────────────────────────────────────────────
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('Prayer times'),
          RafelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                RafelSettingRow(
                  leading: Icons.calculate_outlined,
                  title: 'Calculation method',
                  subtitle: calculation.method.label,
                  onTap: () async {
                    final result = await showMethodSheet(
                      context,
                      calculation.method,
                    );
                    if (result != null) await controller.setMethod(result);
                  },
                ),
                const RafelDivider(indent: 60),
                RafelSettingRow(
                  leading: Icons.balance_outlined,
                  title: 'Asr calculation',
                  subtitle: calculation.madhab.label,
                  onTap: () async {
                    final result = await showMadhabSheet(
                      context,
                      calculation.madhab,
                    );
                    if (result != null) await controller.setMadhab(result);
                  },
                ),
                const RafelDivider(indent: 60),
                RafelSettingRow(
                  leading: Icons.nights_stay_outlined,
                  title: 'High-latitude rule',
                  subtitle: calculation.highLatitudeMethod.label,
                  onTap: () async {
                    final result = await showHighLatitudeSheet(
                      context,
                      calculation.highLatitudeMethod,
                    );
                    if (result != null) {
                      await controller.setHighLatitude(result);
                    }
                  },
                ),
                const RafelDivider(indent: 60),
                RafelSettingRow(
                  leading: Icons.tune,
                  title: 'Prayer adjustments',
                  subtitle: calculation.adjustments.isEmpty
                      ? 'No adjustments applied'
                      : 'Local minute offsets are applied',
                  trailing: Text(
                    calculation.adjustments.isEmpty ? 'None' : 'Custom',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: theme.surfaceVariant.withValues(alpha: 0.72),
                        ),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdjustmentsScreen(),
                    ),
                  ),
                ),
                const RafelDivider(indent: 60),
                RafelSettingRow(
                  leading: Icons.event_outlined,
                  title: 'Hijri offset',
                  subtitle: settings.hijriOffset == 0
                      ? 'No offset · Umm al-Qura estimate'
                      : 'Calendar moved ${settings.hijriOffset.abs()} '
                          'day${settings.hijriOffset.abs() == 1 ? '' : 's'}',
                  trailing: Text(
                    settings.hijriOffset == 0
                        ? '0'
                        : '${settings.hijriOffset > 0 ? '+' : ''}'
                            '${settings.hijriOffset}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () async {
                    final result = await showHijriOffsetSheet(
                      context,
                      settings.hijriOffset,
                    );
                    if (result != null) {
                      await controller.setHijriOffset(result);
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Notifications ──────────────────────────────────────────────────
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('Notifications'),
          RafelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _SwitchRow(
                  icon: Icons.notifications_outlined,
                  title: 'Prayer notifications',
                  subtitle: settings.notificationsEnabled
                      ? 'Six reminders and the full adhan'
                      : 'Everything is paused',
                  value: settings.notificationsEnabled,
                  onChanged: controller.notificationsSupported
                      ? controller.setNotificationsEnabled
                      : null,
                ),
                const RafelDivider(indent: 60),
                RafelSettingRow(
                  leading: Icons.shield_outlined,
                  title: 'Permission',
                  subtitle: permission == null
                      ? 'Checking…'
                      : permission.notificationsGranted
                          ? 'Notifications are allowed'
                          : 'Notifications are not allowed',
                  trailing: RafelPill(
                    label: permission?.notificationsGranted == true
                        ? 'Allowed'
                        : 'Action needed',
                    compact: true,
                    filled: permission?.notificationsGranted == true,
                  ),
                  onTap: isMobile
                      ? () => _requestPermissions(context, controller)
                      : null,
                ),
                if (isAndroid) ...<Widget>[
                  const RafelDivider(indent: 60),
                  RafelSettingRow(
                    leading: Icons.alarm_on_outlined,
                    title: 'Exact alarms',
                    subtitle: controller.nativeExactAlarms
                        ? 'The adhan alarm can fire on time'
                        : 'Timing may drift without this permission',
                    trailing: RafelPill(
                      label: controller.nativeExactAlarms ? 'Allowed' : 'Open',
                      compact: true,
                      filled: controller.nativeExactAlarms,
                    ),
                    onTap: () => _requestPermissions(context, controller),
                  ),
                ],
                const RafelDivider(indent: 60),
                RafelSettingRow(
                  leading: Icons.science_outlined,
                  title: 'Send a test notification',
                  subtitle: 'Checks the channel and permission on this device',
                  onTap: isMobile
                      ? () => _sendTest(context, controller)
                      : null,
                ),
                const RafelDivider(indent: 60),
                RafelSettingRow(
                  leading: Icons.open_in_new,
                  title: 'System notification settings',
                  subtitle: 'Open this app\'s notification page',
                  onTap: isMobile
                      ? controller.openNotificationSettings
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: RafelSpace.xs),
          _AdhanPreviewRow(controller: controller),

          // ── Islamic occasions ──────────────────────────────────────────────
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('Islamic occasions'),
          RafelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                RafelSettingRow(
                  leading: Icons.nights_stay_outlined,
                  title: 'Occasion reminders',
                  subtitle:
                      '${settings.occasionPrefs.values.where((on) => on).length} '
                      'of ${settings.occasionPrefs.length} enabled',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OccasionSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Diagnostics ────────────────────────────────────────────────────
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('Diagnostics'),
          RafelCard(
            padding: EdgeInsets.zero,
            child: RafelSettingRow(
              leading: Icons.monitor_heart_outlined,
              title: 'Diagnostics',
              subtitle: schedule == null
                  ? 'Scheduling has not run yet'
                  : '${schedule.scheduledNotifications} notifications · '
                      '${schedule.scheduledAdhans} adhan alarms',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DiagnosticsScreen(),
                ),
              ),
            ),
          ),

          // ── About ──────────────────────────────────────────────────────────
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('About'),
          RafelCard(
            padding: const EdgeInsets.all(RafelSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const RafelLogo(size: 44, radius: 12),
                    const SizedBox(width: RafelSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const RafelWordmark(compact: true),
                          const SizedBox(height: 4),
                          Text(
                            'Version 1.0.0',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: theme.surfaceVariant
                                      .withValues(alpha: 0.72),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RafelSpace.md),
                Text(
                  'Prayer times are calculated offline from your coordinates '
                  'and chosen method. Hijri dates use the Umm al-Qura calendar '
                  'and remain independent from prayer calculation.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: theme.surfaceVariant.withValues(alpha: 0.72),
                        height: 1.55,
                      ),
                ),
                const SizedBox(height: RafelSpace.md),
                const RafelDivider(),
                const SizedBox(height: RafelSpace.md),
                const _SocialLinksRow(),
              ],
            ),
          ),
          if (schedule != null && schedule.warnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: RafelSpace.md),
            Text(
              schedule.warnings.first,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: theme.surfaceVariant.withValues(alpha: 0.72),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _chooseCity(
    BuildContext context,
    PrayerController controller,
  ) async {
    final selection = await Navigator.of(context).push<LocationSelection>(
      MaterialPageRoute<LocationSelection>(
        builder: (_) => CityPickerScreen(
          current: controller.settings.location,
        ),
      ),
    );
    if (selection == null) return;
    await controller.applyLocation(
      selection.location,
      suggestedMethod: selection.suggestedMethod,
    );
  }

  Future<void> _useDeviceLocation(
    BuildContext context,
    PrayerController controller,
  ) async {
    final success = await controller.useDeviceLocation();
    if (!context.mounted) return;
    if (success) {
      showRafelSnack(context, 'Using the device location.');
    } else if (controller.locationError != null) {
      showRafelSnack(context, controller.locationError!);
    }
  }

  Future<void> _requestPermissions(
    BuildContext context,
    PrayerController controller,
  ) async {
    final state =
        await controller.requestNotificationPermissions(enableOnGrant: true);
    if (!context.mounted) return;
    showRafelSnack(
      context,
      state.notificationsGranted
          ? 'Notification permission is granted.'
          : 'Notification permission is still off. Open system settings to '
              'change it.',
    );
  }

  Future<void> _sendTest(
    BuildContext context,
    PrayerController controller,
  ) async {
    final state = await controller.requestNotificationPermissions(
      enableOnGrant: true,
    );
    if (!state.notificationsGranted) {
      if (context.mounted) {
        showRafelSnack(
          context,
          'Allow notifications before sending a test.',
        );
      }
      return;
    }
    await controller.sendTestNotification();
    if (context.mounted) {
      showRafelSnack(context, 'Test notification sent.');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme segmented control row
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeSegmentRow extends StatelessWidget {
  const _ThemeSegmentRow({required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final isDark = controller.themeMode == ThemeMode.dark;
    return Container(
      margin: const EdgeInsets.all(RafelSpace.xs),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.elevated,
        borderRadius: BorderRadius.circular(RafelRadius.md),
      ),
      child: Row(
        children: <Widget>[
          _ThemeChip(
            label: 'Light',
            icon: Icons.light_mode_outlined,
            activeIcon: Icons.light_mode,
            selected: !isDark,
            onTap: () => controller.setThemeMode(false),
          ),
          const SizedBox(width: 4),
          _ThemeChip(
            label: 'Dark',
            icon: Icons.dark_mode_outlined,
            activeIcon: Icons.dark_mode,
            selected: isDark,
            onTap: () => controller.setThemeMode(true),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: RafelDurations.quick,
          curve: RafelAnimCurves.smooth,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? theme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(RafelRadius.sm),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
            border: Border.all(
              color: selected ? theme.outline : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                selected ? activeIcon : icon,
                size: 16,
                color: selected ? theme.active : theme.surfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'IBMPlexSans',
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? theme.onSurface : theme.surfaceVariant,
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
// Switch row
// ─────────────────────────────────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RafelSpace.md,
        8,
        RafelSpace.sm,
        8,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.outline),
              color: theme.elevated,
            ),
            child: Icon(icon, size: 17, color: theme.onSurface.withValues(alpha: 0.75)),
          ),
          const SizedBox(width: RafelSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: theme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: theme.surfaceVariant.withValues(alpha: 0.72),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Adhan preview row
// ─────────────────────────────────────────────────────────────────────────────

class _AdhanPreviewRow extends StatelessWidget {
  const _AdhanPreviewRow({required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: controller.preview.playingAsset,
      builder: (context, playing, _) {
        final isPlaying = playing == AudioAssetService.adhanPreviewAsset;
        return Padding(
          padding: const EdgeInsets.only(top: RafelSpace.xs),
          child: RafelOutlinedAction(
            label: isPlaying ? 'Stop adhan preview' : 'Preview the full adhan',
            icon: isPlaying
                ? Icons.stop_circle_outlined
                : Icons.volume_up_outlined,
            onTap: controller.previewAdhan,
          ),
        );
      },
    );
  }
}

class RafelOutlinedAction extends StatelessWidget {
  const RafelOutlinedAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: theme.onSurface),
      label: Text(label, style: TextStyle(color: theme.onSurface)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: theme.outline),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Social links footer
// ─────────────────────────────────────────────────────────────────────────────

class _SocialLink {
  const _SocialLink({required this.label, required this.url, required this.icon});

  final String label;
  final String url;
  final IconData icon;
}

const List<_SocialLink> _kSocialLinks = <_SocialLink>[
  _SocialLink(
    label: 'GitHub',
    url: 'https://github.com/hedy-belhej-ali',
    icon: Icons.code_rounded,
  ),
  _SocialLink(
    label: 'LinkedIn',
    url: 'https://www.linkedin.com/in/hedy-belhej-ali-291ab532a',
    icon: Icons.work_outline_rounded,
  ),
  _SocialLink(
    label: 'Instagram',
    url: 'https://www.instagram.com/hedyy69/',
    icon: Icons.photo_camera_outlined,
  ),
];

class _SocialLinksRow extends StatelessWidget {
  const _SocialLinksRow();

  Future<void> _open(BuildContext context, _SocialLink link) async {
    final bool opened = await launchUrl(
      Uri.parse(link.url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      showRafelSnack(context, 'Could not open the link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Row(
      children: <Widget>[
        for (int i = 0; i < _kSocialLinks.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: RafelSpace.xs),
          Expanded(
            child: GestureDetector(
              onTap: () => _open(context, _kSocialLinks[i]),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: theme.elevated,
                  borderRadius: BorderRadius.circular(RafelRadius.sm),
                  border: Border.all(color: theme.outline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(_kSocialLinks[i].icon, size: 15, color: theme.active),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _kSocialLinks[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'IBMPlexSans',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
