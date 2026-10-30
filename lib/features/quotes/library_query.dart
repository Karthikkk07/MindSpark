import '../../models/quote.dart';

enum LibrarySort {
  curated('Curated'),
  alphabetical('A to Z'),
  shortest('Shortest first');

  const LibrarySort(this.label);

  final String label;
}

/// What the user has typed and chosen on the Library screen.
class LibraryQuery {
  const LibraryQuery({
    this.search = '',
    this.categoryId,
    this.sort = LibrarySort.curated,
  });

  final String search;
  final String? categoryId;
  final LibrarySort sort;

  bool get isFiltered => search.trim().isNotEmpty || categoryId != null;

  LibraryQuery copyWith({
    String? search,
    String? categoryId,
    bool clearCategory = false,
    LibrarySort? sort,
  }) {
    return LibraryQuery(
      search: search ?? this.search,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      sort: sort ?? this.sort,
    );
  }
}

/// Filters by category and search text (text, author, tags), then sorts.
List<Quote> applyLibraryQuery(List<Quote> all, LibraryQuery query) {
  final needle = query.search.trim().toLowerCase();

  final result = all.where((quote) {
    if (query.categoryId != null && quote.category != query.categoryId) {
      return false;
    }
    if (needle.isEmpty) return true;
    return quote.text.toLowerCase().contains(needle) ||
        quote.author.toLowerCase().contains(needle) ||
        quote.tags.any((tag) => tag.toLowerCase().contains(needle));
  }).toList();

  switch (query.sort) {
    case LibrarySort.curated:
      break;
    case LibrarySort.alphabetical:
      result.sort((a, b) {
        final byText = a.text.toLowerCase().compareTo(b.text.toLowerCase());
        return byText != 0 ? byText : a.id.compareTo(b.id);
      });
    case LibrarySort.shortest:
      result.sort((a, b) {
        final byLength = a.text.length.compareTo(b.text.length);
        return byLength != 0 ? byLength : a.id.compareTo(b.id);
      });
  }
  return result;
}
