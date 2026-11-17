import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/prayer_controller.dart';
import '../../core/rafel_theme.dart';
import '../../models/islamic_event.dart';
import '../../services/audio_asset_service.dart';
import '../widgets/rafel_widgets.dart';

class OccasionSettingsScreen extends StatelessWidget {
  const OccasionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerController>();
    final theme = RafelTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: const Text('Occasion reminders'),
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
            'Each occasion uses its own recording. Disabled occasions are '
            'never scheduled, and each event key is scheduled only once.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: theme.surfaceVariant.withValues(alpha: 0.72),
                ),
          ),
          const SizedBox(height: RafelSpace.lg),
          for (final type in OccasionType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RafelCard(
                padding: EdgeInsets.zero,
                child: _OccasionTile(
                  type: type,
                  enabled: controller.settings.occasionEnabled(type),
                  onChanged: (value) =>
                      controller.setOccasionEnabled(type, value),
                ),
              ),
            ),
          const SizedBox(height: RafelSpace.sm),
          Text(
            'Ramadan has exactly one countdown, three days before the '
            'expected start. Confirmed or adjusted local dates are applied '
            'before reminders are generated.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: theme.surfaceVariant.withValues(alpha: 0.72),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _OccasionTile extends StatelessWidget {
  const _OccasionTile({
    required this.type,
    required this.enabled,
    required this.onChanged,
  });

  final OccasionType type;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<PrayerController>();
    final theme = RafelTheme.of(context);
    final asset = AudioAssetService.occasionPreviewAsset(type);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RafelSpace.md,
        10,
        RafelSpace.sm,
        10,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        type.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: theme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (type.supportsDateOverride) ...<Widget>[
                      const SizedBox(width: 6),
                      const RafelPill(label: 'Local date', compact: true),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  type.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: theme.surfaceVariant.withValues(alpha: 0.72),
                      ),
                ),
              ],
            ),
          ),
          if (asset != null)
            IconButton(
              tooltip: 'Preview sound',
              visualDensity: VisualDensity.compact,
              onPressed: () => controller.previewOccasion(type),
              icon: ValueListenableBuilder<String?>(
                valueListenable: controller.preview.playingAsset,
                builder: (context, playing, _) => Icon(
                  playing == asset
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                  size: 21,
                  color: theme.surfaceVariant.withValues(alpha: 0.72),
                ),
              ),
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
