import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/goals/goal_models.dart';

/// Stores the user's goals, and what sync needs to remember, on the device.
class GoalsRepository {
  GoalsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const keyGoals = 'goals_v1';

  /// Account ids of goals deleted here that the account still has.
  static const keyPendingDeletes = 'goals_pending_deletes';

  /// The account the synced goals on this device belong to.
  static const keyAccountId = 'goals_account_id';

  /// Reads all goals. Damaged entries are skipped instead of failing.
  List<Goal> load() {
    final raw = _prefs.getString(keyGoals);
    if (raw == null) return const [];
    try {
      final items = jsonDecode(raw) as List<dynamic>;
      final goals = <Goal>[];
      for (final item in items) {
        try {
          goals.add(Goal.fromJson(item as Map<String, dynamic>));
        } catch (_) {
          // Skip this entry and keep the rest.
        }
      }
      return goals;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<Goal> goals) => _prefs.setString(
        keyGoals,
        jsonEncode(goals.map((goal) => goal.toJson()).toList()),
      );

  Set<String> loadPendingDeletes() =>
      (_prefs.getStringList(keyPendingDeletes) ?? const <String>[]).toSet();

  Future<void> savePendingDeletes(Set<String> ids) =>
      _prefs.setStringList(keyPendingDeletes, ids.toList()..sort());

  String? loadAccountId() => _prefs.getString(keyAccountId);

  Future<void> saveAccountId(String id) => _prefs.setString(keyAccountId, id);
}
