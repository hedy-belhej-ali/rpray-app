import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/prayer_controller.dart';
import '../../core/date_formats.dart';
import '../../core/rafel_theme.dart';
import '../../models/prayer_name.dart';
import '../../services/audio_asset_service.dart';
import '../widgets/rafel_widgets.dart';

Future<void> showPrayerDetailSheet(
  BuildContext context,
  PrayerName prayer,
) {
  final theme = RafelTheme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: theme.surface,
    builder: (_) => _PrayerDetailSheet(prayer: prayer),
  );
}

class _PrayerDetailSheet extends StatelessWidget {
  const _PrayerDetailSheet({required this.prayer});

  final PrayerName prayer;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerController>();
    final theme = RafelTheme.of(context);
    final entry = controller.today?.entries[prayer];
    final pref = controller.settings.prefFor(prayer);
    final adjustment =
        controller.settings.calculation.adjustments.forPrayer(prayer);
    final warnings = controller.today?.warnings ?? const <String>[];

    // Fixed-height sheet: laid out once, then slid up as a whole.
    // (DraggableScrollableSheet re-laid-out all content on every entrance
    // frame and drag, which stuttered on mid-range devices.)
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          RafelSpace.lg,
          0,
          RafelSpace.lg,
          MediaQuery.viewPaddingOf(context).bottom + RafelSpace.xxl,
        ),
        children: <Widget>[
          const RafelSheetHandle(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      prayer.arabicLabel,
                      style: RafelType.arabic(
                        context,
                        size: 36,
                        weight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prayer.englishLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: theme.surfaceVariant.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                    if (entry != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        formatTime(entry.adjusted),
                        style: RafelType.tabular.copyWith(
                          fontFamily: 'IBMPlexSans',
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: theme.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: RafelSpace.lg),
          if (entry != null) ...<Widget>[
            RafelSectionLabel('Calculation'),
            RafelCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _InfoRow(
                    label: 'Calculated',
                    value: formatTime(entry.calculated),
                  ),
                  const RafelDivider(indent: 16),
                  _InfoRow(
                    label: 'Your adjustment',
                    value: adjustment == 0
                        ? 'None'
                        : '${adjustment > 0 ? '+' : ''}$adjustment min',
                  ),
                  const RafelDivider(indent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      RafelSpace.md,
                      RafelSpace.sm,
                      RafelSpace.sm,
                      RafelSpace.sm,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Move this prayer',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        _StepButton(
                          icon: Icons.remove,
                          onTap: adjustment <= -60
                              ? null
                              : () => controller.setAdjustment(
                                    prayer,
                                    adjustment - 1,
                                  ),
                        ),
                        SizedBox(
                          width: 58,
                          child: Text(
                            '${adjustment > 0 ? '+' : ''}$adjustment',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontFeatures: RafelType.tabular.fontFeatures,
                                ),
                          ),
                        ),
                        _StepButton(
                          icon: Icons.add,
                          onTap: adjustment >= 60
                              ? null
                              : () => controller.setAdjustment(
                                    prayer,
                                    adjustment + 1,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RafelSpace.lg),
          ],
          RafelSectionLabel('Advance reminders'),
          RafelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (var i = 0; i < reminderIntervalsDescending.length; i++) ...[
                  _ReminderRow(
                    prayer: prayer,
                    minutes: reminderIntervalsDescending[i],
                    enabled: pref.enabledIntervals
                        .contains(reminderIntervalsDescending[i]),
                    prayerTime: entry?.adjusted,
                    onChanged: (value) => controller.setReminderEnabled(
                      prayer,
                      reminderIntervalsDescending[i],
                      value,
                    ),
                  ),
                  if (i < reminderIntervalsDescending.length - 1)
                    const RafelDivider(indent: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: RafelSpace.lg),
          RafelSectionLabel('At prayer time'),
          RafelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _SoundToggleRow(
                  title: 'Full adhan',
                  subtitle: entry == null
                      ? 'Plays at prayer time'
                      : 'Plays at ${formatTime(entry.adjusted)}',
                  asset: AudioAssetService.adhanPreviewAsset,
                  enabled: pref.adhanEnabled,
                  onChanged: (value) =>
                      controller.setAdhanEnabled(prayer, value),
                  onPreview: controller.previewAdhan,
                ),
                const RafelDivider(indent: 16),
                _SoundToggleRow(
                  title: 'Prayer notification',
                  subtitle: 'Show the prayer name and time',
                  enabled: pref.prayerEnabled,
                  onChanged: (value) =>
                      controller.setPrayerEnabled(prayer, value),
                ),
              ],
            ),
          ),
          if (warnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: RafelSpace.lg),
            RafelSectionLabel('Notes for today'),
            RafelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final warning in warnings.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.surfaceVariant.withValues(alpha: 0.72),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              warning,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: theme.surfaceVariant.withValues(
                                        alpha: 0.72),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

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
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: theme.surfaceVariant.withValues(alpha: 0.72),
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: theme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Material(
      color: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 17,
            color: onTap == null
                ? theme.surfaceVariant.withValues(alpha: 0.72)
                : theme.surfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.prayer,
    required this.minutes,
    required this.enabled,
    required this.prayerTime,
    required this.onChanged,
  });

  final PrayerName prayer;
  final int minutes;
  final bool enabled;
  final DateTime? prayerTime;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final asset = AudioAssetService.reminderPreviewAsset(prayer, minutes);
    return _SoundToggleRow(
      title: '$minutes minutes before',
      subtitle: prayerTime == null
          ? 'Recorded reminder'
          : formatTime(prayerTime!.subtract(Duration(minutes: minutes))),
      asset: asset,
      enabled: enabled,
      onChanged: onChanged,
      onPreview: () => context
          .read<PrayerController>()
          .previewReminder(prayer, minutes),
    );
  }
}

class _SoundToggleRow extends StatelessWidget {
  const _SoundToggleRow({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
    this.asset,
    this.onPreview,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final String? asset;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<PrayerController>();
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
          if (asset != null && onPreview != null)
            ValueListenableBuilder<String?>(
              valueListenable: controller.preview.playingAsset,
              builder: (context, playing, _) {
                final isPlaying = playing == asset;
                return IconButton(
                  tooltip: isPlaying ? 'Stop preview' : 'Preview sound',
                  visualDensity: VisualDensity.compact,
                  onPressed: onPreview,
                  icon: Icon(
                    isPlaying
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                    size: 22,
                    color: theme.surfaceVariant.withValues(alpha: 0.72),
                  ),
                );
              },
            ),
          const SizedBox(width: 4),
          Switch(
            value: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
