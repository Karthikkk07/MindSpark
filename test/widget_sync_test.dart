import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/core/platform/widget_service.dart';
import 'package:mindspark/core/prefs/user_prefs_controller.dart';
import 'package:mindspark/features/quotes/quote_pool.dart';
import 'package:mindspark/features/quotes/quote_providers.dart';
import 'package:mindspark/features/widget/widget_sync.dart';
import 'package:mindspark/models/quote.dart';
import 'package:mindspark/repositories/prefs_repository.dart';
import 'package:mindspark/repositories/quote_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Quote _q(String id, String category) => Quote(
      id: id,
      text: 'Quote $id.',
      author: 'Ann',
      category: category,
      tags: const [],
      source: 's',
      license: 'l',
    );

final _quotes = [_q('a', 'study'), _q('b', 'coding'), _q('c', 'coding')];

class _FakeQuoteRepository implements QuoteRepository {
  @override
  Future<List<Quote>> loadAll() async => _quotes;
}

class _FakeWidgetService implements WidgetService {
  final List<List<String>> pushed = [];

  @override
  Future<void> updateQuotes(List<Quote> quotes) async {
    pushed.add(quotes.map((quote) => quote.id).toList());
  }
}

Future<ProviderContainer> makeContainer(
  _FakeWidgetService widget, {
  Set<String> interests = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    PrefsRepository.keyOnboardingComplete: true,
    PrefsRepository.keyInterests: interests.toList(),
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    quoteRepositoryProvider.overrideWithValue(_FakeQuoteRepository()),
    widgetServiceProvider.overrideWithValue(widget),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('quotesForInterests', () {
    test('no interests returns everything', () {
      expect(quotesForInterests(_quotes, {}), _quotes);
    });

    test('keeps only quotes in the chosen interests', () {
      final ids = quotesForInterests(_quotes, {'coding'}).map((q) => q.id);
      expect(ids, ['b', 'c']);
    });

    test('falls back to everything when nothing matches', () {
      expect(quotesForInterests(_quotes, {'finance'}), _quotes);
    });
  });

  group('widget sync', () {
    test('pushes the quotes for the chosen interests', () async {
      final widget = _FakeWidgetService();
      final container = await makeContainer(widget, interests: {'coding'});

      await container.read(widgetSyncProvider.future);

      expect(widget.pushed.single, ['b', 'c']);
    });

    test('pushes everything when there are no interests', () async {
      final widget = _FakeWidgetService();
      final container = await makeContainer(widget);

      await container.read(widgetSyncProvider.future);

      expect(widget.pushed.single, ['a', 'b', 'c']);
    });

    test('pushes again when the interests change', () async {
      final widget = _FakeWidgetService();
      final container = await makeContainer(widget);
      await container.read(widgetSyncProvider.future);

      await container.read(userPrefsProvider.notifier).toggleInterest('study');
      await container.read(widgetSyncProvider.future);

      expect(widget.pushed.last, ['a']);
    });
  });

  test('PlatformWidgetService sends the quotes as JSON', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('com.karthik.mindspark/widget');
    MethodCall? received;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      received = call;
      return null;
    });
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    await PlatformWidgetService().updateQuotes([_quotes.first]);

    expect(received?.method, 'updateQuotes');
    final payload = (received!.arguments as Map)['quotes'] as String;
    expect(jsonDecode(payload), [
      {'id': 'a', 'text': 'Quote a.', 'author': 'Ann', 'category': 'study'},
    ]);
  });
}
