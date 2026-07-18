import '../../../models/garment.dart';

class OutfitCandidate {
  final String id;
  final String name;
  final String category;
  final String? color;
  final String? season;
  final int wearCount;
  final DateTime? lastWorn;
  final bool isAvailable;

  const OutfitCandidate({
    required this.id,
    required this.name,
    required this.category,
    this.color,
    this.season,
    this.wearCount = 0,
    this.lastWorn,
    this.isAvailable = true,
  });

  factory OutfitCandidate.fromGarment(Garment garment) => OutfitCandidate(
    id: garment.id,
    name: garment.name,
    category: garment.category,
    color: garment.color,
    season: garment.season,
    wearCount: garment.wearCount,
    lastWorn: garment.lastWorn,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'nom': name,
    'catégorie': category,
    'couleur': color,
    'saison': season,
    'fréquenceDePort': wearCount,
    'dernièreUtilisation': lastWorn?.toIso8601String(),
  };
}
