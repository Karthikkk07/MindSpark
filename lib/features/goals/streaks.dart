// Calendar-date helpers and streak maths.
//
// Dates are YYYY-MM-DD strings in the user's own time zone, so streaks do
// not depend on UTC offsets or daylight saving.

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// The YYYY-MM-DD key for a date, using its own calendar fields.
String dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// The calendar date for a valid key (as a UTC DateTime), or null.
DateTime? parseDateKey(String value) {
  if (!_datePattern.hasMatch(value)) return null;
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  if (year < 1000) return null;
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Whole days since 1970-01-01 for a valid key, or null.
int? dayNumber(String value) {
  final date = parseDateKey(value);
  if (date == null) return null;
  return date.difference(DateTime.utc(1970)).inDays;
}

/// The key [days] days after [key] (negative for earlier days).
String addDays(String key, int days) {
  final date = parseDateKey(key);
  if (date == null) return key;
  return dateKey(date.add(Duration(days: days)));
}

/// For example "31 Jan 2027". Returns the key itself if it is not valid.
String formatDateKey(String key) {
  final date = parseDateKey(key);
  if (date == null) return key;
  return '${date.day} ${_monthNames[date.month - 1]} ${date.year}';
}

class Streaks {
  const Streaks({required this.current, required this.longest});

  final int current;
  final int longest;
}

/// Streaks from check-in dates. The current streak stays alive until the end
/// of the day after the last check-in.
Streaks computeStreaks(Iterable<String> checkIns, String today) {
  final days = checkIns.map(dayNumber).whereType<int>().toSet().toList()..sort();
  if (days.isEmpty) return const Streaks(current: 0, longest: 0);

  var longest = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    run = days[i] == days[i - 1] + 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }

  final todayNumber = dayNumber(today);
  if (todayNumber == null) return Streaks(current: 0, longest: longest);
  final upToToday = days.where((day) => day <= todayNumber).toList();
  if (upToToday.isEmpty) return Streaks(current: 0, longest: longest);
  if (todayNumber - upToToday.last > 1) {
    return Streaks(current: 0, longest: longest);
  }

  var current = 1;
  for (var i = upToToday.length - 2;
      i >= 0 && upToToday[i] == upToToday[i + 1] - 1;
      i--) {
    current++;
  }
  return Streaks(current: current, longest: longest);
}
