import '../../../models/garment.dart';

class OutfitCandidate {
  final Garment? sourceGarment;
  final String id;
  final String name;
  final String category;
  final String? color;
  final String? season;
  final int wearCount;
  final DateTime? lastWorn;
  final bool isAvailable;

  const OutfitCandidate({
    this.sourceGarment,
    required this.id,
    required this.name,
    required this.category,
    this.color,
    this.season,
    this.wearCount = 0,
    this.lastWorn,
    this.isAvailable = true,
  });

  Garment get garment => sourceGarment ?? Garment(
    id: id,
    name: name,
    category: category,
    color: color,
    season: season,
    wearCount: wearCount,
    lastWorn: lastWorn,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  factory OutfitCandidate.fromGarment(Garment garment) => OutfitCandidate(
    sourceGarment: garment,
    id: garment.id,
    name: garment.name,
    category: garment.category,
    color: garment.color,
    season: garment.effectiveSeasons.join(', '),
    wearCount: garment.wearCount,
    lastWorn: garment.lastWorn,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'nom': name,
    'catégorie': category,
    'couleur': color,
    'styleAnalysis': sourceGarment == null ? null : {
      'registre': sourceGarment!.effectiveStyleAnalysis.register,
      'stylesSecondaires': sourceGarment!.effectiveStyleAnalysis.secondaryStyles,
      'caractéristiques': sourceGarment!.effectiveStyleAnalysis.characteristics,
    },
    'profilThermiqueEffectif':
        sourceGarment?.effectiveThermalProfile.toJson(),
    'niveauFormalité': sourceGarment?.niveauFormalite,
    'occasions': sourceGarment?.effectiveOccasions,
    'couleursCompatibles': sourceGarment?.couleursCompatibles,
    'couleursMoinsAdaptées': sourceGarment?.couleursMoinsAdaptees,
    'fréquenceDePort': wearCount,
    'dernièreUtilisation': lastWorn?.toIso8601String(),
  };
}
