import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/user_prefs_controller.dart';
import '../../repositories/goals_repository.dart';
import '../sync/sync_controller.dart';
import 'goal_models.dart';
import 'streaks.dart';

/// The current time. Tests replace it to move between days.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(ref.watch(sharedPreferencesProvider)),
);

/// The user's goals. Every change is saved on the device and, for signed-in
/// users, sent to the account shortly afterwards.
class GoalsController extends Notifier<List<Goal>> {
  static const int maxGoals = 100;

  Set<String> _pendingDeletes = {};

  @override
  List<Goal> build() {
    final repo = ref.watch(goalsRepositoryProvider);
    _pendingDeletes = repo.loadPendingDeletes();
    return repo.load();
  }

  DateTime _now() => ref.read(clockProvider)();

  /// Account ids of goals deleted here that the account still has.
  Set<String> get pendingDeletes => {..._pendingDeletes};

  Future<void> _save(List<Goal> next) async {
    state = next;
    await ref.read(goalsRepositoryProvider).save(next);
  }

  void _requestSync() {
    if (ref.mounted) {
      ref.read(syncControllerProvider.notifier).goalsChanged();
    }
  }

  String _newId() {
    var id = 'g${_now().microsecondsSinceEpoch.toRadixString(36)}';
    while (state.any((goal) => goal.id == id)) {
      id = '${id}x';
    }
    return id;
  }

  /// Applies [change] to one goal. Real changes stamp the time and mark the
  /// goal as needing sync; returning the same goal means nothing changed.
  Future<void> _edit(String id, Goal Function(Goal goal) change) async {
    final now = _now();
    var changed = false;
    final next = <Goal>[];
    for (final goal in state) {
      if (goal.id != id) {
        next.add(goal);
        continue;
      }
      final edited = change(goal);
      if (identical(edited, goal)) {
        next.add(goal);
      } else {
        changed = true;
        next.add(edited.copyWith(updatedAt: now, dirty: true));
      }
    }
    if (!changed) return;
    await _save(next);
    _requestSync();
  }

  /// Creates a goal and returns its id, or null when the limit is reached.
  Future<String?> create({
    required String title,
    required String categoryId,
    String description = '',
    String? targetDate,
    String dailyAction = '',
    List<Milestone> milestones = const [],
  }) async {
    if (state.length >= maxGoals) return null;
    final now = _now();
    final id = _newId();
    final goal = Goal(
      id: id,
      title: title,
      categoryId: categoryId,
      description: description,
      targetDate: targetDate,
      dailyAction: dailyAction,
      milestones: milestones,
      createdAt: now,
    );
    await _save([...state, goal]);
    _requestSync();
    return id;
  }

  Future<void> update(Goal goal) => _edit(goal.id, (existing) => goal);

  Future<void> delete(String id) async {
    Goal? goal;
    for (final item in state) {
      if (item.id == id) goal = item;
    }
    if (goal == null) return;
    final remoteId = goal.remoteId;
    if (remoteId != null) {
      _pendingDeletes = {..._pendingDeletes, remoteId};
      await ref.read(goalsRepositoryProvider).savePendingDeletes(_pendingDeletes);
    }
    await _save(state.where((item) => item.id != id).toList());
    _requestSync();
  }

  Future<void> setStatus(String id, GoalStatus status) {
    return _edit(id, (goal) {
      if (goal.status == status) return goal;
      return goal.copyWith(
        status: status,
        completedAt: status == GoalStatus.completed ? _now() : null,
        clearCompletedAt: status != GoalStatus.completed,
      );
    });
  }

  Future<void> toggleMilestone(String goalId, String milestoneId) {
    return _edit(
      goalId,
      (goal) => goal.copyWith(
        milestones: [
          for (final milestone in goal.milestones)
            milestone.id == milestoneId
                ? milestone.copyWith(done: !milestone.done)
                : milestone,
        ],
      ),
    );
  }

  /// Marks today's daily action as done. Safe to repeat, and only for
  /// active goals.
  Future<void> checkIn(String goalId) {
    return _edit(goalId, (goal) {
      final today = dateKey(_now());
      if (!goal.isActive || goal.checkIns.contains(today)) return goal;
      return goal.copyWith(checkIns: [...goal.checkIns, today]..sort());
    });
  }

  /// Undoes a check-in (today's by default).
  Future<void> undoCheckIn(String goalId, {String? date}) {
    return _edit(goalId, (goal) {
      final key = date ?? dateKey(_now());
      if (!goal.checkIns.contains(key)) return goal;
      return goal.copyWith(
        checkIns: goal.checkIns.where((day) => day != key).toList(),
      );
    });
  }

  // The methods below are used by sync. They do not mark goals as changed
  // and do not start another sync.

  /// Runs [change] on a goal only if it has not been edited since [seenAt],
  /// so something typed while a sync is running is never overwritten.
  Future<void> _applyIfUnchanged(
    String localId,
    DateTime seenAt,
    Goal Function(Goal goal) change,
  ) =>
      _save([
        for (final goal in state)
          goal.id == localId && goal.updatedAt == seenAt ? change(goal) : goal,
      ]);

  /// A local goal was uploaded or replaced: remember its account id. If it was
  /// edited again while being sent, that edit stays marked as unsent.
  Future<void> linkRemote(
    String localId,
    Goal remote, {
    required DateTime sentAt,
  }) =>
      _save([
        for (final goal in state)
          if (goal.id != localId)
            goal
          else if (goal.updatedAt == sentAt)
            goal.copyWith(
              remoteId: remote.remoteId,
              milestones: remote.milestones,
              updatedAt: remote.updatedAt,
              dirty: false,
            )
          else
            goal.copyWith(remoteId: remote.remoteId),
      ]);

  /// The account's version is newer: take it.
  Future<void> applyRemote(
    String localId,
    Goal remote, {
    required DateTime seenAt,
  }) =>
      _applyIfUnchanged(
        localId,
        seenAt,
        (goal) => remote.withLocalIdentity(id: goal.id, createdAt: goal.createdAt),
      );

  Future<void> markClean(String localId, {required DateTime seenAt}) =>
      _applyIfUnchanged(localId, seenAt, (goal) => goal.copyWith(dirty: false));
  /// A goal that exists only on the account: add it here.
  Future<void> addFromRemote(Goal remote) => _save([
        ...state,
        remote.withLocalIdentity(id: _newId(), createdAt: remote.createdAt),
      ]);

  /// The goal was deleted elsewhere: remove it without queueing a delete.
  Future<void> removeLocal(String localId) =>
      _save(state.where((goal) => goal.id != localId).toList());

  Future<void> clearPendingDelete(String remoteId) async {
    _pendingDeletes = {..._pendingDeletes}..remove(remoteId);
    await ref.read(goalsRepositoryProvider).savePendingDeletes(_pendingDeletes);
  }

  /// A different account signed in: forget goals that belonged to the old
  /// account. Goals that were never synced stay.
  Future<void> dropPreviousAccountData() async {
    _pendingDeletes = {};
    await ref.read(goalsRepositoryProvider).savePendingDeletes(_pendingDeletes);
    await _save(state.where((goal) => goal.remoteId == null).toList());
  }
}

final goalsProvider =
    NotifierProvider<GoalsController, List<Goal>>(GoalsController.new);

/// One goal by id, or null if it does not exist.
final goalProvider = Provider.family<Goal?, String>((ref, id) {
  for (final goal in ref.watch(goalsProvider)) {
    if (goal.id == id) return goal;
  }
  return null;
});
