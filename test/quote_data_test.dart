import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/models/quote_category.dart';
import 'package:mindspark/repositories/quote_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled quotes are valid, unique and cover every category', () async {
    final quotes = await AssetQuoteRepository().loadAll();

    expect(quotes, isNotEmpty);
    expect(
      quotes.map((q) => q.id).toSet().length,
      quotes.length,
      reason: 'quote ids must be unique',
    );

    for (final quote in quotes) {
      expect(quote.text.trim(), isNotEmpty, reason: quote.id);
      expect(quote.author.trim(), isNotEmpty, reason: quote.id);
      expect(quote.license.trim(), isNotEmpty, reason: quote.id);
      expect(
        QuoteCategory.fromId(quote.category),
        isNotNull,
        reason: '${quote.id} has unknown category ${quote.category}',
      );
    }

    for (final category in QuoteCategory.values) {
      final count = quotes.where((q) => q.category == category.id).length;
      expect(
        count,
        greaterThanOrEqualTo(3),
        reason: '${category.id} needs at least 3 quotes',
      );
    }
  });
}
