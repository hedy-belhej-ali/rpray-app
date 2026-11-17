import 'package:material_ui/material_ui.dart';

import '../../core/rafel_theme.dart';
import '../../models/prayer_settings.dart';
import '../widgets/rafel_widgets.dart';

Future<T?> showRafelChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<RafelChoice<T>> choices,
  required T selected,
}) {
  final theme = RafelTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: theme.surface,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.94,
      builder: (context, scrollController) => Column(
        children: <Widget>[
          const RafelSheetHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RafelSpace.lg),
            child: RafelSheetTitle(title: title, subtitle: subtitle),
          ),
          const SizedBox(height: RafelSpace.md),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                RafelSpace.lg,
                0,
                RafelSpace.lg,
                RafelSpace.xl,
              ),
              itemCount: choices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final choice = choices[index];
                final isSelected = choice.value == selected;
                return Material(
                  color: isSelected ? theme.activeAt(0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(RafelRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(RafelRadius.md),
                    onTap: () => Navigator.of(context).pop(choice.value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: RafelSpace.md,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(RafelRadius.md),
                        border: Border.all(
                          color: isSelected
                              ? theme.active
                              : theme.outline,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  choice.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: theme.onSurface,
                                      ),
                                ),
                                if (choice.detail != null) ...<Widget>[
                                  const SizedBox(height: 3),
                                  Text(
                                    choice.detail!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: theme.surfaceVariant.withValues(
                                              alpha: 0.72),
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: RafelSpace.sm),
                          AnimatedContainer(
                            duration: RafelDurations.quick,
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? theme.active : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? theme.active
                                    : theme.outline,
                              ),
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 14,
                                    color: theme.background,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class RafelChoice<T> {
  const RafelChoice({
    required this.value,
    required this.label,
    this.detail,
  });

  final T value;
  final String label;
  final String? detail;
}

Future<PrayerCalculationMethod?> showMethodSheet(
  BuildContext context,
  PrayerCalculationMethod selected,
) {
  return showRafelChoiceSheet<PrayerCalculationMethod>(
    context: context,
    title: 'Calculation method',
    subtitle:
        'Angles differ by authority. Rpray never hides which convention is '
        'being used.',
    selected: selected,
    choices: <RafelChoice<PrayerCalculationMethod>>[
      for (final method in PrayerCalculationMethod.values)
        RafelChoice<PrayerCalculationMethod>(
          value: method,
          label: method.label,
          detail: method.detail,
        ),
    ],
  );
}

Future<AsrMadhab?> showMadhabSheet(
  BuildContext context,
  AsrMadhab selected,
) {
  return showRafelChoiceSheet<AsrMadhab>(
    context: context,
    title: 'Asr calculation',
    subtitle: 'The school of law changes the shadow length used for Asr.',
    selected: selected,
    choices: const <RafelChoice<AsrMadhab>>[
      RafelChoice<AsrMadhab>(
        value: AsrMadhab.standard,
        label: "Standard (Shafi'i, Maliki, Hanbali)",
        detail: 'Shadow length equal to the object plus its noon shadow.',
      ),
      RafelChoice<AsrMadhab>(
        value: AsrMadhab.hanafi,
        label: 'Hanafi',
        detail: 'Shadow length twice the object plus its noon shadow.',
      ),
    ],
  );
}

Future<HighLatitudeMethod?> showHighLatitudeSheet(
  BuildContext context,
  HighLatitudeMethod selected,
) {
  return showRafelChoiceSheet<HighLatitudeMethod>(
    context: context,
    title: 'High-latitude rule',
    subtitle:
        'Above roughly 48°, twilight can last all night. This rule keeps Fajr '
        'and Isha within the night.',
    selected: selected,
    choices: <RafelChoice<HighLatitudeMethod>>[
      for (final method in HighLatitudeMethod.values)
        RafelChoice<HighLatitudeMethod>(
          value: method,
          label: method.label,
          detail: method.detail,
        ),
    ],
  );
}

Future<int?> showHijriOffsetSheet(BuildContext context, int selected) {
  return showRafelChoiceSheet<int>(
    context: context,
    title: 'Hijri date offset',
    subtitle:
        'Move the entire Hijri calendar by up to two days to match local '
        'sighting. This is independent from prayer calculation.',
    selected: selected,
    choices: const <RafelChoice<int>>[
      RafelChoice<int>(
        value: -2,
        label: 'Two days earlier',
        detail: '−2 days',
      ),
      RafelChoice<int>(value: -1, label: 'One day earlier', detail: '−1 day'),
      RafelChoice<int>(
        value: 0,
        label: 'No offset',
        detail: 'Umm al-Qura estimate',
      ),
      RafelChoice<int>(value: 1, label: 'One day later', detail: '+1 day'),
      RafelChoice<int>(
        value: 2,
        label: 'Two days later',
        detail: '+2 days',
      ),
    ],
  );
}
