import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import 'goal_models.dart';
import 'goals_providers.dart';
import 'streaks.dart';

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  static String _statusLabel(GoalStatus status) {
    switch (status) {
      case GoalStatus.active:
        return 'Active';
      case GoalStatus.completed:
        return 'Completed';
      case GoalStatus.archived:
        return 'Archived';
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: const Text(
          'Its check-ins and milestones will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(goalsProvider.notifier).delete(goal.id);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goal = ref.watch(goalProvider(goalId));
    final today = dateKey(ref.watch(clockProvider)());

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Goal')),
        body: const Center(child: Text('This goal could not be found.')),
      );
    }

    final notifier = ref.read(goalsProvider.notifier);
    final streaks = computeStreaks(goal.checkIns, today);
    final checkedInToday = goal.checkedIn(today);
    final target = goal.targetDate;
    final overdue =
        goal.isActive && target != null && target.compareTo(today) < 0;
    final recent = [for (var i = 13; i >= 0; i--) addDays(today, -i)];
    final recentCount = recent.where(goal.checkIns.contains).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal'),
        actions: [
          IconButton(
            tooltip: 'Edit goal',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppRoutes.goalEditPath(goal.id)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(goal.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text(goal.categoryLabel)),
              if (!goal.isActive) Chip(label: Text(_statusLabel(goal.status))),
            ],
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(goal.description, style: theme.textTheme.bodyLarge),
          ],
          if (target != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
                  size: 20,
                  color: overdue ? scheme.error : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  overdue
                      ? 'Overdue: ${formatDateKey(target)}'
                      : 'Target: ${formatDateKey(target)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('Daily action', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            goal.dailyAction.isEmpty ? 'No daily action set' : goal.dailyAction,
            style: theme.textTheme.bodyMedium,
          ),
          if (goal.isActive) ...[
            const SizedBox(height: 12),
            checkedInToday
                ? OutlinedButton.icon(
                    onPressed: () => notifier.undoCheckIn(goal.id),
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo check-in'),
                  )
                : FilledButton.icon(
                    onPressed: () => notifier.checkIn(goal.id),
                    icon: const Icon(Icons.check),
                    label: const Text('Check in for today'),
                  ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(value: '${streaks.current}', label: 'Current streak'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(value: '${streaks.longest}', label: 'Longest streak'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Checked in on $recentCount of the last 14 days',
            child: ExcludeSemantics(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final day in recent)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: goal.checkIns.contains(day)
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        border: day == today
                            ? Border.all(color: scheme.primary, width: 2)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (goal.milestones.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Milestones (${goal.milestonesDone} of ${goal.milestones.length})',
              style: theme.textTheme.titleMedium,
            ),
            for (final milestone in goal.milestones)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: milestone.done,
                title: Text(milestone.title),
                onChanged: (_) => notifier.toggleMilestone(goal.id, milestone.id),
              ),
          ],
          const SizedBox(height: 24),
          if (goal.isActive) ...[
            FilledButton.tonal(
              onPressed: () => notifier.setStatus(goal.id, GoalStatus.completed),
              child: const Text('Mark as completed'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => notifier.setStatus(goal.id, GoalStatus.archived),
              child: const Text('Archive'),
            ),
          ] else
            FilledButton.tonal(
              onPressed: () => notifier.setStatus(goal.id, GoalStatus.active),
              child: const Text('Reopen goal'),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _confirmDelete(context, ref, goal),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Delete goal'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.headlineMedium),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
