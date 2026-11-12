import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/quote_category.dart';
import 'goal_models.dart';
import 'goals_providers.dart';
import 'streaks.dart';

class _MilestoneDraft {
  _MilestoneDraft({required this.id, required String title, required this.done})
      : controller = TextEditingController(text: title);

  final String id;
  final bool done;
  final TextEditingController controller;
}

/// Creates a goal, or edits one when [goalId] is given.
class GoalEditScreen extends ConsumerStatefulWidget {
  const GoalEditScreen({super.key, this.goalId});

  final String? goalId;

  @override
  ConsumerState<GoalEditScreen> createState() => _GoalEditScreenState();
}

class _GoalEditScreenState extends ConsumerState<GoalEditScreen> {
  static const int _maxMilestones = 20;

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _dailyAction = TextEditingController();
  final List<_MilestoneDraft> _milestones = [];

  String _categoryId = QuoteCategory.growth.id;
  String? _targetDate;
  bool _missing = false;
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    final id = widget.goalId;
    if (id == null) return;
    final goal = ref.read(goalProvider(id));
    if (goal == null) {
      _missing = true;
      return;
    }
    _title.text = goal.title;
    _description.text = goal.description;
    _dailyAction.text = goal.dailyAction;
    _categoryId = goal.categoryId;
    _targetDate = goal.targetDate;
    for (final milestone in goal.milestones) {
      _milestones.add(
        _MilestoneDraft(id: milestone.id, title: milestone.title, done: milestone.done),
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _dailyAction.dispose();
    for (final draft in _milestones) {
      draft.controller.dispose();
    }
    super.dispose();
  }

  String _newMilestoneId() =>
      'm${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  String? _maxLength(String? value, int max) =>
      (value ?? '').trim().length > max ? 'Use at most $max characters' : null;

  String? _validateTitle(String? value) {
    final title = (value ?? '').trim();
    if (title.isEmpty) return 'Enter a title';
    return _maxLength(title, 100);
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final todayLocal = DateTime(now.year, now.month, now.day);
    final current = _targetDate == null ? null : parseDateKey(_targetDate!);
    final initial = current == null
        ? todayLocal
        : DateTime(current.year, current.month, current.day);
    final first = initial.isBefore(todayLocal) ? initial : todayLocal;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _targetDate = dateKey(picked));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(goalsProvider.notifier);
    final milestones = [
      for (final draft in _milestones)
        if (draft.controller.text.trim().isNotEmpty)
          Milestone(
            id: draft.id,
            title: draft.controller.text.trim(),
            done: draft.done,
          ),
    ];
    final existing =
        widget.goalId == null ? null : ref.read(goalProvider(widget.goalId!));

    if (existing == null) {
      final id = await notifier.create(
        title: _title.text.trim(),
        description: _description.text.trim(),
        categoryId: _categoryId,
        targetDate: _targetDate,
        dailyAction: _dailyAction.text.trim(),
        milestones: milestones,
      );
      if (!mounted) return;
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can have at most 100 goals.')),
        );
        return;
      }
    } else {
      await notifier.update(
        existing.copyWith(
          title: _title.text.trim(),
          description: _description.text.trim(),
          categoryId: _categoryId,
          targetDate: _targetDate,
          clearTargetDate: _targetDate == null,
          dailyAction: _dailyAction.text.trim(),
          milestones: milestones,
        ),
      );
      if (!mounted) return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.goalId != null;

    if (_missing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit goal')),
        body: const Center(child: Text('This goal could not be found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit goal' : 'New goal')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: _validateTitle,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => _maxLength(value, 500),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final category in QuoteCategory.values)
                  DropdownMenuItem(value: category.id, child: Text(category.label)),
              ],
              onChanged: (value) =>
                  setState(() => _categoryId = value ?? _categoryId),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dailyAction,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Daily action (optional)',
                hintText: 'For example: Read for 20 minutes',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _maxLength(value, 100),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                _targetDate == null
                    ? 'Target date (optional)'
                    : 'Target: ${formatDateKey(_targetDate!)}',
              ),
              trailing: _targetDate == null
                  ? null
                  : IconButton(
                      tooltip: 'Clear date',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _targetDate = null),
                    ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            Text('Milestones', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < _milestones.length; i++)
              Padding(
                key: ValueKey(_milestones[i].id),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _milestones[i].controller,
                        decoration: InputDecoration(
                          labelText: 'Milestone ${i + 1}',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => _maxLength(value, 100),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove milestone ${i + 1}',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() {
                        _milestones.removeAt(i).controller.dispose();
                      }),
                    ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: _milestones.length >= _maxMilestones
                  ? null
                  : () => setState(() {
                        _milestones.add(
                          _MilestoneDraft(
                            id: _newMilestoneId(),
                            title: '',
                            done: false,
                          ),
                        );
                      }),
              icon: const Icon(Icons.add),
              label: const Text('Add milestone'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save goal')),
          ],
        ),
      ),
    );
  }
}
