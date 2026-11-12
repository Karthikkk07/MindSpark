import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/goals/goal_models.dart';

/// Stores the user's goals on the device.
class GoalsRepository {
  GoalsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const keyGoals = 'goals_v1';

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
}
