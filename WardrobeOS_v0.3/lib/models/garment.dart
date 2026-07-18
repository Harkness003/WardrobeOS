class Garment {
  final String id;
  final String name;
  final String category;
  final String? brand;
  final String? color;
  final String? material;
  final String? season;
  final String? style;
  final String? occasion;
  final String? condition;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final int wearCount;
  final DateTime? lastWorn;
  final String? size;
  final String? fit;
  final String? composition;
  final String? notes;
  final String? imagePath;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Garment({
    required this.id,
    required this.name,
    required this.category,
    this.brand,
    this.color,
    this.material,
    this.season,
    this.style,
    this.occasion,
    this.condition,
    this.purchasePrice,
    this.purchaseDate,
    this.wearCount = 0,
    this.lastWorn,
    this.size,
    this.fit,
    this.composition,
    this.notes,
    this.imagePath,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Garment copyWith({
    String? id,
    String? name,
    String? category,
    String? brand,
    String? color,
    String? material,
    String? season,
    String? style,
    String? occasion,
    String? condition,
    double? purchasePrice,
    DateTime? purchaseDate,
    int? wearCount,
    DateTime? lastWorn,
    String? size,
    String? fit,
    String? composition,
    String? notes,
    String? imagePath,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Garment(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    brand: brand ?? this.brand,
    color: color ?? this.color,
    material: material ?? this.material,
    season: season ?? this.season,
    style: style ?? this.style,
    occasion: occasion ?? this.occasion,
    condition: condition ?? this.condition,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    wearCount: wearCount ?? this.wearCount,
    lastWorn: lastWorn ?? this.lastWorn,
    size: size ?? this.size,
    fit: fit ?? this.fit,
    composition: composition ?? this.composition,
    notes: notes ?? this.notes,
    imagePath: imagePath ?? this.imagePath,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'brand': brand,
    'color': color,
    'material': material,
    'season': season,
    'style': style,
    'occasion': occasion,
    'condition': condition,
    'purchase_price': purchasePrice,
    'purchase_date': purchaseDate?.toIso8601String(),
    'wear_count': wearCount,
    'last_worn': lastWorn?.toIso8601String(),
    'size': size,
    'fit': fit,
    'composition': composition,
    'notes': notes,
    'image_path': imagePath,
    'is_favorite': isFavorite ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Garment.fromMap(Map<String, Object?> map) => Garment(
    id: map['id'] as String,
    name: map['name'] as String,
    category: map['category'] as String,
    brand: map['brand'] as String?,
    color: map['color'] as String?,
    material: map['material'] as String?,
    season: map['season'] as String?,
    style: map['style'] as String?,
    occasion: map['occasion'] as String?,
    condition: map['condition'] as String?,
    purchasePrice: (map['purchase_price'] as num?)?.toDouble(),
    purchaseDate: _parseDate(map['purchase_date']),
    wearCount: (map['wear_count'] as int?) ?? 0,
    lastWorn: _parseDate(map['last_worn']),
    size: map['size'] as String?,
    fit: map['fit'] as String?,
    composition: map['composition'] as String?,
    notes: map['notes'] as String?,
    imagePath: map['image_path'] as String?,
    isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );

  static DateTime? _parseDate(Object? value) {
    final text = value as String?;
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
