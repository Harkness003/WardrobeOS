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
  final List<Map<String, Object?>> userMemories;
  final List<Map<String, Object?>> userMemoryRevisions;
  final List<Map<String, Object?>> personalGoals;
  final List<Map<String, Object?>> styleProfiles;

  const BackupFile({
    required this.version,
    required this.createdAt,
    required this.garments,
    required this.images,
    required this.outfits,
    required this.outfitItems,
    required this.wishlist,
    required this.wearHistory,
    this.userMemories = const [],
    this.userMemoryRevisions = const [],
    this.personalGoals = const [],
    this.styleProfiles = const [],
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
    'userMemories': userMemories,
    'userMemoryRevisions': userMemoryRevisions,
    'personalGoals': personalGoals,
    'styleProfiles': styleProfiles,
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
    final createdAt = DateTime.tryParse(document['createdAt'] as String? ?? '');
    if (createdAt == null) {
      throw const BackupFormatException('La date de sauvegarde est invalide.');
    }

    List<Map<String, Object?>> rows(String key) {
      final value = document[key];
      if (value is! List) {
        throw BackupFormatException('Section « $key » invalide.');
      }
      return value
          .map((row) {
            if (row is! Map) {
              throw BackupFormatException('Entrée « $key » invalide.');
            }
            return row.map((key, value) => MapEntry(key.toString(), value));
          })
          .toList(growable: false);
    }

    List<Map<String, Object?>> optionalRows(String key) =>
        document.containsKey(key) ? rows(key) : const [];

    return BackupFile(
      version: version as int,
      createdAt: createdAt,
      garments: rows('garments'),
      images: rows('images'),
      outfits: rows('outfits'),
      outfitItems: rows('outfitItems'),
      wishlist: rows('wishlist'),
      wearHistory: rows('wearHistory'),
      userMemories: optionalRows('userMemories'),
      userMemoryRevisions: optionalRows('userMemoryRevisions'),
      personalGoals: optionalRows('personalGoals'),
      styleProfiles: optionalRows('styleProfiles'),
    );
  }
}
