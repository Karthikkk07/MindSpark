import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/user_prefs_controller.dart';
import '../../models/quote.dart';
import '../../repositories/favorites_repository.dart';
import '../quotes/quote_providers.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(sharedPreferencesProvider)),
);

/// Ids of the favourite quotes, newest first. Saved on every change.
class FavoritesController extends Notifier<List<String>> {
  @override
  List<String> build() => ref.watch(favoritesRepositoryProvider).load();

  Future<void> toggle(String quoteId) async {
    final next = [...state];
    if (!next.remove(quoteId)) next.insert(0, quoteId);
    state = next;
    await ref.read(favoritesRepositoryProvider).save(next);
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesController, List<String>>(
  FavoritesController.new,
);

/// The favourite quotes themselves, in the same order as the saved ids.
final favoriteQuotesProvider = Provider<AsyncValue<List<Quote>>>((ref) {
  final ids = ref.watch(favoritesProvider);
  return ref.watch(allQuotesProvider).whenData((all) {
    final byId = {for (final quote in all) quote.id: quote};
    return ids.map((id) => byId[id]).whereType<Quote>().toList();
  });
});
