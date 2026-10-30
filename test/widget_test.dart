import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/app.dart';
import 'package:mindspark/features/home/widgets/quote_card.dart';
import 'package:mindspark/features/quotes/quote_providers.dart';
import 'package:mindspark/features/settings/settings_screen.dart';
import 'package:mindspark/models/quote.dart';
import 'package:mindspark/repositories/quote_repository.dart';

const _quoteA = Quote(
  id: 'a',
  text: 'First test quote.',
  author: 'Tester',
  category: 'study',
  tags: ['test'],
  source: 'Test',
  license: 'Test',
);

const _quoteB = Quote(
  id: 'b',
  text: 'Second test quote.',
  author: 'Tester',
  category: 'coding',
  tags: ['test'],
  source: 'Test',
  license: 'Test',
);

class _FakeQuoteRepository implements QuoteRepository {
  @override
  Future<List<Quote>> loadAll() async => const [_quoteA, _quoteB];
}

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quoteRepositoryProvider.overrideWithValue(_FakeQuoteRepository()),
      ],
      child: const MindSparkApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts on Home with a quote and the navigation bar',
      (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(QuoteCard), findsOneWidget);
  });

  testWidgets('New quote shows a different quote', (tester) async {
    await pumpApp(tester);

    final showingA = find.text(_quoteA.text).evaluate().isNotEmpty;
    final other = showingA ? _quoteB : _quoteA;

    await tester.tap(find.text('New quote'));
    await tester.pumpAndSettle();

    expect(find.text(other.text), findsOneWidget);
  });

  testWidgets('Copy puts the quote on the clipboard and confirms',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Copy quote'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(copied, isNotNull);
    expect(copied, contains('test quote'));
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('bottom navigation switches tabs', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Library'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Quote library'), findsOneWidget);
  });

  testWidgets('theme can be switched to dark in Settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
