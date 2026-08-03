enum PersonalGoalStatus { active, achieved, paused, abandoned }

class PersonalGoal {
  final String id;
  final String title;
  final String? details;
  final double priority;
  final PersonalGoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalGoal({
    required this.id,
    required this.title,
    this.details,
    this.priority = .5,
    this.status = PersonalGoalStatus.active,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(priority >= 0 && priority <= 1);

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'details': details,
    'priority': priority,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory PersonalGoal.fromMap(Map<String, Object?> map) => PersonalGoal(
    id: map['id'] as String,
    title: map['title'] as String,
    details: map['details'] as String?,
    priority: (map['priority'] as num?)?.toDouble() ?? .5,
    status: PersonalGoalStatus.values.byName(
      map['status'] as String? ?? PersonalGoalStatus.active.name,
    ),
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}
