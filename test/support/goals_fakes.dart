import 'package:mindspark/core/network/api_client.dart';
import 'package:mindspark/features/goals/goal_models.dart';
import 'package:mindspark/features/sync/goals_sync.dart';

/// An in-memory stand-in for the goals part of the server.
class FakeGoalsApi implements GoalsApi {
  /// The goals "on the server" (each has a remoteId).
  final List<Goal> server = [];

  final List<String> calls = [];
  ApiException? failWith;

  /// Fail every create after this many have succeeded.
  int? failCreatesAfter;

  /// When set, list() returns this instead of the real contents (a stale view).
  List<Goal>? listOverride;

  int _next = 1;
  int _creates = 0;

  void _maybeFail() {
    if (failWith != null) throw failWith!;
  }

  Goal _stored(Goal goal, String remoteId) => Goal(
        id: '',
        remoteId: remoteId,
        title: goal.title,
        description: goal.description,
        categoryId: goal.categoryId,
        targetDate: goal.targetDate,
        status: goal.status,
        dailyAction: goal.dailyAction,
        milestones: [
          for (var i = 0; i < goal.milestones.length; i++)
            Milestone(
              id: 'sm$remoteId-$i',
              title: goal.milestones[i].title,
              done: goal.milestones[i].done,
            ),
        ],
        checkIns: goal.checkIns,
        createdAt: goal.createdAt,
        updatedAt: goal.updatedAt,
      );

  @override
  Future<List<Goal>> list(String token) async {
    calls.add('list');
    _maybeFail();
    return [...(listOverride ?? server)];
  }

  @override
  Future<Goal> create(String token, Goal goal) async {
    calls.add('create:${goal.title}');
    _maybeFail();
    if (failCreatesAfter != null && _creates >= failCreatesAfter!) {
      throw const ApiException(code: 'network', message: 'offline');
    }
    _creates++;
    final stored = _stored(goal, 'r${_next++}');
    server.add(stored);
    return stored;
  }

  @override
  Future<Goal> replace(String token, String remoteId, Goal goal) async {
    calls.add('replace:${goal.title}');
    _maybeFail();
    final index = server.indexWhere((item) => item.remoteId == remoteId);
    if (index < 0) {
      throw const ApiException(code: 'not_found', message: 'gone', status: 404);
    }
    if (goal.updatedAt.isBefore(server[index].updatedAt)) {
      throw const ApiException(code: 'stale_write', message: 'stale', status: 409);
    }
    final stored = _stored(goal, remoteId);
    server[index] = stored;
    return stored;
  }

  @override
  Future<void> delete(String token, String remoteId) async {
    calls.add('delete:$remoteId');
    _maybeFail();
    server.removeWhere((item) => item.remoteId == remoteId);
  }
}

/// A goal as the server holds it.
Goal serverGoal({
  required String remoteId,
  String title = 'Server goal',
  required DateTime updatedAt,
}) {
  return Goal(
    id: '',
    remoteId: remoteId,
    title: title,
    categoryId: 'growth',
    createdAt: DateTime(2026, 11, 1),
    updatedAt: updatedAt,
  );
}
