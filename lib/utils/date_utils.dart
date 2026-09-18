const List<String> weekdayShortDe = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const List<String> weekdayLongDe = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];
const List<String> monthNamesDe = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday-first weekday index (Monday = 0 .. Sunday = 6).
int mondayIndex(DateTime d) => d.weekday - 1;

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String weekdayShortLabel(DateTime d) => weekdayShortDe[mondayIndex(d)];

/// "Heute, 18. August" or "Dienstag, 18. August".
String longDayLabel(DateTime d) {
  final today = dateOnly(DateTime.now());
  if (isSameDate(d, today))
    return 'Heute, ${d.day}. ${monthNamesDe[d.month - 1]}';
  return '${weekdayLongDe[mondayIndex(d)]}, ${d.day}. ${monthNamesDe[d.month - 1]}';
}

/// "Dienstag · 18. August 2026" — used for the home screen header.
String fullDateHeader(DateTime d) {
  return '${weekdayLongDe[mondayIndex(d)]} · ${d.day}. ${monthNamesDe[d.month - 1]} ${d.year}';
}

String monthYearLabel(DateTime d) => '${monthNamesDe[d.month - 1]} ${d.year}';

DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

String timeRange(String start, String end) => '$start–$end';

/// "2026-08-27" — the format Postgres `date` columns expect.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Combines a date-only [DateTime] with an "HH:mm" time string.
DateTime combineDateAndTime(DateTime date, String hhmm) {
  final parts = hhmm.split(':');
  return DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

String greetingForHour(int hour, String name) {
  final part = hour < 12
      ? 'Guten Morgen'
      : (hour < 18 ? 'Guten Tag' : 'Guten Abend');
  return '$part, $name';
}
