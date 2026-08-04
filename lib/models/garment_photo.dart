import 'dart:convert';

/// Semantic role of an image. Unknown future values are preserved as [other].
enum GarmentPhotoType {
  primary,
  composition,
  detail,
  interior,
  sole,
  lining,
  wear,
  other;

  static GarmentPhotoType parse(String? value) => values.firstWhere(
        (type) => type.name == value,
        orElse: () => GarmentPhotoType.other,
      );
}

class GarmentPhoto {
  final String id;
  final String path;
  final GarmentPhotoType type;
  final DateTime createdAt;
  final String? semanticType;

  const GarmentPhoto({
    required this.id,
    required this.path,
    required this.type,
    required this.createdAt,
    this.semanticType,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'path': path,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        if (semanticType != null) 'semanticType': semanticType,
      };

  factory GarmentPhoto.fromJson(Map<String, Object?> json) => GarmentPhoto(
        id: json['id']?.toString() ?? '',
        path: json['path']?.toString() ?? '',
        type: GarmentPhotoType.parse(json['type']?.toString()),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        semanticType: json['semanticType']?.toString(),
      );

  static String encode(List<GarmentPhoto> photos) =>
      jsonEncode(photos.map((photo) => photo.toJson()).toList());

  static List<GarmentPhoto> decode(Object? value) {
    if (value is! String || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const [];
      return List.unmodifiable(decoded.whereType<Map>().map((item) =>
          GarmentPhoto.fromJson(item.cast<String, Object?>())));
    } on FormatException {
      return const [];
    }
  }
}
