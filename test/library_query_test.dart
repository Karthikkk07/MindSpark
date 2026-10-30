import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/features/quotes/library_query.dart';
import 'package:mindspark/models/quote.dart';

Quote _q(
  String id,
  String text, {
  String author = 'Ann',
  String category = 'study',
  List<String> tags = const [],
}) {
  return Quote(
    id: id,
    text: text,
    author: author,
    category: category,
    tags: tags,
    source: 's',
    license: 'l',
  );
}

final _all = [
  _q('1', 'Zebra study note.', tags: ['Focus']),
  _q('2', 'Apple coding note.',
      author: 'Bob', category: 'coding', tags: ['debugging']),
  _q('3', 'Mango coding thought that is long.',
      author: 'Cy', category: 'coding', tags: ['craft']),
];

List<String> _ids(List<Quote> quotes) => quotes.map((q) => q.id).toList();

void main() {
  test('an empty query returns everything in the original order', () {
    expect(_ids(applyLibraryQuery(_all, const LibraryQuery())), ['1', '2', '3']);
  });

  test('search matches text ignoring case', () {
    final result = applyLibraryQuery(_all, const LibraryQuery(search: 'APPLE'));
    expect(_ids(result), ['2']);
  });

  test('search matches the author', () {
    final result = applyLibraryQuery(_all, const LibraryQuery(search: 'bob'));
    expect(_ids(result), ['2']);
  });

  test('search matches tags ignoring case', () {
    final result = applyLibraryQuery(_all, const LibraryQuery(search: 'focus'));
    expect(_ids(result), ['1']);
  });

  test('search ignores surrounding spaces', () {
    final result =
        applyLibraryQuery(_all, const LibraryQuery(search: '  mango '));
    expect(_ids(result), ['3']);
  });

  test('category filter keeps only that category', () {
    final result =
        applyLibraryQuery(_all, const LibraryQuery(categoryId: 'coding'));
    expect(_ids(result), ['2', '3']);
  });

  test('search and category combine', () {
    final result = applyLibraryQuery(
      _all,
      const LibraryQuery(search: 'note', categoryId: 'coding'),
    );
    expect(_ids(result), ['2']);
  });

  test('no match returns an empty list', () {
    final result = applyLibraryQuery(_all, const LibraryQuery(search: 'zzzz'));
    expect(result, isEmpty);
  });

  test('A to Z sorts by text', () {
    final result = applyLibraryQuery(
      _all,
      const LibraryQuery(sort: LibrarySort.alphabetical),
    );
    expect(_ids(result), ['2', '3', '1']);
  });

  test('shortest first sorts by length', () {
    final result = applyLibraryQuery(
      _all.reversed.toList(),
      const LibraryQuery(sort: LibrarySort.shortest),
    );
    expect(_ids(result), ['1', '2', '3']);
  });

  test('isFiltered reflects search and category only', () {
    expect(const LibraryQuery().isFiltered, isFalse);
    expect(const LibraryQuery(search: '   ').isFiltered, isFalse);
    expect(const LibraryQuery(search: 'a').isFiltered, isTrue);
    expect(const LibraryQuery(categoryId: 'study').isFiltered, isTrue);
    expect(const LibraryQuery(sort: LibrarySort.shortest).isFiltered, isFalse);
  });
}
