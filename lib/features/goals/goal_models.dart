import '../../models/quote_category.dart';

enum GoalStatus { active, completed, archived }

class Milestone {
  const Milestone({required this.id, required this.title, this.done = false});

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
        id: json['id'] as String,
        title: json['title'] as String,
        done: json['done'] as bool? ?? false,
      );

  final String id;
  final String title;
  final bool done;

  Milestone copyWith({String? title, bool? done}) =>
      Milestone(id: id, title: title ?? this.title, done: done ?? this.done);

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.createdAt,
    this.description = '',
    this.targetDate,
    this.status = GoalStatus.active,
    this.completedAt,
    this.dailyAction = '',
    this.milestones = const <Milestone>[],
    this.checkIns = const <String>[],
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    final checkIns = ((json['checkIns'] as List<dynamic>?) ?? const [])
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return Goal(
      id: json['id'] as String,
      title: json['title'] as String,
      categoryId: json['categoryId'] as String,
      description: json['description'] as String? ?? '',
      targetDate: json['targetDate'] as String?,
      status: GoalStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => GoalStatus.active,
      ),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      dailyAction: json['dailyAction'] as String? ?? '',
      milestones: ((json['milestones'] as List<dynamic>?) ?? const [])
          .map((item) => Milestone.fromJson(item as Map<String, dynamic>))
          .toList(),
      checkIns: checkIns,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String title;
  final String description;
  final String categoryId;

  /// A calendar date (YYYY-MM-DD), or null.
  final String? targetDate;
  final GoalStatus status;
  final DateTime? completedAt;

  /// What to do each day, for example "Read for 20 minutes".
  final String dailyAction;
  final List<Milestone> milestones;

  /// Days the daily action was done (YYYY-MM-DD), oldest first.
  final List<String> checkIns;
  final DateTime createdAt;

  bool get isActive => status == GoalStatus.active;

  String get categoryLabel =>
      QuoteCategory.fromId(categoryId)?.label ?? categoryId;

  int get milestonesDone => milestones.where((m) => m.done).length;

  /// 0 to 1, or null when the goal has no milestones.
  double? get progress =>
      milestones.isEmpty ? null : milestonesDone / milestones.length;

  bool checkedIn(String today) => checkIns.contains(today);

  Goal copyWith({
    String? title,
    String? description,
    String? categoryId,
    String? targetDate,
    bool clearTargetDate = false,
    GoalStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? dailyAction,
    List<Milestone>? milestones,
    List<String>? checkIns,
  }) {
    return Goal(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      dailyAction: dailyAction ?? this.dailyAction,
      milestones: milestones ?? this.milestones,
      checkIns: checkIns ?? this.checkIns,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'categoryId': categoryId,
        'targetDate': targetDate,
        'status': status.name,
        'completedAt': completedAt?.toIso8601String(),
        'dailyAction': dailyAction,
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'checkIns': checkIns,
        'createdAt': createdAt.toIso8601String(),
      };
}
