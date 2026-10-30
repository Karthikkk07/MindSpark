import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/app.dart';
import 'package:mindspark/core/prefs/user_prefs_controller.dart';
import 'package:mindspark/features/home/widgets/quote_card.dart';
import 'package:mindspark/features/quotes/quote_providers.dart';
import 'package:mindspark/features/settings/settings_screen.dart';
import 'package:mindspark/models/quote.dart';
import 'package:mindspark/repositories/prefs_repository.dart';
import 'package:mindspark/repositories/quote_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Starts the app with the given saved preferences. By default onboarding
/// is already complete, so the app opens on Home.
Future<SharedPreferences> pumpApp(
  WidgetTester tester, {
  Map<String, Object> initial = const {
    PrefsRepository.keyOnboardingComplete: true,
  },
}) async {
  SharedPreferences.setMockInitialValues(initial);
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
  return prefs;
}

void main() {
  group('onboarding', () {
    testWidgets('first launch shows onboarding and finishes as guest',
        (tester) async {
      final prefs = await pumpApp(tester, initial: {});

      expect(find.text('Welcome to MindSpark'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(prefs.getBool(PrefsRepository.keyOnboardingComplete), isTrue);
    });

    testWidgets('picking an interest is saved', (tester) async {
      final prefs = await pumpApp(tester, initial: {});

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Coding'));
      await tester.pumpAndSettle();

      expect(prefs.getStringList(PrefsRepository.keyInterests), ['coding']);
    });
  });

  group('home', () {
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

    testWidgets('saved interests narrow the quotes shown', (tester) async {
      await pumpApp(tester, initial: {
        PrefsRepository.keyOnboardingComplete: true,
        PrefsRepository.keyInterests: ['coding'],
      });

      expect(find.text(_quoteB.text), findsOneWidget);

      await tester.tap(find.text('New quote'));
      await tester.pumpAndSettle();

      expect(find.text(_quoteB.text), findsOneWidget);
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
  });

  group('navigation and settings', () {
    testWidgets('bottom navigation switches tabs', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Library'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Quote library'), findsOneWidget);
    });

    testWidgets('dark theme is applied and saved', (tester) async {
      final prefs = await pumpApp(tester);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SettingsScreen));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(prefs.getString(PrefsRepository.keyThemeMode), 'dark');
    });
  });
}
