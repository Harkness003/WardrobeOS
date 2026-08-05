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

class GarmentPhotoNormalizationReport {
  final List<GarmentPhoto> photos;
  final int removedEmptyPaths;
  final int repairedEmptyIds;
  final int removedDuplicateIds;
  final int removedDuplicatePaths;
  final bool promotedPrimary;
  final int demotedPrimaryCount;

  const GarmentPhotoNormalizationReport({
    required this.photos,
    this.removedEmptyPaths = 0,
    this.repairedEmptyIds = 0,
    this.removedDuplicateIds = 0,
    this.removedDuplicatePaths = 0,
    this.promotedPrimary = false,
    this.demotedPrimaryCount = 0,
  });

  bool get changed =>
      removedEmptyPaths > 0 ||
      repairedEmptyIds > 0 ||
      removedDuplicateIds > 0 ||
      removedDuplicatePaths > 0 ||
      promotedPrimary ||
      demotedPrimaryCount > 0;
}

class GarmentPhotoNormalizer {
  const GarmentPhotoNormalizer._();

  static GarmentPhotoNormalizationReport normalize(
    Iterable<GarmentPhoto> source,
  ) {
    final photos = <GarmentPhoto>[];
    final ids = <String>{};
    final paths = <String>{};
    var removedEmptyPaths = 0;
    var repairedEmptyIds = 0;
    var removedDuplicateIds = 0;
    var removedDuplicatePaths = 0;

    for (final photo in source) {
      final path = photo.path.trim();
      if (path.isEmpty) {
        removedEmptyPaths++;
        continue;
      }
      var id = photo.id.trim();
      if (id.isEmpty) {
        repairedEmptyIds++;
        do {
          id = 'photo-${photos.length + 1 + repairedEmptyIds}';
        } while (ids.contains(id));
      }
      if (!ids.add(id)) {
        removedDuplicateIds++;
        continue;
      }
      if (!paths.add(path)) {
        removedDuplicatePaths++;
        continue;
      }
      photos.add(GarmentPhoto(
        id: id,
        path: path,
        type: photo.type,
        createdAt: photo.createdAt,
        semanticType: photo.semanticType,
      ));
    }

    var primarySeen = false;
    var promotedPrimary = false;
    var demotedPrimaryCount = 0;
    final canonical = <GarmentPhoto>[];
    for (var index = 0; index < photos.length; index++) {
      final photo = photos[index];
      if (photo.type == GarmentPhotoType.primary) {
        if (!primarySeen) {
          primarySeen = true;
          canonical.add(photo);
        } else {
          demotedPrimaryCount++;
          canonical.add(GarmentPhoto(
            id: photo.id,
            path: photo.path,
            type: GarmentPhotoType.other,
            createdAt: photo.createdAt,
            semanticType: photo.semanticType,
          ));
        }
      } else if (index == 0 && !primarySeen) {
        promotedPrimary = true;
        primarySeen = true;
        canonical.add(GarmentPhoto(
          id: photo.id,
          path: photo.path,
          type: GarmentPhotoType.primary,
          createdAt: photo.createdAt,
          semanticType: photo.semanticType,
        ));
      } else {
        canonical.add(photo);
      }
    }

    return GarmentPhotoNormalizationReport(
      photos: List.unmodifiable(canonical),
      removedEmptyPaths: removedEmptyPaths,
      repairedEmptyIds: repairedEmptyIds,
      removedDuplicateIds: removedDuplicateIds,
      removedDuplicatePaths: removedDuplicatePaths,
      promotedPrimary: promotedPrimary,
      demotedPrimaryCount: demotedPrimaryCount,
    );
  }
}
