import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/app.dart';
import 'package:mindspark/core/prefs/user_prefs_controller.dart';
import 'package:mindspark/features/quotes/quote_providers.dart';
import 'package:mindspark/models/quote.dart';
import 'package:mindspark/repositories/prefs_repository.dart';
import 'package:mindspark/repositories/quote_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = Quote(
  id: 'a',
  text: 'Alpha study quote.',
  author: 'Ann',
  category: 'study',
  tags: ['focus'],
  source: 'Test source',
  license: 'Test license',
);

const _b = Quote(
  id: 'b',
  text: 'Bravo coding quote.',
  author: 'Bob',
  category: 'coding',
  tags: ['debugging'],
  source: 'Test source',
  license: 'Test license',
);

const _c = Quote(
  id: 'c',
  text: 'Charlie coding thought that is a little longer.',
  author: 'Cy',
  category: 'coding',
  tags: ['craft'],
  source: 'Test source',
  license: 'Test license',
);

class _FakeQuoteRepository implements QuoteRepository {
  @override
  Future<List<Quote>> loadAll() async => const [_c, _a, _b];
}

Future<void> openLibrary(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    PrefsRepository.keyOnboardingComplete: true,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        quoteRepositoryProvider.overrideWithValue(_FakeQuoteRepository()),
      ],
      child: const MindSparkApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('Library'),
  ));
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, Quote quote) =>
    tester.getTopLeft(find.text(quote.text)).dy;

void main() {
  testWidgets('lists every quote with a count', (tester) async {
    await openLibrary(tester);

    expect(find.text(_a.text), findsOneWidget);
    expect(find.text(_b.text), findsOneWidget);
    expect(find.text(_c.text), findsOneWidget);
    expect(find.text('3 quotes'), findsOneWidget);
  });

  testWidgets('search narrows the list', (tester) async {
    await openLibrary(tester);

    await tester.enterText(find.byType(TextField), 'bravo');
    await tester.pumpAndSettle();

    expect(find.text(_b.text), findsOneWidget);
    expect(find.text(_a.text), findsNothing);
    expect(find.text(_c.text), findsNothing);
    expect(find.text('1 quote'), findsOneWidget);
  });

  testWidgets('search also matches tags', (tester) async {
    await openLibrary(tester);

    await tester.enterText(find.byType(TextField), 'craft');
    await tester.pumpAndSettle();

    expect(find.text(_c.text), findsOneWidget);
    expect(find.text(_b.text), findsNothing);
  });

  testWidgets('a category chip filters the list', (tester) async {
    await openLibrary(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Coding'));
    await tester.pumpAndSettle();

    expect(find.text(_a.text), findsNothing);
    expect(find.text(_b.text), findsOneWidget);
    expect(find.text(_c.text), findsOneWidget);
  });

  testWidgets('no results shows an empty state that can be cleared',
      (tester) async {
    await openLibrary(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No quotes match your search.'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text(_a.text), findsOneWidget);
    expect(find.text('3 quotes'), findsOneWidget);
  });

  testWidgets('sorting A to Z reorders the list', (tester) async {
    await openLibrary(tester);
    expect(_top(tester, _c), lessThan(_top(tester, _a)));

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A to Z'));
    await tester.pumpAndSettle();

    expect(_top(tester, _a), lessThan(_top(tester, _c)));
  });

  testWidgets('tapping a quote opens its details', (tester) async {
    await openLibrary(tester);

    await tester.tap(find.text(_b.text));
    await tester.pumpAndSettle();

    expect(find.text('Test source'), findsOneWidget);
    expect(find.text('Test license'), findsOneWidget);
    expect(find.text('Copy quote'), findsOneWidget);
  });

  testWidgets('filters survive opening a quote and going back',
      (tester) async {
    await openLibrary(tester);

    await tester.enterText(find.byType(TextField), 'coding');
    await tester.pumpAndSettle();
    expect(find.text('2 quotes'), findsOneWidget);

    await tester.tap(find.text(_b.text));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('2 quotes'), findsOneWidget);
  });
}
