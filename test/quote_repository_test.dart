import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindspark/core/network/api_client.dart';
import 'package:mindspark/models/quote.dart';
import 'package:mindspark/repositories/quote_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object> _quote(String id, String text) => {
      'id': id,
      'text': text,
      'author': 'MindSpark',
      'category': 'study',
      'tags': ['t'],
      'source': 's',
      'license': 'l',
    };

class _Bundled implements QuoteRepository {
  @override
  Future<List<Quote>> loadAll() async => [Quote.fromJson(_quote('b1', 'Bundled'))];
}

Future<ApiQuoteRepository> _repo(
  Future<http.Response> Function(http.Request request) handler, {
  Map<String, Object> prefsValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  return ApiQuoteRepository(
    api: ApiClient(client: MockClient(handler), baseUrl: 'http://test/api'),
    prefs: prefs,
    fallback: _Bundled(),
  );
}

http.Response _page(List<Map<String, Object>> quotes, {int page = 1, int totalPages = 1}) =>
    http.Response(
      jsonEncode({'data': quotes, 'page': page, 'totalPages': totalPages}),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('API quote repository', () {
    test('starts from the bundled quotes and never waits for the network', () async {
      var calls = 0;
      final repo = await _repo((_) async {
        calls++;
        return _page([]);
      });
      final quotes = await repo.loadAll();
      expect(quotes.single.id, 'b1');
      expect(calls, 0);
    });

    test('refresh saves the server list, which loadAll then returns', () async {
      final repo = await _repo((_) async => _page([_quote('s1', 'From server')]));

      expect(await repo.refresh(), QuoteRefresh.updated);
      expect((await repo.loadAll()).single.text, 'From server');
      expect(await repo.refresh(), QuoteRefresh.unchanged);
    });

    test('reads every page', () async {
      final seen = <String>[];
      final repo = await _repo((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        seen.add('$page');
        return _page([_quote('s$page', 'Quote $page')], page: page, totalPages: 2);
      });

      await repo.refresh();
      expect(seen, ['1', '2']);
      expect((await repo.loadAll()).map((q) => q.id), ['s1', 's2']);
    });

    test('a failed refresh keeps the saved quotes', () async {
      final saved = jsonEncode([_quote('c1', 'Saved copy')]);
      for (final handler in <Future<http.Response> Function(http.Request)>[
        (_) async => http.Response('boom', 500),
        (_) async => throw http.ClientException('offline'),
        (_) async => http.Response('not json', 200),
        (_) async => _page([]),
      ]) {
        final repo = await _repo(handler, prefsValues: {ApiQuoteRepository.cacheKey: saved});
        expect(await repo.refresh(), QuoteRefresh.failed);
        expect((await repo.loadAll()).single.text, 'Saved copy');
      }
    });

    test('a damaged saved copy falls back to the bundled quotes', () async {
      final repo = await _repo(
        (_) async => _page([]),
        prefsValues: {ApiQuoteRepository.cacheKey: '{broken'},
      );
      expect((await repo.loadAll()).single.id, 'b1');
    });
  });
}
