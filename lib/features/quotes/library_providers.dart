import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quote.dart';
import 'library_query.dart';
import 'quote_providers.dart';

class LibraryQueryController extends Notifier<LibraryQuery> {
  @override
  LibraryQuery build() => const LibraryQuery();

  void setSearch(String value) => state = state.copyWith(search: value);

  void setCategory(String? id) =>
      state = state.copyWith(categoryId: id, clearCategory: id == null);

  void setSort(LibrarySort sort) => state = state.copyWith(sort: sort);

  void clear() => state = state.copyWith(search: '', clearCategory: true);
}

final libraryQueryProvider =
    NotifierProvider<LibraryQueryController, LibraryQuery>(
  LibraryQueryController.new,
);

/// The quotes matching the current Library search, filter and sort.
final libraryResultsProvider = Provider<AsyncValue<List<Quote>>>((ref) {
  final query = ref.watch(libraryQueryProvider);
  return ref
      .watch(allQuotesProvider)
      .whenData((all) => applyLibraryQuery(all, query));
});
