import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/user_prefs_controller.dart';
import '../../core/telemetry/telemetry_service.dart';
import '../../models/quote.dart';
import '../../repositories/favorites_repository.dart';
import '../quotes/quote_providers.dart';
import '../sync/sync_controller.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(sharedPreferencesProvider)),
);

/// Ids of the favourite quotes, newest first. Saved on every change.
class FavoritesController extends Notifier<List<String>> {
  @override
  List<String> build() => ref.watch(favoritesRepositoryProvider).load();

  Future<void> toggle(String quoteId) async {
    final next = [...state];
    final added = !next.remove(quoteId);
    if (added) next.insert(0, quoteId);
    state = next;
    await ref.read(favoritesRepositoryProvider).save(next);
    if (added) unawaited(ref.read(telemetryServiceProvider).logEvent('favorite_added'));
    // Signed-in users: mirror the change to the account (queued if offline).
    unawaited(
      ref.read(syncControllerProvider.notifier).pushFavorite(quoteId, added: added),
    );
  }

  /// Replaces the list with the account's list. Used by sync; does not push.
  Future<void> replaceAll(List<String> ids) async {
    state = [...ids];
    await ref.read(favoritesRepositoryProvider).save(state);
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
