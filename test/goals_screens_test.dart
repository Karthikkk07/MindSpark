import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/app.dart';
import 'package:mindspark/core/prefs/user_prefs_controller.dart';
import 'package:mindspark/features/goals/goals_providers.dart';
import 'package:mindspark/features/quotes/quote_providers.dart';
import 'package:mindspark/models/quote.dart';
import 'package:mindspark/repositories/goals_repository.dart';
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

Map<String, Object> _goal({
  String id = 'g1',
  String title = 'Read daily',
  String dailyAction = 'Read 20 minutes',
  List<String> checkIns = const [],
  List<Map<String, Object>> milestones = const [],
}) {
  return {
    'id': id,
    'title': title,
    'description': '',
    'categoryId': 'growth',
    'status': 'active',
    'dailyAction': dailyAction,
    'milestones': milestones,
    'checkIns': checkIns,
    'createdAt': '2026-11-01T09:00:00.000',
  };
}

Future<void> _openGoals(
  WidgetTester tester, {
  List<Map<String, Object>> goals = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    PrefsRepository.keyOnboardingComplete: true,
    GoalsRepository.keyGoals: jsonEncode(goals),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        quoteRepositoryProvider.overrideWithValue(_FakeQuoteRepository()),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 10, 9)),
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

Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(find.text('Read daily'));
  await tester.pumpAndSettle();
}

void main() {
  group('goals list', () {
    testWidgets('starts empty with a hint', (tester) async {
      await _openGoals(tester);

      expect(find.text('No active goals yet'), findsOneWidget);
      expect(find.text('Tap New goal to set one.'), findsOneWidget);
    });

    testWidgets('shows streaks and checks in from the card', (tester) async {
      await _openGoals(tester, goals: [
        _goal(checkIns: ['2026-11-09']),
      ]);
      expect(find.text('1 day streak'), findsOneWidget);

      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();

      expect(find.text('2 day streak'), findsOneWidget);
      expect(find.text('Done today'), findsOneWidget);
    });

    testWidgets('a goal with no recent check-ins has no streak', (tester) async {
      await _openGoals(tester, goals: [
        _goal(checkIns: ['2026-11-01']),
      ]);
      expect(find.text('No streak yet'), findsOneWidget);
    });
  });

  group('creating goals', () {
    testWidgets('a new goal with a milestone appears in the list',
        (tester) async {
      await _openGoals(tester);

      await tester.tap(find.text('New goal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Learn Dart',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Daily action (optional)'),
        'Practice 30 minutes',
      );
      await tester.tap(find.text('Add milestone'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Milestone 1'),
        'Finish the basics',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save goal'));
      await tester.pumpAndSettle();

      expect(find.text('Learn Dart'), findsOneWidget);
      expect(find.text('Practice 30 minutes'), findsOneWidget);
      expect(find.text('0 of 1 milestones'), findsOneWidget);
    });

    testWidgets('a goal needs a title', (tester) async {
      await _openGoals(tester);

      await tester.tap(find.text('New goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save goal'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a title'), findsOneWidget);
    });
  });

  group('goal details', () {
    testWidgets('milestones can be ticked off', (tester) async {
      await _openGoals(tester, goals: [
        _goal(milestones: [
          {'id': 'm1', 'title': 'Finish basics', 'done': false},
        ]),
      ]);
      await _openDetail(tester);
      expect(find.text('Milestones (0 of 1)'), findsOneWidget);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      expect(find.text('Milestones (1 of 1)'), findsOneWidget);
    });

    testWidgets('checking in and undoing from the detail screen',
        (tester) async {
      await _openGoals(tester, goals: [_goal()]);
      await _openDetail(tester);

      await tester.tap(find.text('Check in for today'));
      await tester.pumpAndSettle();
      expect(find.text('Undo check-in'), findsOneWidget);

      await tester.tap(find.text('Undo check-in'));
      await tester.pumpAndSettle();
      expect(find.text('Check in for today'), findsOneWidget);
    });

    testWidgets('a completed goal moves to the Completed tab', (tester) async {
      await _openGoals(tester, goals: [_goal()]);
      await _openDetail(tester);

      await tester.tap(find.text('Mark as completed'));
      await tester.pumpAndSettle();
      expect(find.text('Reopen goal'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('No active goals yet'), findsOneWidget);

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.text('Read daily'), findsOneWidget);
    });

    testWidgets('a goal can be edited', (tester) async {
      await _openGoals(tester, goals: [_goal()]);
      await _openDetail(tester);

      await tester.tap(find.byTooltip('Edit goal'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Read more');
      await tester.tap(find.widgetWithText(FilledButton, 'Save goal'));
      await tester.pumpAndSettle();

      expect(find.text('Read more'), findsWidgets);
      expect(find.text('Read daily'), findsNothing);
    });

    testWidgets('deleting asks first and then removes the goal',
        (tester) async {
      await _openGoals(tester, goals: [_goal()]);
      await _openDetail(tester);

      await tester.tap(find.text('Delete goal'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this goal?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('No active goals yet'), findsOneWidget);
    });

    testWidgets('cancelling keeps the goal', (tester) async {
      await _openGoals(tester, goals: [_goal()]);
      await _openDetail(tester);

      await tester.tap(find.text('Delete goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this goal?'), findsNothing);
      expect(find.text('Check in for today'), findsOneWidget);
    });
  });
}
