import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/core/prefs/user_prefs_controller.dart';
import 'package:mindspark/features/goals/goal_models.dart';
import 'package:mindspark/features/goals/goals_providers.dart';
import 'package:mindspark/features/goals/streaks.dart';
import 'package:mindspark/repositories/goals_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _today = '2026-11-10';
String _d(int offset) => addDays(_today, offset);
Streaks _streaks(List<String> days) => computeStreaks(days, _today);

Future<ProviderContainer> _container({
  Map<String, Object> initial = const {},
  DateTime Function()? clock,
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    clockProvider.overrideWithValue(clock ?? () => DateTime(2026, 11, 10, 9)),
  ]);
  addTearDown(container.dispose);
  return container;
}

Goal _goal(ProviderContainer container, String id) =>
    container.read(goalsProvider).firstWhere((goal) => goal.id == id);

void main() {
  group('date helpers', () {
    test('dateKey pads the calendar fields', () {
      expect(dateKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(dateKey(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
    });

    test('parseDateKey accepts real dates only', () {
      expect(parseDateKey('2028-02-29'), isNotNull);
      for (final bad in ['2027-02-29', '2027-13-01', '2027-1-1', 'abc', '', '0050-01-01']) {
        expect(parseDateKey(bad), isNull, reason: bad);
      }
    });

    test('addDays crosses month, year and leap-day boundaries', () {
      expect(addDays('2026-12-31', 1), '2027-01-01');
      expect(addDays('2028-02-28', 1), '2028-02-29');
      expect(addDays('2027-03-01', -1), '2027-02-28');
      expect(addDays('2026-11-10', -14), '2026-10-27');
    });

    test('formatDateKey is readable', () {
      expect(formatDateKey('2027-01-31'), '31 Jan 2027');
      expect(formatDateKey('nonsense'), 'nonsense');
    });
  });

  group('computeStreaks', () {
    test('no check-ins', () {
      final s = _streaks([]);
      expect((s.current, s.longest), (0, 0));
    });

    test('today or yesterday keeps the streak alive', () {
      expect(_streaks([_d(0)]).current, 1);
      expect(_streaks([_d(-1)]).current, 1);
    });

    test('two days without a check-in resets the current streak', () {
      final s = _streaks([_d(-2)]);
      expect((s.current, s.longest), (0, 1));
    });

    test('counts a run of consecutive days', () {
      final s = _streaks([_d(-4), _d(-3), _d(-2), _d(-1), _d(0)]);
      expect((s.current, s.longest), (5, 5));
    });

    test('separates the current streak from the longest one', () {
      var s = _streaks([_d(-9), _d(-8), _d(-7), _d(-2), _d(-1)]);
      expect((s.current, s.longest), (2, 3));
      s = _streaks([_d(-9), _d(-8), _d(-7), _d(-5), _d(-4)]);
      expect((s.current, s.longest), (0, 3));
    });

    test('ignores duplicates, order and invalid entries', () {
      final s = _streaks([_d(0), _d(-1), _d(0), 'junk', _d(-1)]);
      expect((s.current, s.longest), (2, 2));
    });

    test('future days do not count towards the current streak', () {
      final s = _streaks([_d(1), _d(0)]);
      expect((s.current, s.longest), (1, 2));
    });

    test('works across year and leap-day boundaries', () {
      var s = computeStreaks(['2027-01-01', '2026-12-31', '2026-12-30'], '2027-01-01');
      expect(s.current, 3);
      s = computeStreaks(['2028-03-01', '2028-02-29', '2028-02-28'], '2028-03-01');
      expect(s.current, 3);
    });
  });

  group('goals controller', () {
    test('create saves a goal that survives a restart', () async {
      final container = await _container();
      final id = await container.read(goalsProvider.notifier).create(
            title: 'Read daily',
            categoryId: 'growth',
            dailyAction: 'Read 20 minutes',
            targetDate: '2027-01-31',
            milestones: const [Milestone(id: 'm1', title: 'Chapter 1')],
          );
      expect(id, isNotNull);

      final reloaded = GoalsRepository(container.read(sharedPreferencesProvider)).load();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.title, 'Read daily');
      expect(reloaded.single.dailyAction, 'Read 20 minutes');
      expect(reloaded.single.targetDate, '2027-01-31');
      expect(reloaded.single.milestones.single.title, 'Chapter 1');
    });

    test('refuses to create more than 100 goals', () async {
      final container = await _container();
      final prefs = container.read(sharedPreferencesProvider);
      await GoalsRepository(prefs).save([
        for (var i = 0; i < 100; i++)
          Goal(id: 'g$i', title: 'Goal $i', categoryId: 'growth', createdAt: DateTime(2026)),
      ]);

      final fresh = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(fresh.dispose);

      final id = await fresh
          .read(goalsProvider.notifier)
          .create(title: 'One more', categoryId: 'growth');
      expect(id, isNull);
      expect(fresh.read(goalsProvider), hasLength(100));
    });

    test('check-in is once per day, and days in a row build a streak', () async {
      var now = DateTime(2026, 11, 10, 9);
      final container = await _container(clock: () => now);
      final notifier = container.read(goalsProvider.notifier);
      final id = (await notifier.create(title: 'Read', categoryId: 'growth'))!;

      await notifier.checkIn(id);
      await notifier.checkIn(id);
      expect(_goal(container, id).checkIns, ['2026-11-10']);

      now = DateTime(2026, 11, 11, 9);
      await notifier.checkIn(id);
      final goal = _goal(container, id);
      expect(goal.checkIns, ['2026-11-10', '2026-11-11']);
      expect(computeStreaks(goal.checkIns, '2026-11-11').current, 2);

      now = DateTime(2026, 11, 14, 9);
      expect(computeStreaks(goal.checkIns, dateKey(now)).current, 0);
    });

    test('check-in is ignored once a goal is completed', () async {
      final container = await _container();
      final notifier = container.read(goalsProvider.notifier);
      final id = (await notifier.create(title: 'Read', categoryId: 'growth'))!;
      await notifier.setStatus(id, GoalStatus.completed);

      await notifier.checkIn(id);

      expect(_goal(container, id).checkIns, isEmpty);
    });

    test('undoing a check-in removes it', () async {
      final container = await _container();
      final notifier = container.read(goalsProvider.notifier);
      final id = (await notifier.create(title: 'Read', categoryId: 'growth'))!;
      await notifier.checkIn(id);

      await notifier.undoCheckIn(id);

      expect(_goal(container, id).checkIns, isEmpty);
    });

    test('milestones can be ticked and drive the progress', () async {
      final container = await _container();
      final notifier = container.read(goalsProvider.notifier);
      final id = (await notifier.create(
        title: 'Read',
        categoryId: 'growth',
        milestones: const [
          Milestone(id: 'a', title: 'One'),
          Milestone(id: 'b', title: 'Two'),
        ],
      ))!;

      await notifier.toggleMilestone(id, 'a');
      expect(_goal(container, id).progress, 0.5);

      await notifier.toggleMilestone(id, 'a');
      expect(_goal(container, id).progress, 0.0);
    });

    test('completing stamps the time and reopening clears it', () async {
      final container = await _container();
      final notifier = container.read(goalsProvider.notifier);
      final id = (await notifier.create(title: 'Read', categoryId: 'growth'))!;

      await notifier.setStatus(id, GoalStatus.completed);
      expect(_goal(container, id).completedAt, isNotNull);

      await notifier.setStatus(id, GoalStatus.active);
      expect(_goal(container, id).completedAt, isNull);
    });

    test('update and delete work', () async {
      final container = await _container();
      final notifier = container.read(goalsProvider.notifier);
      final id = (await notifier.create(title: 'Read', categoryId: 'growth'))!;

      await notifier.update(_goal(container, id).copyWith(title: 'Read more'));
      expect(_goal(container, id).title, 'Read more');

      await notifier.delete(id);
      expect(container.read(goalsProvider), isEmpty);
    });
  });

  group('loading damaged data', () {
    test('invalid JSON gives an empty list', () async {
      final container = await _container(initial: {GoalsRepository.keyGoals: 'not json'});
      expect(container.read(goalsProvider), isEmpty);
    });

    test('a damaged entry is skipped and the rest are kept', () async {
      final good = {
        'id': 'g1',
        'title': 'Good',
        'categoryId': 'growth',
        'createdAt': '2026-11-10T09:00:00.000',
      };
      final container = await _container(initial: {
        GoalsRepository.keyGoals: jsonEncode([good, {'broken': true}, 5]),
      });
      expect(container.read(goalsProvider).map((goal) => goal.title), ['Good']);
    });
  });
}
