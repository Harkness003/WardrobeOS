class WearHistory {
  final int? id;
  final String garmentId;
  final DateTime wornAt;
  final DateTime createdAt;

  const WearHistory({
    this.id,
    required this.garmentId,
    required this.wornAt,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'garment_id': garmentId,
    'worn_at': wornAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  factory WearHistory.fromMap(Map<String, Object?> map) => WearHistory(
    id: map['id'] as int?,
    garmentId: map['garment_id'] as String,
    wornAt: DateTime.parse(map['worn_at'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
