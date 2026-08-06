import 'dart:convert';

/// Stable identifiers used by persistence and future style-library screens.
abstract final class StyleTaxonomy {
  static const version = 2;
  static const characteristics = <String>{
    'understated', 'structured', 'modern', 'retro', 'elegant', 'utility',
  };

  /// Canonical metadata keyed by the stable identifiers stored in
  /// [StyleAnalysis]. UI code must resolve labels through this map rather than
  /// maintaining its own lists.
  static final _rawEntries = <String, StyleDefinition>{
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
    for (final spec in _expandedStyleSpecs)
      spec.$1: StyleDefinition(
        id: spec.$1, name: spec.$2,
        definition: 'Un registre ${spec.$2} reconnaissable par ${spec.$3}.',
        description: 'Une compatibilité stylistique fondée sur ${spec.$3}, à confirmer selon les associations de la tenue.',
        synonyms: spec.$4,
        characteristics: [spec.$3, 'cohérent', 'identifiable'],
        colors: const ['neutres', 'tons naturels', 'couleurs signatures'],
        materials: const ['coton', 'laine', 'matières caractéristiques'],
        occasions: const ['quotidien', 'sortie', 'occasion adaptée'],
        typicalPieces: spec.$5,
        relatedStyleIds: spec.$6,
      ),
  };

  static final entries = <String, StyleDefinition>{
    for (final value in _rawEntries.values) value.id: value.enriched,
  };

