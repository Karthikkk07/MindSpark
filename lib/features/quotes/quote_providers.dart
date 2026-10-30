import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/user_prefs_controller.dart';
import '../../models/quote.dart';
import '../../repositories/quote_repository.dart';

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => AssetQuoteRepository(),
);

final allQuotesProvider = FutureProvider<List<Quote>>(
  (ref) => ref.watch(quoteRepositoryProvider).loadAll(),
);

/// The quote shown on Home, favouring the user's interests.
/// [next] picks a different one.
class FeaturedQuoteController extends AsyncNotifier<Quote> {
  final Random _random = Random();

  @override
  Future<Quote> build() async {
    // Pick a fresh quote whenever the user's interests change.
    ref.watch(userPrefsProvider.select((prefs) => prefs.interests));
    final quotes = await ref.watch(allQuotesProvider.future);
    return _pick(_pool(quotes), excludeId: null);
  }

  Future<void> next() async {
    final quotes = await ref.read(allQuotesProvider.future);
    state = AsyncData(_pick(_pool(quotes), excludeId: state.value?.id));
  }

  /// Quotes in the user's interests, or all quotes if none match.
  List<Quote> _pool(List<Quote> all) {
    final interests = ref.read(userPrefsProvider).interests;
    if (interests.isEmpty) return all;
    final filtered =
        all.where((quote) => interests.contains(quote.category)).toList();
    return filtered.isEmpty ? all : filtered;
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
