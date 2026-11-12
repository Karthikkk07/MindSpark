import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/user_prefs_controller.dart';
import '../../repositories/goals_repository.dart';
import 'goal_models.dart';
import 'streaks.dart';

/// The current time. Tests replace it to move between days.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(ref.watch(sharedPreferencesProvider)),
);

/// The user's goals. Every change is saved on the device.
class GoalsController extends Notifier<List<Goal>> {
  static const int maxGoals = 100;

  @override
  List<Goal> build() => ref.watch(goalsRepositoryProvider).load();

  DateTime _now() => ref.read(clockProvider)();

  Future<void> _save(List<Goal> next) async {
    state = next;
    await ref.read(goalsRepositoryProvider).save(next);
  }

  Future<void> _replace(String id, Goal Function(Goal goal) change) =>
      _save([for (final goal in state) goal.id == id ? change(goal) : goal]);

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
    var id = 'g${now.microsecondsSinceEpoch.toRadixString(36)}';
    while (state.any((goal) => goal.id == id)) {
      id = '${id}x';
    }
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
    return id;
  }

  Future<void> update(Goal goal) =>
      _replace(goal.id, (existing) => goal);

  Future<void> delete(String id) =>
      _save(state.where((goal) => goal.id != id).toList());

  Future<void> setStatus(String id, GoalStatus status) {
    return _replace(
      id,
      (goal) => goal.copyWith(
        status: status,
        completedAt: status == GoalStatus.completed ? _now() : null,
        clearCompletedAt: status != GoalStatus.completed,
      ),
    );
  }

  Future<void> toggleMilestone(String goalId, String milestoneId) {
    return _replace(
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
    return _replace(goalId, (goal) {
      final today = dateKey(_now());
      if (!goal.isActive || goal.checkIns.contains(today)) return goal;
      return goal.copyWith(checkIns: [...goal.checkIns, today]..sort());
    });
  }

  /// Undoes a check-in (today's by default).
  Future<void> undoCheckIn(String goalId, {String? date}) {
    return _replace(goalId, (goal) {
      final key = date ?? dateKey(_now());
      return goal.copyWith(
        checkIns: goal.checkIns.where((day) => day != key).toList(),
      );
    });
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
