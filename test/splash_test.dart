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

const _quote = Quote(
  id: 'only',
  text: 'Only test quote.',
  author: 'Tester',
  category: 'study',
  tags: ['test'],
  source: 's',
  license: 'l',
);

class _FakeQuoteRepository implements QuoteRepository {
  @override
  Future<List<Quote>> loadAll() async => const [_quote];
}

Future<void> _start(WidgetTester tester, {required bool onboarded}) async {
  SharedPreferences.setMockInitialValues({
    if (onboarded) PrefsRepository.keyOnboardingComplete: true,
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
}

void main() {
  testWidgets('the splash screen leads to Home for returning users',
      (tester) async {
    await _start(tester, onboarded: true);
    expect(find.text('A little spark for every day'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('A little spark for every day'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('the splash screen leads new users to onboarding',
      (tester) async {
    await _start(tester, onboarded: false);
    expect(find.text('A little spark for every day'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('A little spark for every day'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
