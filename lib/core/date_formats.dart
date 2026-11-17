import 'package:intl/intl.dart';

String twoDigits(int value) => value.toString().padLeft(2, '0');

String formatTime(DateTime time) => '${twoDigits(time.hour)}:${twoDigits(time.minute)}';

String formatTime12(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final suffix = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:${twoDigits(time.minute)} $suffix';
}

String formatGregorianDate(DateTime date) {
  try {
    return DateFormat('EEEE, d MMMM yyyy').format(date);
  } catch (_) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

String formatShortGregorianDate(DateTime date) =>
    '${date.day} ${DateFormat('MMM').format(date)} ${date.year}';

String formatWeekday(DateTime date) {
  try {
    return DateFormat('EEEE').format(date);
  } catch (_) {
    return '';
  }
}

String formatCountdown(Duration duration) {
  final total = duration.isNegative ? Duration.zero : duration;
  final hours = total.inHours;
  final minutes = total.inMinutes % 60;
  final seconds = total.inSeconds % 60;
  if (hours > 0) {
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
  return '${twoDigits(minutes)}:${twoDigits(seconds)}';
}

String formatCountdownLong(Duration duration) {
  final total = duration.isNegative ? Duration.zero : duration;
  final days = total.inDays;
  final hours = total.inHours % 24;
  final minutes = total.inMinutes % 60;
  if (days > 0) {
    return '$days d ${twoDigits(hours)} h ${twoDigits(minutes)} min';
  }
  if (hours > 0) return '$hours h ${twoDigits(minutes)} min';
  return '$minutes min';
}

String pluralize(int count, String singular, [String? plural]) =>
    count == 1 ? singular : (plural ?? '${singular}s');
