import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/prayer_controller.dart';
import '../../core/date_formats.dart';
import '../../core/rafel_theme.dart';
import '../../models/prayer_name.dart';
import '../widgets/rafel_widgets.dart';

class AdjustmentsScreen extends StatelessWidget {
  const AdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerController>();
    final theme = RafelTheme.of(context);
    final day = controller.today;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: const Text('Prayer adjustments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          AnimatedOpacity(
            opacity: controller.settings.calculation.adjustments.isEmpty
                ? 0.3
                : 1.0,
            duration: RafelDurations.quick,
            child: TextButton(
              onPressed: controller.settings.calculation.adjustments.isEmpty
                  ? null
                  : () async {
                      await controller.resetAdjustments();
                      if (context.mounted) {
                        showRafelSnack(context, 'All adjustments reset.');
                      }
                    },
              child: const Text('Reset all'),
            ),
          ),
          const SizedBox(width: 8),
        ],
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
            'Move individual prayers to match your local mosque. Rpray keeps '
            'the calculated time and your adjustment separate.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: theme.surfaceVariant.withValues(alpha: 0.72),
                ),
          ),
          const SizedBox(height: RafelSpace.lg),
          for (final prayer in prayerOrder) ...<Widget>[
            _AdjustmentCard(
              prayer: prayer,
              calculated: day?.entries[prayer]?.calculated,
              adjusted: day?.entries[prayer]?.adjusted,
              minutes: controller.settings.calculation.adjustments
                  .forPrayer(prayer),
              onChanged: (value) =>
                  controller.setAdjustment(prayer, value),
            ),
            const SizedBox(height: RafelSpace.xs),
          ],
          const SizedBox(height: RafelSpace.sm),
          Text(
            'Adjustments are limited to ±60 minutes. A missed reminder is '
            'never moved to a later time.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: theme.surfaceVariant.withValues(alpha: 0.72),
                ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentCard extends StatelessWidget {
  const _AdjustmentCard({
    required this.prayer,
    required this.calculated,
    required this.adjusted,
    required this.minutes,
    required this.onChanged,
  });

  final PrayerName prayer;
  final DateTime? calculated;
  final DateTime? adjusted;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final hasAdjustment = minutes != 0;

    return RafelCard(
      padding: const EdgeInsets.fromLTRB(
        RafelSpace.md,
        RafelSpace.sm,
        RafelSpace.md,
        RafelSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Prayer name + times
          Row(
            children: <Widget>[
              PrayerIcon(
                prayer,
                size: 17,
                color: theme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: RafelSpace.sm),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      prayer.englishLabel,
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: theme.onSurface,
                              ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      prayer.arabicLabel,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 13,
                        color: theme.surfaceVariant.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              if (calculated != null) ...<Widget>[
                if (hasAdjustment) ...<Widget>[
                  Text(
                    formatTime(calculated!),
                    style: RafelType.tabular.copyWith(
                      fontFamily: 'IBMPlexSans',
                      fontSize: 12.5,
                      color: theme.surfaceVariant.withValues(alpha: 0.72),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                AnimatedSwitcher(
                  duration: RafelDurations.quick,
                  child: Text(
                    adjusted != null ? formatTime(adjusted!) : '--:--',
                    key: ValueKey<String>(
                      adjusted != null ? formatTime(adjusted!) : '',
                    ),
                    style: RafelType.tabular.copyWith(
                      fontFamily: 'IBMPlexSans',
                      fontSize: 15,
                      fontWeight:
                          hasAdjustment ? FontWeight.w600 : FontWeight.w400,
                      color: theme.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: RafelSpace.sm),

          // Slider
          Row(
            children: <Widget>[
              Text(
                '−60',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: theme.surfaceVariant.withValues(alpha: 0.72),
                    ),
              ),
              Expanded(
                child: Slider(
                  value: minutes.toDouble(),
                  min: -60,
                  max: 60,
                  divisions: 120,
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
              Text(
                '+60',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: theme.surfaceVariant.withValues(alpha: 0.72),
                    ),
              ),
            ],
          ),

          // Value + step buttons
          Row(
            children: <Widget>[
              _StepButton(
                icon: Icons.remove,
                onTap: minutes <= -60 ? null : () => onChanged(minutes - 1),
              ),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: RafelDurations.quick,
                    child: Text(
                      minutes == 0
                          ? 'No adjustment'
                          : '${minutes > 0 ? '+' : ''}$minutes min',
                      key: ValueKey<int>(minutes),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: hasAdjustment
                                ? theme.onSurface
                                : theme.surfaceVariant.withValues(alpha: 0.72),
                            fontWeight: hasAdjustment
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontFeatures: RafelType.tabular.fontFeatures,
                          ),
                    ),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onTap: minutes >= 60 ? null : () => onChanged(minutes + 1),
              ),
            ],
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
      color: theme.elevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 34,
          child: Icon(
            icon,
            size: 15,
            color: onTap == null
                ? theme.surfaceVariant.withValues(alpha: 0.72)
                : theme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
