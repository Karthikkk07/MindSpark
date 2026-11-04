import '../../models/quote.dart';

/// Quotes in the given interests, or all quotes when none are chosen
/// or none match.
List<Quote> quotesForInterests(List<Quote> all, Set<String> interests) {
  if (interests.isEmpty) return all;
  final filtered =
      all.where((quote) => interests.contains(quote.category)).toList();
  return filtered.isEmpty ? all : filtered;
}
