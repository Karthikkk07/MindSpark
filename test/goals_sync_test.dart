import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/core/network/api_client.dart';
import 'package:mindspark/core/prefs/user_prefs_controller.dart';
import 'package:mindspark/features/auth/auth_controller.dart';
import 'package:mindspark/features/auth/auth_repository.dart';
import 'package:mindspark/features/auth/token_store.dart';
import 'package:mindspark/features/goals/goal_models.dart';
import 'package:mindspark/features/goals/goals_providers.dart';
import 'package:mindspark/features/sync/account_api.dart';
import 'package:mindspark/features/sync/goals_sync.dart';
import 'package:mindspark/features/sync/sync_controller.dart';
import 'package:mindspark/repositories/goals_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/goals_fakes.dart';

const _offline = ApiException(code: 'network', message: 'offline');

final _yesterday = DateTime(2026, 11, 9, 9);
final _now = DateTime(2026, 11, 10, 9);
final _later = DateTime(2026, 11, 10, 12);

Goal _local({
  required String id,
  String title = 'Local goal',
  String? remoteId,
  DateTime? updatedAt,
  bool dirty = false,
}) {
  return Goal(
    id: id,
    title: title,
    categoryId: 'growth',
    createdAt: DateTime(2026, 11, 1),
    remoteId: remoteId,
    updatedAt: updatedAt,
    dirty: dirty,
  );
}

Future<ProviderContainer> _container(
  FakeGoalsApi goalsApi, {
  List<Goal> goals = const [],
  Map<String, Object> extra = const {},
  bool signedIn = true,
}) async {
  SharedPreferences.setMockInitialValues({
    GoalsRepository.keyGoals: jsonEncode(goals.map((goal) => goal.toJson()).toList()),
    ...extra,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    tokenStoreProvider.overrideWithValue(
      MemoryTokenStore(signedIn ? testSession : null),
    ),
    // Verifying the token at startup "fails offline", so no sync starts by itself.
    authRepositoryProvider.overrideWithValue(FakeAuthRepository(meError: _offline)),
    accountApiProvider.overrideWithValue(FakeAccountApi()),
    goalsApiProvider.overrideWithValue(goalsApi),
    clockProvider.overrideWithValue(() => _now),
  ]);
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  await pumpEventQueue();
  return container;
}

Future<void> _sync(ProviderContainer container) =>
    container.read(syncControllerProvider.notifier).syncNow();

List<Goal> _goals(ProviderContainer container) => container.read(goalsProvider);

Goal _byTitle(ProviderContainer container, String title) =>
    _goals(container).firstWhere((goal) => goal.title == title);

