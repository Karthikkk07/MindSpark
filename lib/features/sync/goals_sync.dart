import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_models.dart';
import '../goals/goal_models.dart';
import '../goals/goals_providers.dart';

/// The goals part of the MindSpark API.
abstract class GoalsApi {
  Future<List<Goal>> list(String token);

  Future<Goal> create(String token, Goal goal);

  /// Replaces the goal on the account. Throws status 409 if the account has a
  /// newer version.
  Future<Goal> replace(String token, String remoteId, Goal goal);

  Future<void> delete(String token, String remoteId);
}

final RegExp _serverId = RegExp(r'^[a-fA-F0-9]{24}$');

Map<String, dynamic> _body(Goal goal) => {
      'title': goal.title,
      'description': goal.description,
      'category': goal.categoryId,
      'targetDate': goal.targetDate,
      'dailyAction': goal.dailyAction,
      'status': goal.status.name,
      'milestones': [
        for (final milestone in goal.milestones)
          {
            if (_serverId.hasMatch(milestone.id)) 'id': milestone.id,
            'title': milestone.title,
            'done': milestone.done,
          },
      ],
      'checkIns': goal.checkIns,
      'clientUpdatedAt': goal.updatedAt.toUtc().toIso8601String(),
    };

class ApiGoalsApi implements GoalsApi {
  ApiGoalsApi(this._api);

  final ApiClient _api;

  @override
  Future<List<Goal>> list(String token) async {
    final json = await _api.get('/goals', token: token);
    final items = (json['data'] as List<dynamic>?) ?? const [];
    return [
      for (final item in items) Goal.fromServer(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<Goal> create(String token, Goal goal) async {
    final json = await _api.post('/goals', body: _body(goal), token: token);
    return Goal.fromServer(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Goal> replace(String token, String remoteId, Goal goal) async {
    final json = await _api.put('/goals/$remoteId', body: _body(goal), token: token);
    return Goal.fromServer(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> delete(String token, String remoteId) async {
    try {
      await _api.delete('/goals/$remoteId', token: token);
    } on ApiException catch (error) {
      if (error.status != 404) rethrow; // already gone
    }
  }
}

final goalsApiProvider = Provider<GoalsApi>(
  (ref) => ApiGoalsApi(ref.watch(apiClientProvider)),
);

/// One goals sync. Each step is saved as it happens, so an interrupted sync
/// never uploads the same goal twice.
Future<void> syncGoals(Ref ref, AuthSession session) async {
  final api = ref.read(goalsApiProvider);
  final repo = ref.read(goalsRepositoryProvider);
  final controller = ref.read(goalsProvider.notifier);
  final token = session.token;

  // A different account signed in: forget goals that belonged to the old one.
  final previousAccount = repo.loadAccountId();
  if (previousAccount != null && previousAccount != session.user.id) {
    await controller.dropPreviousAccountData();
  }

  // Deletions made here.
  for (final remoteId in controller.pendingDeletes) {
    await api.delete(token, remoteId);
    await controller.clearPendingDelete(remoteId);
  }

  final remote = await api.list(token);
  final remoteById = {for (final goal in remote) goal.remoteId!: goal};
  final handled = <String>{};

  for (final local in [...ref.read(goalsProvider)]) {
    final remoteId = local.remoteId;

    if (remoteId == null) {
      // Only on this device: upload it.
      final created = await api.create(token, local);
      await controller.linkRemote(local.id, created, sentAt: local.updatedAt);
      handled.add(created.remoteId!);
      continue;
    }

    handled.add(remoteId);
    final server = remoteById[remoteId];
    if (server == null) {
      // Deleted elsewhere.
      await controller.removeLocal(local.id);
    } else if (local.dirty && local.updatedAt.isAfter(server.updatedAt)) {
      // Changed here more recently: send it.
      try {
        final replaced = await api.replace(token, remoteId, local);
        await controller.linkRemote(local.id, replaced, sentAt: local.updatedAt);
      } on ApiException catch (error) {
        // 409: the account changed first. The next sync pulls its version.
        if (error.status != 409) rethrow;
      }
    } else if (server.updatedAt.isAfter(local.updatedAt)) {
      // Changed elsewhere more recently: take it.
      await controller.applyRemote(local.id, server, seenAt: local.updatedAt);
    } else if (local.dirty) {
      await controller.markClean(local.id, seenAt: local.updatedAt);
    }
  }

  // Only on the account: add it here.
  for (final server in remote) {
    if (!handled.contains(server.remoteId)) {
      await controller.addFromRemote(server);
    }
  }

  await repo.saveAccountId(session.user.id);
}
