import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quote.dart';
import '../../repositories/quote_repository.dart';

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => AssetQuoteRepository(),
);

final allQuotesProvider = FutureProvider<List<Quote>>(
  (ref) => ref.watch(quoteRepositoryProvider).loadAll(),
);

/// The quote shown on Home. [next] picks a different one.
class FeaturedQuoteController extends AsyncNotifier<Quote> {
  final Random _random = Random();

  @override
  Future<Quote> build() async {
    final quotes = await ref.watch(allQuotesProvider.future);
    return _pick(quotes, excludeId: null);
  }

  Future<void> next() async {
    final quotes = await ref.read(allQuotesProvider.future);
    state = AsyncData(_pick(quotes, excludeId: state.value?.id));
  }

  Quote _pick(List<Quote> quotes, {required String? excludeId}) {
    if (quotes.isEmpty) throw StateError('No quotes available');
    if (quotes.length == 1) return quotes.first;
    Quote candidate;
    do {
      candidate = quotes[_random.nextInt(quotes.length)];
    } while (candidate.id == excludeId);
    return candidate;
  }
}

final featuredQuoteProvider =
    AsyncNotifierProvider<FeaturedQuoteController, Quote>(
  FeaturedQuoteController.new,
);
