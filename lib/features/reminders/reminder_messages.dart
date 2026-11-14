import '../../models/quote.dart';

const int maxReminderMessages = 30;
const int _maxLength = 220;

/// The quotes a reminder rotates through: at most [maxReminderMessages],
/// narrowed to the user's interests when that leaves any.
List<String> reminderMessages(List<Quote> quotes, Set<String> interests) {
  final preferred = interests.isEmpty
      ? quotes
      : quotes.where((quote) => interests.contains(quote.category)).toList();
  final source = preferred.isEmpty ? quotes : preferred;
  return [for (final quote in source.take(maxReminderMessages)) _format(quote)];
}

String _format(Quote quote) {
  final text = '"${quote.text}" - ${quote.author}';
  if (text.length <= _maxLength) return text;
  return '${text.substring(0, _maxLength - 3)}...';
}
