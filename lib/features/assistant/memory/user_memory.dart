enum UserMemoryKind { declarative, behavioral }

enum UserMemoryStatus { active, archived }

/// A fact or a fallible observation used to personalize WardrobeGPT.
class UserMemory {
  final String id;
  final UserMemoryKind kind;
  final String topic;
  final String statement;
  final double confidence;
  final int evidenceCount;
  final UserMemoryStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserMemory({
    required this.id,
    required this.kind,
    required this.topic,
    required this.statement,
    required this.confidence,
    this.evidenceCount = 1,
    this.status = UserMemoryStatus.active,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(confidence >= 0 && confidence <= 1),
       assert(evidenceCount > 0);

  bool get isBehavioral => kind == UserMemoryKind.behavioral;

  UserMemory copyWith({
    String? statement,
    double? confidence,
    int? evidenceCount,
    UserMemoryStatus? status,
    DateTime? updatedAt,
  }) => UserMemory(
    id: id,
    kind: kind,
    topic: topic,
    statement: statement ?? this.statement,
    confidence: confidence ?? this.confidence,
    evidenceCount: evidenceCount ?? this.evidenceCount,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind.name,
    'topic': topic,
    'statement': statement,
    'confidence': confidence,
    'evidence_count': evidenceCount,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory UserMemory.fromMap(Map<String, Object?> map) => UserMemory(
    id: map['id'] as String,
    kind: UserMemoryKind.values.byName(map['kind'] as String),
    topic: map['topic'] as String,
    statement: map['statement'] as String,
    confidence: (map['confidence'] as num).toDouble(),
    evidenceCount: map['evidence_count'] as int? ?? 1,
    status: UserMemoryStatus.values.byName(
      map['status'] as String? ?? UserMemoryStatus.active.name,
    ),
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}

class UserMemoryRevision {
  final int? id;
  final String memoryId;
  final String statement;
  final double confidence;
  final DateTime recordedAt;

  const UserMemoryRevision({
    this.id,
    required this.memoryId,
    required this.statement,
    required this.confidence,
    required this.recordedAt,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'memory_id': memoryId,
    'statement': statement,
    'confidence': confidence,
    'recorded_at': recordedAt.toIso8601String(),
  };

  factory UserMemoryRevision.fromMap(Map<String, Object?> map) =>
      UserMemoryRevision(
        id: map['id'] as int?,
        memoryId: map['memory_id'] as String,
        statement: map['statement'] as String,
        confidence: (map['confidence'] as num).toDouble(),
        recordedAt: DateTime.parse(map['recorded_at'] as String),
      );
}
