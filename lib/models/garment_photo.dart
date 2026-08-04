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
    try {
      return decodeStrict(value);
    } on FormatException {
      return const [];
    }
  }

  /// Decodes persisted canonical photos without accepting malformed or legacy
  /// representations. Backup/restore uses this variant to prevent data loss.
  static List<GarmentPhoto> decodeStrict(Object? value) {
    if (value is! String) throw const FormatException('photos must be JSON');
    if (value.isEmpty) throw const FormatException('photos must not be empty');
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List || decoded.any((item) => item is! Map)) {
        throw const FormatException('photos must be a list of objects');
      }
      return List.unmodifiable(decoded.cast<Map>().map((item) =>
          GarmentPhoto.fromJson(item.cast<String, Object?>())));
    } on JsonUnsupportedObjectError {
      throw const FormatException('photos are invalid');
    }
  }
}
