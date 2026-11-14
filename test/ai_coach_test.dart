import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/app.dart';
import 'package:mindspark/core/network/api_client.dart';
import 'package:mindspark/core/prefs/user_prefs_controller.dart';
import 'package:mindspark/features/ai/ai_api.dart';
import 'package:mindspark/features/auth/auth_repository.dart';
import 'package:mindspark/features/auth/token_store.dart';
import 'package:mindspark/features/goals/goals_providers.dart';
import 'package:mindspark/features/quotes/quote_providers.dart';
import 'package:mindspark/features/sync/account_api.dart';
import 'package:mindspark/models/quote.dart';
import 'package:mindspark/repositories/goals_repository.dart';
import 'package:mindspark/repositories/prefs_repository.dart';
import 'package:mindspark/repositories/quote_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

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

class _FakeAiApi implements AiApi {
  ApiException? failWith;
  String? lastToken;
  String? lastTitle;
  GoalProgress? lastProgress;

  @override
  Future<GoalSuggestion> suggestGoal(
    String token, {
    required String title,
    required String description,
    required String categoryId,
  }) async {
    lastToken = token;
    lastTitle = title;
    if (failWith != null) throw failWith!;
    return const GoalSuggestion(
      dailyAction: 'Read for 20 minutes',
      milestones: ['Finish chapter 1', 'Finish chapter 2', 'Finish the book'],
    );
  }

  @override
  Future<String> encourage(String token, GoalProgress progress) async {
    lastProgress = progress;
    if (failWith != null) throw failWith!;
    return 'Two days in a row. Keep it small and steady.';
  }
}

Map<String, Object> _goal() => {
      'id': 'g1',
      'title': 'Read daily',
      'description': '',
      'categoryId': 'growth',
      'status': 'active',
      'dailyAction': 'Read 20 minutes',
      'milestones': [
        {'id': 'm1', 'title': 'Chapter 1', 'done': true},
        {'id': 'm2', 'title': 'Chapter 2', 'done': false},
      ],
      'checkIns': ['2026-11-09', '2026-11-10'],
      'createdAt': '2026-11-01T09:00:00.000',
    };

Future<void> _openGoals(
  WidgetTester tester,
  _FakeAiApi ai, {
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    PrefsRepository.keyOnboardingComplete: true,
    GoalsRepository.keyGoals: jsonEncode([_goal()]),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        quoteRepositoryProvider.overrideWithValue(_FakeQuoteRepository()),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 10, 9)),
        tokenStoreProvider.overrideWithValue(
          MemoryTokenStore(signedIn ? testSession : null),
        ),
        // Verifying the token at startup fails offline, so no sync starts.
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            meError: const ApiException(code: 'network', message: 'offline'),
          ),
        ),
        accountApiProvider.overrideWithValue(FakeAccountApi()),
        aiApiProvider.overrideWithValue(ai),
      ],
      child: const MindSparkApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('Goals'),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('AI suggestions on the goal form', () {
    testWidgets('guests are asked to sign in', (tester) async {
      await _openGoals(tester, _FakeAiApi(), signedIn: false);
      await tester.tap(find.text('New goal'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in for AI suggestions'), findsOneWidget);
      expect(find.text('Suggest with AI'), findsNothing);
    });

    testWidgets('suggestions fill the form only after "Use suggestions"',
        (tester) async {
      final ai = _FakeAiApi();
      await _openGoals(tester, ai);
      await tester.tap(find.text('New goal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Read more',
      );

      await tester.tap(find.text('Suggest with AI'));
      await tester.pumpAndSettle();

      expect(ai.lastToken, 'tok');
      expect(ai.lastTitle, 'Read more');
      expect(find.text('Use suggestions'), findsOneWidget);
      expect(find.text('Read for 20 minutes'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Milestone 1'), findsNothing);

      await tester.tap(find.text('Use suggestions'));
      await tester.pumpAndSettle();

      expect(find.text('Use suggestions'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Daily action (optional)'),
            )
            .controller!
            .text,
        'Read for 20 minutes',
      );
      expect(find.text('Finish chapter 1'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Milestone 3'), findsOneWidget);
    });

    testWidgets('needs a title and shows server errors', (tester) async {
      final ai = _FakeAiApi();
      await _openGoals(tester, ai);
      await tester.tap(find.text('New goal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Suggest with AI'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a title'), findsOneWidget);
      expect(ai.lastTitle, isNull);

      ai.failWith = const ApiException(
        code: 'ai_limit_reached',
        message: 'You have used all 10 AI requests for today',
        status: 429,
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Read');
      await tester.tap(find.text('Suggest with AI'));
      await tester.pumpAndSettle();

      expect(find.textContaining('used all 10 AI requests'), findsOneWidget);
      expect(find.text('Use suggestions'), findsNothing);
    });
  });

  group('AI encouragement on a goal', () {
    testWidgets('sends progress numbers and shows the note', (tester) async {
      final ai = _FakeAiApi();
      await _openGoals(tester, ai);
      await tester.tap(find.text('Read daily'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Encourage me'));
      await tester.pumpAndSettle();

      expect(find.text('Two days in a row. Keep it small and steady.'),
          findsOneWidget);
      final progress = ai.lastProgress!;
      expect(progress.currentStreak, 2);
      expect(progress.checkInsLast14Days, 2);
      expect(progress.milestonesDone, 1);
      expect(progress.milestonesTotal, 2);
      expect(progress.checkedInToday, isTrue);
    });

    testWidgets('guests see a sign-in hint', (tester) async {
      await _openGoals(tester, _FakeAiApi(), signedIn: false);
      await tester.tap(find.text('Read daily'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in for AI encouragement'), findsOneWidget);
      expect(find.text('Encourage me'), findsNothing);
    });

    testWidgets('a failed request shows the error', (tester) async {
      final ai = _FakeAiApi()
        ..failWith = const ApiException(
          code: 'ai_busy',
          message: 'The AI service is busy. Try again in a minute.',
          status: 503,
        );
      await _openGoals(tester, ai);
      await tester.tap(find.text('Read daily'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Encourage me'));
      await tester.pumpAndSettle();

      expect(find.textContaining('AI service is busy'), findsOneWidget);
    });
  });
}