  static const _expandedStyleSpecs = <(String, String, String, List<String>, List<String>, List<String>)>[
    ('business', 'Business', 'des lignes professionnelles structurées', ['professionnel'], ['costume', 'chemise', 'souliers'], ['business_casual', 'modern_classic']),
    ('business_casual', 'Business Casual', 'des codes de bureau assouplis', ['bureau décontracté'], ['oxford', 'chino', 'blazer'], ['smart_casual', 'ivy_league']),
    ('old_money', 'Old Money', 'une élégance patrimoniale discrète', ['heritage chic'], ['polo', 'mocassins', 'maille fine'], ['ivy_league', 'quiet_luxury']),
    ('quiet_luxury', 'Quiet Luxury', 'un luxe discret sans logos', ['luxe discret'], ['manteau sobre', 'maille fine', 'pantalon net'], ['minimalist', 'old_money']),
    ('ivy_league', 'Ivy League', 'les codes universitaires américains classiques', ['ivy'], ['chemise Oxford', 'chino', 'penny loafers'], ['preppy', 'old_money']),
    ('techwear', 'Techwear', 'la performance technique urbaine', ['urban tech'], ['shell', 'cargo technique', 'sac fonctionnel'], ['technical', 'utility']),
    ('heritage', 'Heritage', 'des références durables et patrimoniales', ['patrimoine'], ['tweed', 'veste cirée', 'boots'], ['workwear', 'old_money']),
    ('military', 'Military', 'des détails issus de l’uniforme', ['militaire'], ['field jacket', 'cargo', 'combat boots'], ['utility', 'workwear']),
    ('utility', 'Utility', 'des fonctions et poches visibles', ['utilitaire'], ['cargo', 'surchemise', 'gilet'], ['workwear', 'military']),
    ('gorpcore', 'Gorpcore', 'l’équipement outdoor porté en ville', ['gorp'], ['polaire', 'shell', 'chaussures trail'], ['outdoor', 'techwear']),
    ('scandinavian', 'Scandinave', 'un minimalisme fonctionnel nordique', ['scandi'], ['manteau droit', 'maille', 'sneakers sobres'], ['minimalist', 'japandi']),
    ('japandi', 'Japandi', 'la sobriété japonaise et scandinave', [], ['veste épurée', 'pantalon ample', 'maille'], ['scandinavian', 'minimalist']),
    ('japanese_americana', 'Japanese Americana', 'une relecture japonaise du vestiaire américain', [], ['denim selvedge', 'chore jacket', 'boots'], ['heritage', 'workwear']),
    ('french_chic', 'French Chic', 'une élégance française sans effort', ['chic français'], ['trench', 'marinière', 'ballerines'], ['parisian', 'modern_classic']),
    ('parisian', 'Parisien', 'des classiques urbains sobres', ['parisian'], ['blazer', 'jean droit', 'mocassins'], ['french_chic', 'minimalist']),
    ('italian_elegance', 'Élégance italienne', 'un tailoring souple et expressif', ['italian style'], ['costume souple', 'mocassins', 'chemise'], ['business', 'mediterranean']),
    ('mediterranean', 'Méditerranéen', 'des volumes légers et solaires', [], ['chemise lin', 'pantalon clair', 'sandales'], ['resort', 'italian_elegance']),
    ('dark_academia', 'Dark Academia', 'des références universitaires sombres', [], ['tweed', 'col roulé', 'mocassins'], ['light_academia', 'vintage']),
    ('light_academia', 'Light Academia', 'des références universitaires lumineuses', [], ['cardigan clair', 'oxford', 'pantalon plissé'], ['dark_academia', 'preppy']),
    ('modern_classic', 'Classique moderne', 'des classiques aux proportions actuelles', [], ['blazer', 'pantalon droit', 'chemise'], ['contemporary', 'business']),
    ('contemporary', 'Contemporain', 'des lignes actuelles et maîtrisées', [], ['veste moderne', 'pantalon fluide', 'sneakers'], ['modern_classic', 'minimalist']),
    ('retro', 'Rétro', 'une interprétation actuelle de codes passés', [], ['veste rétro', 'maille graphique', 'pantalon taille haute'], ['vintage', '90s']),
    ('y2k', 'Y2K', 'les codes pop du début des années 2000', ['années 2000'], ['mini sac', 'cargo taille basse', 'lunettes teintées'], ['90s', 'streetwear']),
    ('90s', 'Années 90', 'les volumes et références des années 1990', ['nineties'], ['jean droit', 'bomber', 'slip dress'], ['grunge', 'y2k']),
    ('80s', 'Années 80', 'des volumes affirmés et graphiques', ['eighties'], ['blazer épaulé', 'denim délavé', 'maille vive'], ['retro', 'color_blocking']),
    ('bohemian', 'Bohème', 'des volumes libres et influences artisanales', ['boho'], ['robe fluide', 'gilet brodé', 'sandales'], ['boho_chic', 'artisanal']),
    ('boho_chic', 'Boho Chic', 'une bohème raffinée', [], ['robe imprimée', 'suède', 'bijoux'], ['bohemian', 'romantic']),
    ('western', 'Western', 'les codes du vestiaire de l’Ouest américain', [], ['chemise western', 'denim', 'boots'], ['heritage', 'bohemian']),
    ('punk', 'Punk', 'une esthétique subversive et bricolée', [], ['cuir', 'tartan', 'boots'], ['rock', 'grunge']),
    ('grunge', 'Grunge', 'des superpositions relâchées inspirées des années 1990', [], ['flanelle', 'jean usé', 'boots'], ['rock', '90s']),
    ('romantic', 'Romantique', 'des détails délicats et silhouettes douces', [], ['dentelle', 'blouse', 'robe fluide'], ['boho_chic', 'ceremony']),
    ('avant_garde', 'Avant-Garde', 'des formes expérimentales', ['avant garde'], ['volume sculptural', 'drapé', 'pièce conceptuelle'], ['designer', 'artisanal']),
    ('artisanal', 'Artisanal', 'des textures et savoir-faire visibles', [], ['maille main', 'broderie', 'tissage'], ['bohemian', 'avant_garde']),
    ('sport_chic', 'Sport Chic', 'des codes sportifs polis', [], ['polo', 'pantalon net', 'sneakers premium'], ['athleisure', 'smart_casual']),
    ('athleisure', 'Athleisure', 'des vêtements sportifs intégrés au quotidien', [], ['legging', 'sweat', 'sneakers'], ['sport_chic', 'running']),
    ('tennis', 'Tennis', 'les codes sportifs de court', [], ['polo', 'jupe plissée', 'sneakers blanches'], ['preppy', 'sport_chic']),
    ('golf', 'Golf', 'les codes sportifs de club', [], ['polo', 'chino', 'gilet'], ['preppy', 'old_money']),
    ('running', 'Running', 'la performance et les lignes de course', [], ['coupe-vent', 'short technique', 'running shoes'], ['athleisure', 'technical']),
    ('cycling', 'Cyclisme', 'les lignes aérodynamiques du vélo', [], ['maillot', 'coupe-vent', 'lunettes'], ['technical', 'sport_chic']),
    ('sailing', 'Nautique', 'les codes fonctionnels de la voile', ['sailing'], ['ciré', 'polo', 'chaussures bateau'], ['resort', 'preppy']),
    ('resort', 'Resort', 'une élégance détendue de villégiature', [], ['chemise légère', 'robe fluide', 'sandales'], ['beachwear', 'mediterranean']),
    ('beachwear', 'Beachwear', 'des pièces conçues pour la plage', ['plage'], ['maillot', 'paréo', 'chemise ouverte'], ['resort', 'mediterranean']),
    ('evening', 'Soirée', 'une élégance adaptée au soir', [], ['robe longue', 'veste habillée', 'pochette'], ['cocktail', 'black_tie']),
    ('black_tie', 'Black Tie', 'les codes formels du smoking', [], ['smoking', 'robe de gala', 'souliers vernis'], ['evening', 'ceremony']),
    ('cocktail', 'Cocktail', 'une formalité festive intermédiaire', [], ['robe cocktail', 'costume sombre', 'escarpins'], ['evening', 'wedding_guest']),
    ('ceremony', 'Cérémonie', 'une tenue formelle de célébration', [], ['costume', 'robe habillée', 'accessoire précieux'], ['wedding_guest', 'evening']),
    ('wedding_guest', 'Invité de mariage', 'une élégance festive respectant la cérémonie', [], ['costume clair', 'robe midi', 'pochette'], ['ceremony', 'cocktail']),
    ('travel', 'Voyage', 'la polyvalence et le confort en déplacement', [], ['veste légère', 'pantalon confortable', 'sneakers'], ['casual', 'utility']),
    ('luxury', 'Luxe', 'des matières et finitions haut de gamme', [], ['manteau précieux', 'sac cuir', 'maille fine'], ['designer', 'quiet_luxury']),
    ('designer', 'Créateur', 'une signature de maison ou de designer', [], ['pièce signature', 'coupe distinctive', 'accessoire iconique'], ['luxury', 'avant_garde']),
    ('monochrome', 'Monochrome', 'une palette centrée sur une seule couleur', [], ['ensemble ton sur ton', 'manteau assorti', 'accessoires coordonnés'], ['minimalist', 'color_blocking']),
    ('color_blocking', 'Color Blocking', 'des aplats de couleurs contrastés', ['blocs de couleur'], ['maille vive', 'pantalon coloré', 'accessoire contrasté'], ['80s', 'contemporary']),
    ('normcore', 'Normcore', 'des basiques volontairement ordinaires', [], ['jean droit', 't-shirt uni', 'sneakers simples'], ['casual', 'minimalist']),
  ];
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