void main() {
  group('goals sync', () {
    test('uploads goals that only exist on this device', () async {
      final api = FakeGoalsApi();
      final container = await _container(api, goals: [
        _local(id: 'a', title: 'First'),
        Goal(
          id: 'b',
          title: 'Second',
          categoryId: 'growth',
          createdAt: DateTime(2026, 11, 2),
          milestones: const [Milestone(id: 'm1', title: 'Step')],
        ),
      ]);

      await _sync(container);

      expect(api.server.map((goal) => goal.title), ['First', 'Second']);
      final first = _byTitle(container, 'First');
      expect(first.remoteId, 'r1');
      expect(first.dirty, isFalse);
      expect(_byTitle(container, 'Second').milestones.single.id, 'smr2-0');
    });

    test('downloads goals that only exist on the account', () async {
      final api = FakeGoalsApi()
        ..server.add(serverGoal(remoteId: 'r9', updatedAt: _yesterday));
      final container = await _container(api);

      await _sync(container);

      final goal = _goals(container).single;
      expect(goal.title, 'Server goal');
      expect(goal.remoteId, 'r9');
      expect(goal.id, isNotEmpty);
      expect(goal.dirty, isFalse);
    });

    test('sends a changed goal when this device is newer', () async {
      final api = FakeGoalsApi()
        ..server.add(serverGoal(remoteId: 'r1', title: 'Old', updatedAt: _yesterday));
      final container = await _container(api, goals: [
        _local(id: 'a', title: 'Edited', remoteId: 'r1', updatedAt: _now, dirty: true),
      ]);

      await _sync(container);

      expect(api.server.single.title, 'Edited');
      expect(_goals(container).single.dirty, isFalse);
    });

    test('takes the account version when it is newer', () async {
      final api = FakeGoalsApi()
        ..server.add(serverGoal(remoteId: 'r1', title: 'New', updatedAt: _now));
      final container = await _container(api, goals: [
        _local(id: 'a', title: 'Old', remoteId: 'r1', updatedAt: _yesterday),
      ]);

      await _sync(container);

      expect(_goals(container).single.title, 'New');
      expect(_goals(container).single.id, 'a');
      expect(api.calls.where((call) => call.startsWith('replace')), isEmpty);
    });

    test('removes a goal the account no longer has', () async {
      final api = FakeGoalsApi();
      final container = await _container(api, goals: [
        _local(id: 'a', remoteId: 'r5', updatedAt: _yesterday),
      ]);

      await _sync(container);

      expect(_goals(container), isEmpty);
    });

    test('a goal deleted here is deleted on the account', () async {
      final api = FakeGoalsApi()
        ..server.add(serverGoal(remoteId: 'r1', updatedAt: _yesterday));
      final container = await _container(api, goals: [
        _local(id: 'a', remoteId: 'r1', updatedAt: _yesterday),
      ]);

      await container.read(goalsProvider.notifier).delete('a');
      expect(container.read(goalsProvider.notifier).pendingDeletes, {'r1'});

      await _sync(container);

      expect(api.server, isEmpty);
      expect(container.read(goalsProvider.notifier).pendingDeletes, isEmpty);
      expect(_goals(container), isEmpty);
    });

    test('an interrupted sync never uploads a goal twice', () async {
      final api = FakeGoalsApi()..failCreatesAfter = 1;
      final container = await _container(api, goals: [
        _local(id: 'a', title: 'First'),
        _local(id: 'b', title: 'Second'),
      ]);

      await _sync(container);
      expect(container.read(syncControllerProvider).phase, SyncPhase.failed);
      expect(api.server, hasLength(1));
      expect(_byTitle(container, 'First').remoteId, 'r1');
      expect(_byTitle(container, 'Second').remoteId, isNull);

      api.failCreatesAfter = null;
      await _sync(container);

      expect(api.server.map((goal) => goal.title), ['First', 'Second']);
      expect(_goals(container).every((goal) => goal.remoteId != null), isTrue);
    });

    test('a different account drops the old account goals but keeps unsynced ones',
        () async {
      final api = FakeGoalsApi();
      final container = await _container(
        api,
        goals: [
          _local(id: 'a', title: 'Old account goal', remoteId: 'r1', updatedAt: _yesterday),
          _local(id: 'b', title: 'Guest goal'),
        ],
        extra: {GoalsRepository.keyAccountId: 'someone-else'},
      );

      await _sync(container);

      expect(_goals(container).map((goal) => goal.title), ['Guest goal']);
      expect(api.server.map((goal) => goal.title), ['Guest goal']);
    });

    test('when the account changed first, the push is skipped and kept for later',
        () async {
      final api = FakeGoalsApi()
        ..server.add(serverGoal(remoteId: 'r1', title: 'Server edit', updatedAt: _later))
        ..listOverride = [
          serverGoal(remoteId: 'r1', title: 'Stale view', updatedAt: _yesterday),
        ];
      final container = await _container(api, goals: [
        _local(id: 'a', title: 'Local edit', remoteId: 'r1', updatedAt: _now, dirty: true),
      ]);

      await _sync(container);

      expect(api.server.single.title, 'Server edit');
      expect(_goals(container).single.title, 'Local edit');
      expect(_goals(container).single.dirty, isTrue);
    });
  });

  group('marking goals as changed', () {
    test('an edit stamps the time and marks the goal as unsent', () async {
      final container = await _container(FakeGoalsApi(), goals: [
        _local(id: 'a', remoteId: 'r1', updatedAt: _yesterday),
      ]);

      await container.read(goalsProvider.notifier).checkIn('a');

      final goal = _goals(container).single;
      expect(goal.dirty, isTrue);
      expect(goal.updatedAt, _now);
    });

    test('a check-in that changes nothing leaves the goal alone', () async {
      final container = await _container(FakeGoalsApi(), goals: [
        Goal(
          id: 'a',
          title: 'Read',
          categoryId: 'growth',
          createdAt: DateTime(2026, 11, 1),
          updatedAt: _yesterday,
          checkIns: const ['2026-11-10'],
        ),
      ]);

      await container.read(goalsProvider.notifier).checkIn('a');

      final goal = _goals(container).single;
      expect(goal.dirty, isFalse);
      expect(goal.updatedAt, _yesterday);
    });

    test('a goal edited while it was being sent keeps its edit', () async {
      final container = await _container(FakeGoalsApi(), goals: [
        _local(id: 'a', updatedAt: _later, dirty: true),
      ]);

      await container.read(goalsProvider.notifier).linkRemote(
            'a',
            serverGoal(remoteId: 'r1', updatedAt: _yesterday),
            sentAt: _now,
          );

      final goal = _goals(container).single;
      expect(goal.remoteId, 'r1');
      expect(goal.dirty, isTrue);
      expect(goal.updatedAt, _later);
    });

    test('a goal edited while the account version arrived is not overwritten',
        () async {
      final container = await _container(FakeGoalsApi(), goals: [
        _local(id: 'a', title: 'Mine', remoteId: 'r1', updatedAt: _later, dirty: true),
      ]);

      await container.read(goalsProvider.notifier).applyRemote(
            'a',
            serverGoal(remoteId: 'r1', title: 'Theirs', updatedAt: DateTime(2026, 11, 11)),
            seenAt: _now,
          );

      expect(_goals(container).single.title, 'Mine');
    });
  });

  group('sync controller', () {
    test('a fresh edit is sent by a goals sync', () async {
      final api = FakeGoalsApi()
        ..server.add(serverGoal(remoteId: 'r1', title: 'Local goal', updatedAt: _yesterday));
      final container = await _container(api, goals: [
        _local(id: 'a', remoteId: 'r1', updatedAt: _yesterday),
      ]);

      await container.read(goalsProvider.notifier).checkIn('a');
      await container.read(syncControllerProvider.notifier).syncGoalsOnly();

      expect(api.calls, contains('replace:Local goal'));
      expect(api.server.single.checkIns, ['2026-11-10']);
      expect(_goals(container).single.dirty, isFalse);
    });

    test('signing in uploads goals made as a guest', () async {
      final api = FakeGoalsApi();
      final container = await _container(
        api,
        goals: [_local(id: 'a', title: 'Guest goal')],
        signedIn: false,
      );

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'ann@example.com', password: 'password123');
      await pumpEventQueue();

      expect(api.server.map((goal) => goal.title), ['Guest goal']);
    });

    test('a guest never calls the account', () async {
      final api = FakeGoalsApi();
      final container = await _container(api, signedIn: false);

      await container
          .read(goalsProvider.notifier)
          .create(title: 'Mine', categoryId: 'growth');
      await container.read(syncControllerProvider.notifier).syncGoalsOnly();

      expect(api.calls, isEmpty);
    });

    test('an offline failure is reported and the edit stays unsent', () async {
      final api = FakeGoalsApi()..failWith = _offline;
      final container = await _container(api, goals: [
        _local(id: 'a', remoteId: 'r1', updatedAt: _yesterday),
      ]);

      await container.read(goalsProvider.notifier).checkIn('a');
      await container.read(syncControllerProvider.notifier).syncGoalsOnly();

      final status = container.read(syncControllerProvider);
      expect(status.phase, SyncPhase.failed);
      expect(status.message, 'Offline: changes will sync later.');
      expect(_goals(container).single.dirty, isTrue);
    });
  });
}
