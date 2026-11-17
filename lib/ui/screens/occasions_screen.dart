import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../controllers/prayer_controller.dart';
import '../../core/date_formats.dart';
import '../../core/rafel_theme.dart';
import '../../models/islamic_event.dart';
import '../../services/audio_asset_service.dart';
import '../widgets/rafel_widgets.dart';

class OccasionsScreen extends StatelessWidget {
  const OccasionsScreen({super.key});

  static final _monthYearFormat = DateFormat('MMMM yyyy');

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerController>();
    final theme = RafelTheme.of(context);
    final primary = controller.primaryDates;
    final events = controller.occasions;
    final groups = <String, List<IslamicEvent>>{};
    for (final event in events) {
      final key = _monthYearFormat.format(event.date);
      groups.putIfAbsent(key, () => <IslamicEvent>[]).add(event);
    }

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            RafelSpace.lg,
            RafelSpace.md,
            RafelSpace.lg,
            RafelSpace.xxl,
          ),
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Occasions',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: theme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hijri dates, kept honest.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: theme.surfaceVariant.withValues(alpha: 0.72),
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Occasion preferences',
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    useSafeArea: true,
                    isScrollControlled: true,
                    backgroundColor: theme.surface,
                    builder: (_) => const _OccasionPreferencesSheet(),
                  ),
                  icon: const Icon(Icons.tune, size: 20),
                ),
              ],
            ),
          const SizedBox(height: RafelSpace.lg),
          RafelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.auto_awesome_outlined, size: 18),
                    const SizedBox(width: RafelSpace.xs),
                    Expanded(
                      child: Text(
                        'Hijri dates may vary by local moon sighting',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: theme.onSurface,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RafelSpace.xs),
                Text(
                  'Rpray starts with Umm al-Qura estimates. When your local '
                  'community confirms a date, update it here and all related '
                  'reminders will follow.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: theme.surfaceVariant.withValues(alpha: 0.72),
                        height: 1.55,
                      ),
                ),
                const SizedBox(height: RafelSpace.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: const <Widget>[
                    RafelStatusPill(EventDateStatus.estimated, compact: true),
                    RafelStatusPill(EventDateStatus.adjusted, compact: true),
                    RafelStatusPill(EventDateStatus.confirmed, compact: true),
                  ],
                ),
              ],
            ),
          ),
          if (primary.isNotEmpty) ...<Widget>[
            const SizedBox(height: RafelSpace.xl),
            const RafelSectionLabel('Primary dates'),
            for (final date in primary.take(6)) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: RafelSpace.xs),
                child: _PrimaryDateCard(date: date),
              ),
            ],
          ],
          const SizedBox(height: RafelSpace.xl),
          const RafelSectionLabel('Next twelve months'),
          if (groups.isEmpty)
            RafelEmptyState(
              icon: Icons.nights_stay_outlined,
              title: 'No occasions in this window',
              message:
                  'Choose a location to resolve local Hijri dates, or '
                  'enable occasions in preferences.',
            )
          else
            for (final entry in groups.entries) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(
                  top: RafelSpace.sm,
                  bottom: RafelSpace.xs,
                ),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: theme.surfaceVariant.withValues(alpha: 0.72),
                      ),
                ),
              ),
              RafelCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (var i = 0; i < entry.value.length; i++) ...<Widget>[
                      _OccasionRow(
                        event: entry.value[i],
                        onTap: () => _showOccasion(
                          context,
                          entry.value[i],
                        ),
                      ),
                      if (i < entry.value.length - 1)
                        const RafelDivider(indent: 68),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showOccasion(
    BuildContext context,
    IslamicEvent event,
  ) async {
    final controller = context.read<PrayerController>();
    final theme = RafelTheme.of(context);
    PrimaryOccasionDate? primary;
    if (event.canBeOverridden && event.primaryOverrideKey != null) {
      for (final date in controller.primaryDates) {
        if (date.overrideKey == event.primaryOverrideKey) {
          primary = date;
          break;
        }
      }
    }
    if (primary == null) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        backgroundColor: theme.surface,
        builder: (bottomSheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(
            RafelSpace.lg,
            0,
            RafelSpace.lg,
            MediaQuery.viewPaddingOf(bottomSheetContext).bottom + RafelSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const RafelSheetHandle(),
              RafelSheetTitle(
                title: event.title,
                subtitle: formatGregorianDate(event.date),
                trailing: RafelStatusPill(event.status, compact: true),
              ),
              const SizedBox(height: RafelSpace.md),
              Text(
                event.message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: theme.onSurface.withValues(alpha: 0.65),
                    ),
              ),
              if (event.hijriLabel != null) ...<Widget>[
                const SizedBox(height: RafelSpace.md),
                Text(
                  event.hijriLabel!,
                  style: RafelType.arabic(
                    context,
                    size: 16,
                    color: theme.surfaceVariant.withValues(alpha: 0.72),
                    height: 1.2,
                  ),
                ),
              ],
              const SizedBox(height: RafelSpace.lg),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
      return;
    }
    await showEventDateEditor(context, primary);
  }
}

