import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../goals/goal_models.dart';
import '../goals/goals_providers.dart';
import '../goals/streaks.dart';
import 'ai_api.dart';

/// A button on the goal screen that asks the AI coach for a short note.
class EncourageCard extends ConsumerStatefulWidget {
  const EncourageCard({super.key, required this.goal});

  final Goal goal;

  @override
  ConsumerState<EncourageCard> createState() => _EncourageCardState();
}

class _EncourageCardState extends ConsumerState<EncourageCard> {
  bool _loading = false;
  String? _note;
  String? _error;

  Future<void> _ask(String token) async {
    final goal = widget.goal;
    final today = dateKey(ref.read(clockProvider)());
    final streaks = computeStreaks(goal.checkIns, today);
    final recent = [for (var i = 13; i >= 0; i--) addDays(today, -i)];
    final progress = GoalProgress(
      title: goal.title,
      categoryId: goal.categoryId,
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
      checkInsLast14Days: recent.where(goal.checkIns.contains).length,
      milestonesDone: goal.milestonesDone,
      milestonesTotal: goal.milestones.length,
      checkedInToday: goal.checkedIn(today),
    );

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final note = await ref.read(aiApiProvider).encourage(token, progress);
      if (!mounted) return;
      setState(() {
        _note = note;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = aiErrorMessage(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(currentSessionProvider);

    if (session == null) {
      return Text(
        'Sign in for AI encouragement',
        style: theme.textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_note != null)
          Card(
            elevation: 0,
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_note!, style: theme.textTheme.bodyLarge),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _loading ? null : () => _ask(session.token),
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_note == null ? 'Encourage me' : 'Another note'),
        ),
        const SizedBox(height: 4),
        Text(aiPrivacyNote, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
