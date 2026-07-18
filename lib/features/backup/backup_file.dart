import 'dart:convert';

class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

class BackupFile {
  static const currentVersion = 1;

  final int version;
  final DateTime createdAt;
  final List<Map<String, Object?>> garments;
  final List<Map<String, Object?>> images;
  final List<Map<String, Object?>> outfits;
  final List<Map<String, Object?>> outfitItems;
  final List<Map<String, Object?>> wishlist;
  final List<Map<String, Object?>> wearHistory;

  const BackupFile({
    required this.version,
    required this.createdAt,
    required this.garments,
    required this.images,
    required this.outfits,
    required this.outfitItems,
    required this.wishlist,
    required this.wearHistory,
  });

  Map<String, Object?> toJson() => {
    'version': version,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'garments': garments,
    'images': images,
    'outfits': outfits,
    'outfitItems': outfitItems,
    'wishlist': wishlist,
    'wearHistory': wearHistory,
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory BackupFile.decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const BackupFormatException('Le fichier JSON est invalide.');
    }
    if (decoded is! Map<String, Object?>) {
      throw const BackupFormatException(
        'Le contenu de la sauvegarde est invalide.',
      );
    }
    final document = decoded;
    final version = document['version'];
    if (version != currentVersion) {
      throw BackupFormatException(
        'Version de sauvegarde non prise en charge : $version.',
      );
    }
    final createdAt = DateTime.tryParse(
      document['createdAt'] as String? ?? '',
    );
    if (createdAt == null) {
      throw const BackupFormatException('La date de sauvegarde est invalide.');
    }

    List<Map<String, Object?>> rows(String key) {
      final value = document[key];
      if (value is! List) {
        throw BackupFormatException('Section « $key » invalide.');
      }
      return value.map((row) {
        if (row is! Map) {
          throw BackupFormatException('Entrée « $key » invalide.');
        }
        return row.map((key, value) => MapEntry(key.toString(), value));
      }).toList(growable: false);
    }

    return BackupFile(
      version: version as int,
      createdAt: createdAt,
      garments: rows('garments'),
      images: rows('images'),
      outfits: rows('outfits'),
      outfitItems: rows('outfitItems'),
      wishlist: rows('wishlist'),
      wearHistory: rows('wearHistory'),
    );
  }
}