class _PrimaryDateCard extends StatelessWidget {
  const _PrimaryDateCard({required this.date});

  final PrimaryOccasionDate date;
  static final _monthFormat = DateFormat('MMM');

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final textTheme = Theme.of(context).textTheme;

    return RafelCard(
      onTap: () => showEventDateEditor(context, date),
      padding: const EdgeInsets.all(RafelSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RafelRadius.sm),
              border: Border.all(color: theme.outline),
              color: theme.elevated,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${date.date.day}',
                  textAlign: TextAlign.center,
                  style: RafelType.tabular.copyWith(
                    fontFamily: 'IBMPlexSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.onSurface,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _monthFormat.format(date.date),
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(
                    color: theme.surfaceVariant.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: RafelSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  date.type.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: theme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatGregorianDate(date.date)}'
                  '${date.isOverridden ? ' · local' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: theme.surfaceVariant.withValues(alpha: 0.72),
                  ),
                ),
                if (date.hijriLabel.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    date.hijriLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RafelType.arabic(
                      context,
                      size: 14,
                      color: theme.surfaceVariant.withValues(alpha: 0.85),
                      height: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: RafelSpace.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RafelStatusPill(date.status, compact: true),
                ),
              ],
            ),
          ),
          const SizedBox(width: RafelSpace.xs),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: theme.surfaceVariant.withValues(alpha: 0.65),
          ),
        ],
      ),
    );
  }
}

class _OccasionRow extends StatelessWidget {
  const _OccasionRow({required this.event, required this.onTap});

  final IslamicEvent event;
  final VoidCallback onTap;

