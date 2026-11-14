import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/prefs/user_prefs_controller.dart';
import '../../models/quote.dart';
import '../../repositories/quote_repository.dart';
import 'quote_pool.dart';

/// Quotes from the API, saved on the device, with the bundled quotes as the
/// starting point and the offline fallback.
final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => ApiQuoteRepository(
    api: ref.watch(apiClientProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    fallback: AssetQuoteRepository(),
  ),
);

final allQuotesProvider = FutureProvider<List<Quote>>(
  (ref) => ref.watch(quoteRepositoryProvider).loadAll(),
);

/// Downloads the latest quotes once at start-up and shows them if they changed.
final quoteRefreshProvider = Provider<void>((ref) {
  final repo = ref.watch(quoteRepositoryProvider);
  unawaited(
    repo.refreshIfSupported().then((result) {
      if (result == QuoteRefresh.updated && ref.mounted) {
        ref.invalidate(allQuotesProvider);
      }
    }),
  );
});

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

  List<Quote> _pool(List<Quote> all) =>
      quotesForInterests(all, ref.read(userPrefsProvider).interests);

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
