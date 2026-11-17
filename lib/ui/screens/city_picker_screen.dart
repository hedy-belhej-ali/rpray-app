import 'package:material_ui/material_ui.dart';

import '../../core/rafel_theme.dart';
import '../../data/city_database.dart';
import '../../models/prayer_settings.dart';
import '../../services/timezone_service.dart';
import '../widgets/rafel_widgets.dart';

class LocationSelection {
  const LocationSelection({
    required this.location,
    this.suggestedMethod,
  });

  final GeoLocation location;
  final PrayerCalculationMethod? suggestedMethod;
}

class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key, this.current});

  final GeoLocation? current;

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final cities = searchCities(_query);
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: const Text('Choose a city'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RafelSpace.lg,
                0,
                RafelSpace.lg,
                RafelSpace.sm,
              ),
              child: TextField(
                controller: _search,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search city or country',
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.surfaceVariant.withValues(alpha: 0.72),
                    size: 20,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RafelSpace.lg,
                RafelSpace.xs,
                RafelSpace.lg,
                RafelSpace.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: RafelActionTile(
                      label: 'Enter coordinates',
                      icon: Icons.my_location,
                      onTap: () async {
                        final selection = await Navigator.of(context).push<
                            LocationSelection>(
                          MaterialPageRoute<LocationSelection>(
                            builder: (_) => CustomLocationScreen(
                              initialTimezone:
                                  widget.current?.timezoneId ?? 'UTC',
                            ),
                          ),
                        );
                        if (selection != null && context.mounted) {
                          Navigator.of(context).pop(selection);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const RafelDivider(indent: RafelSpace.lg),
            Expanded(
              child: cities.isEmpty
                  ? const RafelEmptyState(
                      icon: Icons.travel_explore,
                      title: 'No city found',
                      message:
                          'Try another spelling, or enter coordinates '
                          'directly.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        RafelSpace.lg,
                        RafelSpace.xs,
                        RafelSpace.lg,
                        RafelSpace.xl,
                      ),
                      itemCount: cities.length,
                      separatorBuilder: (_, _) => const RafelDivider(),
                      itemBuilder: (context, index) {
                        final city = cities[index];
                        final isCurrent = widget.current?.latitude ==
                                city.latitude &&
                            widget.current?.longitude == city.longitude;
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(
                            LocationSelection(
                              location: city.toLocation(),
                              suggestedMethod: city.suggestedMethod,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 14,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Flexible(
                                            child: Text(
                                              city.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                          ),
                                          if (city.arabicName != null) ...<
                                              Widget>[
                                            const SizedBox(width: 8),
                                            Text(
                                              city.arabicName!,
                                              style: RafelType.arabic(
                                                context,
                                                size: 13,
                                                color: theme.surfaceVariant.withValues(
                                                    alpha: 0.72),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${city.country} · '
                                        '${city.latitude.toStringAsFixed(2)}°, '
                                        '${city.longitude.toStringAsFixed(2)}°',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: theme.surfaceVariant.withValues(
                                                  alpha: 0.72),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCurrent)
                                  const RafelPill(
                                    label: 'Current',
                                    filled: true,
                                    compact: true,
                                  )
                                else
                                  Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: theme.surfaceVariant.withValues(
                                        alpha: 0.72),
                                  ),
                              ],
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
}

class CustomLocationScreen extends StatefulWidget {
  const CustomLocationScreen({
    super.key,
    required this.initialTimezone,
  });

  final String initialTimezone;

  @override
  State<CustomLocationScreen> createState() => _CustomLocationScreenState();
}

class _CustomLocationScreenState extends State<CustomLocationScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _latitude = TextEditingController();
  final TextEditingController _longitude = TextEditingController();
  late String _timezone = widget.initialTimezone;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _pickTimezone() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: RafelTheme.of(context).surface,
      builder: (_) => TimezonePickerSheet(selected: _timezone),
    );
    if (result != null) setState(() => _timezone = result);
  }

  void _save() {
    final latitude = double.tryParse(_latitude.text.trim().replaceAll(',', '.'));
    final longitude =
        double.tryParse(_longitude.text.trim().replaceAll(',', '.'));
    if (latitude == null || longitude == null) {
      setState(() => _error = 'Enter numeric latitude and longitude.');
      return;
    }
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      setState(() => _error =
          'Latitude must be between −90 and 90, longitude between −180 and 180.');
      return;
    }
    if (!TimezoneService.isValidTimezone(_timezone)) {
      setState(() => _error = 'Choose a valid IANA timezone.');
      return;
    }
    final name = _name.text.trim().isEmpty
        ? 'Custom location'
        : _name.text.trim();
    Navigator.of(context).pop(
      LocationSelection(
        location: GeoLocation(
          name: name,
          latitude: latitude,
          longitude: longitude,
          timezoneId: _timezone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: const Text('Coordinates'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            RafelSpace.lg,
            RafelSpace.xs,
            RafelSpace.lg,
            RafelSpace.xl,
          ),
          children: <Widget>[
            Text(
              'Rpray calculates from these exact coordinates. The timezone '
              'controls the civil date and clock, so it must match the place, '
              'not the device.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: theme.surfaceVariant.withValues(alpha: 0.72),
                  ),
            ),
            const SizedBox(height: RafelSpace.lg),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Place name (optional)',
                hintText: 'Custom location',
              ),
            ),
            const SizedBox(height: RafelSpace.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _latitude,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: '36.8065',
                    ),
                  ),
                ),
                const SizedBox(width: RafelSpace.sm),
                Expanded(
                  child: TextField(
                    controller: _longitude,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: '10.1815',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RafelSpace.sm),
            InkWell(
              onTap: _pickTimezone,
              borderRadius: BorderRadius.circular(RafelRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RafelSpace.md,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(RafelRadius.md),
                  border: Border.all(color: theme.outline),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.public,
                      size: 18,
                      color: theme.surfaceVariant.withValues(alpha: 0.72),
                    ),
                    const SizedBox(width: RafelSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Timezone',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: theme.surfaceVariant.withValues(alpha: 0.72)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            TimezoneService.timezoneLabel(_timezone),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.surfaceVariant.withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: RafelSpace.sm),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: theme.onSurface,
                    ),
              ),
            ],
            const SizedBox(height: RafelSpace.lg),
            FilledButton(onPressed: _save, child: const Text('Use this place')),
          ],
        ),
      ),
    );
  }
}

class TimezonePickerSheet extends StatefulWidget {
  const TimezonePickerSheet({super.key, required this.selected});

  final String selected;

  @override
  State<TimezonePickerSheet> createState() => _TimezonePickerSheetState();
}

class _TimezonePickerSheetState extends State<TimezonePickerSheet> {
  late final List<String> _all = TimezoneService.availableTimezones;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = RafelTheme.of(context);
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? _all
        : _all.where((name) => name.toLowerCase().contains(query)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: <Widget>[
          const RafelSheetHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RafelSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Timezone',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: theme.onSurface,
                      ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search IANA timezone',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RafelSpace.sm),
          Expanded(
            child: ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final name = matches[index];
                final isSelected = name == widget.selected;
                return ListTile(
                  dense: true,
                  onTap: () => Navigator.of(context).pop(name),
                  title: Text(
                    name,
                    style: TextStyle(
                      color: isSelected ? theme.onSurface : theme.surfaceVariant.withValues(alpha: 0.72),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, size: 18)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