  StyleDefinition get enriched => StyleDefinition(
    id: id, name: name, definition: definition, description: description,
    synonyms: synonyms,
    characteristics: characteristics.isEmpty ? const ['cohérent', 'identifiable'] : characteristics,
    colors: colors.isEmpty ? const ['neutres', 'couleurs signatures'] : colors,
    materials: materials.isEmpty ? const ['coton', 'laine'] : materials,
    occasions: occasions.isEmpty ? const ['quotidien', 'occasion adaptée'] : occasions,
    typicalPieces: typicalPieces.isEmpty ? const ['pièce signature'] : typicalPieces,
    relatedStyleIds: relatedStyleIds.isEmpty ? const ['casual'] : relatedStyleIds,
    oppositeStyleIds: oppositeStyleIds,
  );
}

/// A non-exclusive, explainable affinity between a garment and a style.
class StyleCompatibility {
  final String styleId;
  final double score;
  final String justification;
  final double? confidence;

  const StyleCompatibility({required this.styleId, required this.score,
    required this.justification, this.confidence});

  Map<String, Object?> toMap() => {'styleId': styleId, 'score': score,
    'justification': justification, 'confidence': confidence};
  factory StyleCompatibility.fromMap(Map<Object?, Object?> map) =>
      StyleCompatibility(styleId: map['styleId']?.toString() ?? '',
        score: (map['score'] as num?)?.toDouble() ?? 0,
        justification: map['justification']?.toString() ?? '',
        confidence: (map['confidence'] as num?)?.toDouble());
}

