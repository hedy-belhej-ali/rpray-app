/// Islamic occasions supported by Rpray. Titles and messages are the exact
/// copy required by the product specification where it defines them.
enum OccasionType {
  ramadan(
    key: 'ramadan',
    label: 'Ramadan',
    arabicLabel: 'رمضان',
    description: 'One countdown, exactly three days before the expected start.',
    audioRaw: 'ramadhan_notifa',
    defaultEnabled: true,
  ),
  eidAlFitr(
    key: 'eid_fitr',
    label: 'Eid al-Fitr',
    arabicLabel: 'عيد الفطر',
    description: 'One notification, on the first day of Eid.',
    audioRaw: 'eid_fitr',
    defaultEnabled: true,
  ),
  eidAlAdha(
    key: 'eid_adha',
    label: 'Eid al-Adha',
    arabicLabel: 'عيد الأضحى',
    description: 'One notification, on the first day of Eid.',
    audioRaw: 'eid_adha',
    defaultEnabled: true,
  ),
  islamicNewYear(
    key: 'new_hijri_year',
    label: 'Islamic New Year',
    arabicLabel: 'رأس السنة الهجرية',
    description: 'The day before and the first day of Muharram.',
    audioRaw: 'new_hijri_year',
    defaultEnabled: true,
  ),
  ashura(
    key: 'ashura',
    label: 'Ashura',
    arabicLabel: 'عاشوراء',
    description: 'The day before and the 10th of Muharram.',
    audioRaw: 'tmrw_ashura',
    defaultEnabled: true,
  ),
  arafah(
    key: 'arafah',
    label: 'Day of Arafah',
    arabicLabel: 'يوم عرفة',
    description: 'The day before and the 9th of Dhul Hijjah.',
    audioRaw: 'tmr_arafa',
    defaultEnabled: true,
  ),
  mawlid(
    key: 'mawlid',
    label: 'Mawlid an-Nabi',
    arabicLabel: 'المولد النبوي',
    description: 'Optional: communities differ in how they observe this day.',
    audioRaw: 'mawlid_nabawi',
    defaultEnabled: false,
  ),
  whiteDays(
    key: 'white_days',
    label: 'White Days',
    arabicLabel: 'الأيام البيض',
    description: 'The 13th, 14th and 15th of every Hijri month.',
    audioRaw: 'notif_ayam_lbidh',
    defaultEnabled: true,
  ),
  lastTenNights(
    key: 'last_ten_nights',
    label: 'Last 10 Nights of Ramadan',
    arabicLabel: 'العشر الأواخر',
    description: 'A nightly reminder across the final ten nights.',
    audioRaw: 'ten_awakhr',
    defaultEnabled: true,
  ),
  laylatAlQadr(
    key: 'laylat_al_qadr',
    label: 'Laylat al-Qadr',
    arabicLabel: 'ليلة القدر',
    description: 'Reminders for the odd nights. The exact night is not known.',
    audioRaw: 'laylat_al_qadr',
    defaultEnabled: true,
  );

  const OccasionType({
    required this.key,
    required this.label,
    required this.arabicLabel,
    required this.description,
    this.audioRaw,
    required this.defaultEnabled,
  });

  final String key;
  final String label;
  final String arabicLabel;
  final String description;

  /// Android `res/raw` name, or null when the occasion uses the default sound.
  final String? audioRaw;
  final bool defaultEnabled;

  static OccasionType? fromKey(String? key) {
    for (final type in OccasionType.values) {
      if (type.key == key) return type;
    }
    return null;
  }

  bool get supportsDateOverride =>
      this == OccasionType.ramadan ||
      this == OccasionType.eidAlFitr ||
      this == OccasionType.eidAlAdha;
}

enum EventPhase {
  threeDaysBefore('three_days_before', 'In 3 days'),
  dayBefore('day_before', 'Tomorrow'),
  onDay('on_day', 'Today'),
  night('night', 'Tonight');

  const EventPhase(this.key, this.label);

  final String key;
  final String label;
}

/// The confidence level attached to every Islamic date.
enum EventDateStatus {
  estimated('estimated', 'Estimated', 'Based on the Umm al-Qura calendar.'),
  adjusted('adjusted', 'Adjusted', 'Adjusted for local moon sighting or offset.'),
  confirmed('confirmed', 'Confirmed', 'Confirmed by a local announcement.');

  const EventDateStatus(this.key, this.label, this.detail);

  final String key;
  final String label;
  final String detail;

  static EventDateStatus fromKey(String? key) {
    for (final status in EventDateStatus.values) {
      if (status.key == key) return status;
    }
    return EventDateStatus.estimated;
  }
}

/// A locally confirmed or adjusted primary date (Ramadan, Eid al-Fitr, Eid
/// al-Adha). Dates are stored as civil yyyy-mm-dd values, independent of the
/// device's current timezone.
class EventDateOverride {
  const EventDateOverride({
    required this.key,
    required this.date,
    required this.status,
    this.note,
  });

  final String key;
  final DateTime date;
  final EventDateStatus status;
  final String? note;

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'date': dateKey,
        'status': status.key,
        'note': note,
      };

  static EventDateOverride? fromJson(Object? value) {
    if (value is! Map) return null;
    final key = value['key'];
    final rawDate = value['date'];
    if (key is! String || rawDate is! String) return null;
    final parts = rawDate.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final status = EventDateStatus.fromKey(value['status'] as String?);
    if (status == EventDateStatus.estimated) return null;
    return EventDateOverride(
      key: key,
      date: DateTime.utc(year, month, day),
      status: status,
      note: value['note'] is String ? value['note'] as String : null,
    );
  }

  EventDateOverride copyWith({
    DateTime? date,
    EventDateStatus? status,
    String? note,
  }) {
    return EventDateOverride(
      key: key,
      date: date ?? this.date,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}

/// A primary date the user may confirm or adjust (expected 1 Ramadan, 1
/// Shawwal, or 10 Dhu al-Hijjah). Used by the occasions screen and stored in
/// [AppSettings.dateOverrides].
class PrimaryOccasionDate {
  const PrimaryOccasionDate({
    required this.type,
    required this.hijriYear,
    required this.date,
    required this.status,
    required this.overrideKey,
    required this.hijriLabel,
    required this.isOverridden,
  });

  final OccasionType type;
  final int hijriYear;

  /// Local midnight of the civil date in the selected location's timezone.
  final DateTime date;
  final EventDateStatus status;
  final String overrideKey;
  final String hijriLabel;
  final bool isOverridden;
}

/// One notification-ready Islamic event occurrence, already resolved to a
/// timezone-aware local date and time.
class IslamicEvent {
  const IslamicEvent({
    required this.key,
    required this.type,
    required this.phase,
    required this.date,
    required this.title,
    required this.message,
    required this.status,
    this.audioRaw,
    this.hijriYear,
    this.hijriLabel,
    this.primaryOverrideKey,
    this.dayNumber,
  });

  final String key;
  final OccasionType type;
  final EventPhase phase;
  final DateTime date;
  final String title;
  final String message;
  final EventDateStatus status;
  final String? audioRaw;
  final int? hijriYear;
  final String? hijriLabel;

  /// Set only on events that represent a primary date and can therefore be
  /// confirmed or adjusted by the user (e.g. `ramadan_1448`).
  final String? primaryOverrideKey;
  final int? dayNumber;

  bool get canBeOverridden =>
      primaryOverrideKey != null && type.supportsDateOverride;
}
