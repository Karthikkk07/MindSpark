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
  id: 'a',
  text: 'A long enough test quote that has to wrap onto several lines when '
      'the text is scaled up for readability.',
  author: 'Tester',
  category: 'study',
  tags: ['test'],
  source: 'Test',
  license: 'Test',
);

class _FakeQuoteRepository implements QuoteRepository {
  @override
  Future<List<Quote>> loadAll() async => const [_quote];
}

Future<void> _pump(WidgetTester tester, {required double textScale}) async {
  SharedPreferences.setMockInitialValues({
    PrefsRepository.keyOnboardingComplete: true,
  });
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(720, 1280); // a small 360x640 phone
  tester.view.devicePixelRatio = 2.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

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
}

void main() {
  testWidgets('every tab lays out without overflow at 200% text size',
      (tester) async {
    await _pump(tester, textScale: 2.0);
    expect(tester.takeException(), isNull);

    for (final tab in ['Library', 'Favorites', 'Goals', 'Home']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tab tab overflowed');
    }

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Settings overflowed');
  });

  testWidgets('home screen meets the tap target and label guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, textScale: 1.0);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
