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

  factory WearHistory.fromMap(Map<String, Object?> map) {
    final id = map['id'];
    final garmentId = map['garment_id'];
    return WearHistory(
      id: id is num ? id.toInt() : null,
      garmentId: garmentId is String ? garmentId : '',
      wornAt: _date(map['worn_at']),
      createdAt: _date(map['created_at']),
    );
  }

  static DateTime _date(Object? value) =>
      value is String
          ? DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0);
}