/// Versioned, explainable stylistic result. AI values and user decisions are
/// deliberately separate: recomputation only replaces the suggestion layer.
class StyleAnalysis {
  static const currentModelVersion = 'style-v2-compatibilities';

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
  final List<StyleCompatibility> suggestedCompatibilities;
  /// Complete user override. Removing or adding an entry remains persistent
  /// across later AI recomputations without mutating the system catalogue.
  final List<StyleCompatibility>? userCompatibilities;
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
    this.suggestedCompatibilities = const [],
    this.userCompatibilities,
    required this.calculatedAt,
  });

  List<StyleCompatibility> get compatibilities {
    if (userCompatibilities != null) return userCompatibilities!;
    if (suggestedCompatibilities.isNotEmpty) return suggestedCompatibilities;
    return [StyleCompatibility(styleId: register, score: 1,
      justification: evidence.isEmpty ? 'Compatibilité héritée' : evidence.first),
      ...secondaryStyles.map((id) => StyleCompatibility(styleId: id, score: .7,
        justification: 'Compatibilité secondaire héritée'))];
  }

  String get register => userRegister ?? suggestedRegister;
  List<String> get secondaryStyles =>
      userSecondaryStyles ?? suggestedSecondaryStyles;
  List<String> get characteristics =>
      userCharacteristics ?? suggestedCharacteristics;
  bool get hasUserCorrections => userRegister != null ||
      userSecondaryStyles != null || userCharacteristics != null ||
      userCompatibilities != null;

  StyleAnalysis withUserCorrections({String? register,
    List<String>? secondaryStyles, List<String>? characteristics,
    List<StyleCompatibility>? compatibilities}) =>
      StyleAnalysis(
        taxonomyVersion: taxonomyVersion, modelVersion: modelVersion,
        inputFingerprint: inputFingerprint,
        suggestedRegister: suggestedRegister,
        suggestedSecondaryStyles: suggestedSecondaryStyles,
        suggestedCharacteristics: suggestedCharacteristics,
        userRegister: register ?? userRegister,
        userSecondaryStyles: secondaryStyles ?? userSecondaryStyles,
        userCharacteristics: characteristics ?? userCharacteristics,
        suggestedCompatibilities: suggestedCompatibilities,
        userCompatibilities: compatibilities ?? userCompatibilities,
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
    suggestedCompatibilities: suggestedCompatibilities,
    userCompatibilities: previous?.userCompatibilities,
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
    'suggestedCompatibilities': suggestedCompatibilities.map((e) => e.toMap()).toList(),
    'userCompatibilities': userCompatibilities?.map((e) => e.toMap()).toList(),
  });

  static StyleAnalysis? decode(Object? source) {
    if (source is! String || source.isEmpty) return null;
    try {
      final map = jsonDecode(source);
      if (map is! Map) return null;
      List<String> strings(Object? value) => value is List
          ? value.map((e) => e.toString()).toList(growable: false) : const [];
      List<StyleCompatibility> compatibilities(Object? value) => value is List
          ? value.whereType<Map>().map(StyleCompatibility.fromMap).toList(growable: false)
          : const [];
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
        suggestedCompatibilities: compatibilities(map['suggestedCompatibilities']),
        userCompatibilities: map['userCompatibilities'] == null ? null :
          compatibilities(map['userCompatibilities']),
        calculatedAt: DateTime.tryParse(map['calculatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    } on FormatException { return null; }
  }
}
