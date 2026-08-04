import 'dart:convert';

/// Stable identifiers used by persistence and future style-library screens.
abstract final class StyleTaxonomy {
  static const version = 1;
  static const registers = <String>{
    'casual', 'smart_casual', 'dressy', 'sport', 'technical',
  };
  static const secondaryStyles = <String>{
    'minimalist', 'workwear', 'streetwear', 'preppy', 'vintage', 'rock',
    'outdoor',
  };
  static const characteristics = <String>{
    'understated', 'structured', 'modern', 'retro', 'elegant', 'utility',
  };

  /// Canonical metadata keyed by the stable identifiers stored in
  /// [StyleAnalysis]. UI code must resolve labels through this map rather than
  /// maintaining its own lists.
  static const entries = <String, StyleDefinition>{
    'casual': StyleDefinition(id: 'casual', name: 'Décontracté', definition: 'Une allure confortable et simple pour le quotidien.', description: 'Des pièces faciles à porter, souples et peu formelles.', synonyms: ['casual', 'quotidien'], characteristics: ['confortable', 'simple', 'polyvalent'], colors: ['denim', 'neutres'], materials: ['coton', 'maille'], occasions: ['quotidien', 'week-end'], typicalPieces: ['jean', 't-shirt', 'baskets'], relatedStyleIds: ['smart_casual']),
    'smart_casual': StyleDefinition(id: 'smart_casual', name: 'Chic décontracté', definition: 'L’équilibre entre décontraction et élégance.', description: 'Une silhouette quotidienne soignée sans les codes stricts du formel.', synonyms: ['smart casual', 'casual chic'], characteristics: ['soigné', 'polyvalent', 'moderne'], colors: ['marine', 'beige', 'blanc'], materials: ['coton', 'laine'], occasions: ['bureau', 'sortie'], typicalPieces: ['chino', 'blazer souple', 'mocassins'], relatedStyleIds: ['casual', 'dressy']),
    'dressy': StyleDefinition(id: 'dressy', name: 'Habillé', definition: 'Une tenue élégante pensée pour les occasions formelles.', description: 'Des lignes nettes, des finitions raffinées et une silhouette structurée.', synonyms: ['formel', 'élégant'], characteristics: ['elegant', 'structured'], colors: ['noir', 'marine'], materials: ['laine', 'soie'], occasions: ['cérémonie', 'soirée'], typicalPieces: ['costume', 'robe', 'souliers'], oppositeStyleIds: ['sport']),
    'sport': StyleDefinition(id: 'sport', name: 'Sport', definition: 'Une esthétique inspirée des vêtements d’activité.', description: 'Le confort, la liberté de mouvement et les détails athlétiques dominent.', synonyms: ['sportif', 'athleisure'], characteristics: ['confortable', 'dynamique'], materials: ['jersey', 'mesh'], occasions: ['sport', 'loisirs'], typicalPieces: ['jogging', 'sweat', 'baskets'], oppositeStyleIds: ['dressy']),
    'technical': StyleDefinition(id: 'technical', name: 'Technique', definition: 'Un style fonctionnel fondé sur la performance.', description: 'Matières protectrices, détails utilitaires et construction adaptée aux éléments.', synonyms: ['techwear', 'fonctionnel'], characteristics: ['utility', 'modern'], materials: ['ripstop', 'membrane'], occasions: ['extérieur', 'voyage'], typicalPieces: ['shell', 'pantalon cargo'], relatedStyleIds: ['outdoor']),
    'minimalist': StyleDefinition(id: 'minimalist', name: 'Minimaliste', definition: 'Une esthétique épurée qui privilégie l’essentiel.', description: 'Peu de détails, palette maîtrisée et lignes lisibles.', synonyms: ['minimal', 'épuré'], characteristics: ['understated', 'modern'], colors: ['blanc', 'noir', 'beige'], materials: ['coton', 'laine'], occasions: ['quotidien', 'bureau'], typicalPieces: ['chemise nette', 'pantalon droit']),
    'workwear': StyleDefinition(id: 'workwear', name: 'Workwear', definition: 'Un style robuste inspiré des vêtements de travail.', description: 'Coupes pratiques, poches et matières résistantes.', synonyms: ['ouvrier', 'utilitaire'], characteristics: ['utility', 'structured'], materials: ['denim', 'toile'], typicalPieces: ['surchemise', 'pantalon carpenter'], relatedStyleIds: ['outdoor']),
    'streetwear': StyleDefinition(id: 'streetwear', name: 'Streetwear', definition: 'Une culture vestimentaire urbaine, expressive et confortable.', description: 'Volumes amples, références sport et culture graphique.', synonyms: ['urbain', 'street'], characteristics: ['modern'], typicalPieces: ['hoodie', 'sneakers', 'cargo'], relatedStyleIds: ['sport']),
    'preppy': StyleDefinition(id: 'preppy', name: 'Preppy', definition: 'Une allure soignée inspirée des campus classiques.', description: 'Mailles, chemises et références sportives traditionnelles.', synonyms: ['college', 'ivy'], characteristics: ['structured', 'elegant'], typicalPieces: ['polo', 'cardigan', 'chino']),
    'vintage': StyleDefinition(id: 'vintage', name: 'Vintage', definition: 'Un style nourri de silhouettes et détails d’époques passées.', description: 'Pièces anciennes ou réinterprétées, patine et références historiques.', synonyms: ['rétro', 'ancien'], characteristics: ['retro'], typicalPieces: ['veste rétro', 'jean taille haute']),
    'rock': StyleDefinition(id: 'rock', name: 'Rock', definition: 'Une esthétique affirmée issue des cultures musicales rock.', description: 'Contrastes sombres, cuir, denim et détails métalliques.', synonyms: ['rocker'], characteristics: ['affirmé'], colors: ['noir', 'rouge'], materials: ['cuir', 'denim'], typicalPieces: ['perfecto', 'boots']),
    'outdoor': StyleDefinition(id: 'outdoor', name: 'Plein air', definition: 'Un style pratique inspiré des activités extérieures.', description: 'Superposition, résistance et confort climatique.', synonyms: ['randonnée', 'gorpcore'], characteristics: ['utility'], materials: ['polaire', 'ripstop'], occasions: ['extérieur', 'voyage'], typicalPieces: ['polaire', 'parka'], relatedStyleIds: ['technical']),
  };
}