  static final _dayNameFormat = DateFormat('EEE');

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final date = event.date;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RafelSpace.md,
          vertical: 12,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${date.day}',
                    style: RafelType.tabular.copyWith(
                      fontFamily: 'IBMPlexSans',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: theme.onSurface.withValues(alpha: 0.85),
                      height: 1.1,
                    ),
                  ),
                  Text(
                    _dayNameFormat.format(date),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: theme.surfaceVariant.withValues(alpha: 0.72),
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: RafelSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.onSurface,
                        ),
                  ),
                  if (event.hijriLabel != null && event.hijriLabel!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      event.hijriLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RafelType.arabic(
                        context,
                        size: 13,
                        color: theme.surfaceVariant.withValues(alpha: 0.72),
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (event.status != EventDateStatus.estimated) ...<Widget>[
              const SizedBox(width: RafelSpace.xs),
              RafelPill(
                label: event.status.label,
                icon: event.status == EventDateStatus.confirmed
                    ? Icons.check
                    : Icons.tune,
                compact: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OccasionPreferencesSheet extends StatelessWidget {
  const _OccasionPreferencesSheet();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PrayerController>();
    final theme = RafelTheme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          RafelSpace.lg,
          0,
          RafelSpace.lg,
          MediaQuery.viewPaddingOf(context).bottom + RafelSpace.xl,
        ),
        children: <Widget>[
          const RafelSheetHandle(),
          const RafelSheetTitle(
            title: 'Occasion reminders',
            subtitle:
                'Every occasion uses its own voice recording. Disabled '
                'occasions are never scheduled.',
          ),
          const SizedBox(height: RafelSpace.lg),
          for (final type in OccasionType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RafelCard(
                padding: EdgeInsets.zero,
                child: _OccasionPrefRow(
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
            'expected start.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: theme.surfaceVariant.withValues(alpha: 0.72),
                ),
          ),
        ],
      ),
    );
  }
}

class _OccasionPrefRow extends StatelessWidget {
  const _OccasionPrefRow({
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
                Text(
                  type.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: theme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
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
                  color: theme.onSurface.withValues(alpha: 0.6),
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

Future<void> showEventDateEditor(
  BuildContext context,
  PrimaryOccasionDate primary,
) async {
  final controller = context.read<PrayerController>();
  final theme = RafelTheme.of(context);
  var selected = DateTime(
    primary.date.year,
    primary.date.month,
    primary.date.day,
  );
  var status = primary.status == EventDateStatus.estimated
      ? EventDateStatus.confirmed
      : primary.status;

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: theme.surface,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            RafelSpace.lg,
            0,
            RafelSpace.lg,
            MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.viewPaddingOf(sheetContext).bottom +
                RafelSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const RafelSheetHandle(),
              RafelSheetTitle(
                title: primary.type.label,
                subtitle:
                    'Set the date your community has confirmed. This is '
                    'stored only on this device.',
                trailing: RafelStatusPill(primary.status, compact: true),
              ),
              const SizedBox(height: RafelSpace.lg),
              RafelCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    RafelSettingRow(
                      leading: Icons.event_outlined,
                      title: 'Local date',
                      subtitle: formatGregorianDate(selected),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selected,
                          firstDate: DateTime(controller.now.year - 1),
                          lastDate: DateTime(controller.now.year + 2, 12, 31),
                          helpText: 'Select the local date',
                        );
                        if (picked != null) {
                          setState(() => selected = picked);
                        }
                      },
                    ),
                    const RafelDivider(indent: 66),
                    RafelSettingRow(
                      leading: Icons.verified_outlined,
                      title: 'Status',
                      subtitle: status.detail,
                      trailing: RafelPill(
                        label: status.label,
                        compact: true,
                      ),
                      onTap: () {
                        setState(() {
                          status = status == EventDateStatus.confirmed
                              ? EventDateStatus.adjusted
                              : EventDateStatus.confirmed;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RafelSpace.sm),
              Text(
                'Confirmed means a local announcement has fixed this date. '
                'Adjusted means you have moved the estimate yourself. Either '
                'way, Rpray recalculates every dependent reminder.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: theme.surfaceVariant.withValues(alpha: 0.72),
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: RafelSpace.lg),
              FilledButton(
                onPressed: () async {
                  await controller.setOverride(
                    EventDateOverride(
                      key: primary.overrideKey,
                      date: DateTime.utc(
                        selected.year,
                        selected.month,
                        selected.day,
                      ),
                      status: status == EventDateStatus.confirmed
                          ? EventDateStatus.confirmed
                          : EventDateStatus.adjusted,
                    ),
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    showRafelSnack(
                      context,
                      '${primary.type.label} set to '
                      '${formatShortGregorianDate(selected)}.',
                    );
                  }
                },
                child: const Text('Save local date'),
              ),
              if (primary.isOverridden) ...<Widget>[
                const SizedBox(height: RafelSpace.xs),
                TextButton(
                  onPressed: () async {
                    await controller.clearOverride(primary.overrideKey);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      showRafelSnack(
                        context,
                        '${primary.type.label} returned to the estimate.',
                      );
                    }
                  },
                  child: const Text('Reset to estimate'),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
