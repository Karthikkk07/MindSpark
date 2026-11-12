import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import 'goal_models.dart';
import 'goals_providers.dart';
import 'streaks.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  GoalStatus _filter = GoalStatus.active;

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final today = dateKey(ref.watch(clockProvider)());
    final shown = goals.where((goal) => goal.status == _filter).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.goalNew),
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<GoalStatus>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: GoalStatus.active, label: Text('Active')),
                  ButtonSegment(
                    value: GoalStatus.completed,
                    label: Text('Completed'),
                  ),
                  ButtonSegment(
                    value: GoalStatus.archived,
                    label: Text('Archived'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (selection) =>
                    setState(() => _filter = selection.first),
              ),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? _EmptyState(filter: _filter)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: shown.length,
                    itemBuilder: (context, index) =>
                        _GoalCard(goal: shown[index], today: today),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.today});

  final Goal goal;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final streak = computeStreaks(goal.checkIns, today).current;
    final progress = goal.progress;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => context.push(AppRoutes.goalPath(goal.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(goal.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                goal.categoryLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (goal.dailyAction.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(goal.dailyAction, style: theme.textTheme.bodyMedium),
              ],
              if (progress != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 4),
                Text(
                  '${goal.milestonesDone} of ${goal.milestones.length} milestones',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 20,
                    color: streak > 0 ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      streak > 0 ? '$streak day streak' : 'No streak yet',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (goal.isActive)
                    (goal.checkedIn(today)
                        ? const Chip(
                            avatar: Icon(Icons.check, size: 18),
                            label: Text('Done today'),
                          )
                        : FilledButton.tonal(
                            onPressed: () => ref
                                .read(goalsProvider.notifier)
                                .checkIn(goal.id),
                            child: const Text('Check in'),
                          )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final GoalStatus filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title;
    final String? hint;
    switch (filter) {
      case GoalStatus.active:
        title = 'No active goals yet';
        hint = 'Tap New goal to set one.';
      case GoalStatus.completed:
        title = 'No completed goals yet';
        hint = null;
      case GoalStatus.archived:
        title = 'Nothing archived';
        hint = null;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