class StyleDefinition {
  final String id, name, definition, description;
  final List<String> synonyms, characteristics, colors, materials, occasions,
      typicalPieces, relatedStyleIds, oppositeStyleIds;
  const StyleDefinition({required this.id, required this.name,
    required this.definition, required this.description, this.synonyms = const [],
    this.characteristics = const [], this.colors = const [], this.materials = const [],
    this.occasions = const [], this.typicalPieces = const [],
    this.relatedStyleIds = const [], this.oppositeStyleIds = const []});
}

/// Versioned, explainable stylistic result. AI values and user decisions are
/// deliberately separate: recomputation only replaces the suggestion layer.
class StyleAnalysis {
  static const currentModelVersion = 'style-v1';

  final int taxonomyVersion;
  final String modelVersion;
  final String inputFingerprint;
  final String suggestedRegister;
  final List<String> suggestedSecondaryStyles;
  final List<String> suggestedCharacteristics;
  final String? userRegister;
  final List<String>? userSecondaryStyles;
  final List<String>? userCharacteristics;
  final List<String> evidence;
  final DateTime calculatedAt;

  const StyleAnalysis({
    this.taxonomyVersion = StyleTaxonomy.version,
    this.modelVersion = currentModelVersion,
    required this.inputFingerprint,
    required this.suggestedRegister,
    this.suggestedSecondaryStyles = const [],
    this.suggestedCharacteristics = const [],
    this.userRegister,
    this.userSecondaryStyles,
    this.userCharacteristics,
    this.evidence = const [],
    required this.calculatedAt,
  });

  String get register => userRegister ?? suggestedRegister;
  List<String> get secondaryStyles =>
      userSecondaryStyles ?? suggestedSecondaryStyles;
  List<String> get characteristics =>
      userCharacteristics ?? suggestedCharacteristics;
  bool get hasUserCorrections => userRegister != null ||
      userSecondaryStyles != null || userCharacteristics != null;

  StyleAnalysis withUserCorrections({String? register,
    List<String>? secondaryStyles, List<String>? characteristics}) =>
      StyleAnalysis(
        taxonomyVersion: taxonomyVersion, modelVersion: modelVersion,
        inputFingerprint: inputFingerprint,
        suggestedRegister: suggestedRegister,
        suggestedSecondaryStyles: suggestedSecondaryStyles,
        suggestedCharacteristics: suggestedCharacteristics,
        userRegister: register ?? userRegister,
        userSecondaryStyles: secondaryStyles ?? userSecondaryStyles,
        userCharacteristics: characteristics ?? userCharacteristics,
        evidence: evidence, calculatedAt: calculatedAt,
      );

  StyleAnalysis retainCorrectionsFrom(StyleAnalysis? previous) => StyleAnalysis(
    taxonomyVersion: taxonomyVersion, modelVersion: modelVersion,
    inputFingerprint: inputFingerprint, suggestedRegister: suggestedRegister,
    suggestedSecondaryStyles: suggestedSecondaryStyles,
    suggestedCharacteristics: suggestedCharacteristics,
    userRegister: previous?.userRegister,
    userSecondaryStyles: previous?.userSecondaryStyles,
    userCharacteristics: previous?.userCharacteristics,
    evidence: evidence, calculatedAt: calculatedAt,
  );

  String encode() => jsonEncode({
    'taxonomyVersion': taxonomyVersion, 'modelVersion': modelVersion,
    'inputFingerprint': inputFingerprint,
    'suggestedRegister': suggestedRegister,
    'suggestedSecondaryStyles': suggestedSecondaryStyles,
    'suggestedCharacteristics': suggestedCharacteristics,
    'userRegister': userRegister,
    'userSecondaryStyles': userSecondaryStyles,
    'userCharacteristics': userCharacteristics,
    'evidence': evidence, 'calculatedAt': calculatedAt.toIso8601String(),
  });

  static StyleAnalysis? decode(Object? source) {
    if (source is! String || source.isEmpty) return null;
    try {
      final map = jsonDecode(source);
      if (map is! Map) return null;
      List<String> strings(Object? value) => value is List
          ? value.map((e) => e.toString()).toList(growable: false) : const [];
      return StyleAnalysis(
        taxonomyVersion: map['taxonomyVersion'] is int
            ? map['taxonomyVersion'] as int : StyleTaxonomy.version,
        modelVersion: map['modelVersion']?.toString() ?? currentModelVersion,
        inputFingerprint: map['inputFingerprint']?.toString() ?? '',
        suggestedRegister: map['suggestedRegister']?.toString() ?? 'casual',
        suggestedSecondaryStyles: strings(map['suggestedSecondaryStyles']),
        suggestedCharacteristics: strings(map['suggestedCharacteristics']),
        userRegister: map['userRegister']?.toString(),
        userSecondaryStyles: map['userSecondaryStyles'] == null
            ? null : strings(map['userSecondaryStyles']),
        userCharacteristics: map['userCharacteristics'] == null
            ? null : strings(map['userCharacteristics']),
        evidence: strings(map['evidence']),
        calculatedAt: DateTime.tryParse(map['calculatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    } on FormatException { return null; }
  }
}
