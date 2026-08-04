import 'dart:convert';

import 'garment_normalizer.dart';
import 'garment_photo.dart';
import 'thermal_profile.dart';
import 'style_analysis.dart';
import 'style_classifier.dart';
import '../features/scanner/ai/analysis_foundations.dart';

class Garment {
  static const availableSeasons = ['Printemps', 'Été', 'Automne', 'Hiver'];
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
  final DateTime? lastWorn;
  final String? size;
  final String? fit;
  final String? composition;
  final String? notes;
  final String? imagePath;
  final List<GarmentPhoto> photos;
  final DateTime? lastAnalyzedAt;
  final String? aiAnalysisVersion;
  final GarmentAnalysisSnapshot? previousAnalysis;
  final GarmentAnalysisSnapshot? currentAnalysis;
  final Set<String> userModifiedFields;
  final String? sousCategorie;
  final String? typePrecis;
  final String? descriptionIA;
  final String? couleurPrincipale;
  final List<String>? couleursSecondaires;
  final String? motif;
  final String? texture;
  final bool? logoVisible;
  final String? stylePrincipal;
  final List<String>? stylesSecondaires;
  final String? niveauFormalite;
  final String? coupe;
  final String? longueur;
  final String? longueurManches;
  final String? typeCol;
  final String? typeFermeture;
  final String? matierePrincipale;
  final List<String>? matieresSecondaires;
  final double? confianceMatiere;
  final List<String>? saisons;
  final List<String>? occasions;
  final double? temperatureMinimum;
  final double? temperatureMaximum;
  final bool? compatiblePluie;
  final bool? compatibleChaleur;
  final bool? superposable;
  /// Couche calculée par l'analyse (jamais demandée à l'utilisateur).
  final String? layerType;
  final ThermalProfile? thermalProfile;
  final StyleAnalysis? styleAnalysis;
  final String? etatVisuel;
  final String? usureVisible;
  final List<String>? defautsVisibles;
  final double? confianceGlobale;
  final List<String>? avertissementsIA;
  final String? resumeStylistique;
  final List<String>? pointsForts;
  final List<String>? pointsFaibles;
  final List<String>? conseils;
  final String? verdict;
  final List<String>? couleursCompatibles;
  final List<String>? couleursMoinsAdaptees;
  final List<String>? basCompatibles;
  final List<String>? chaussuresCompatibles;
  final String? explicationPolyvalence;
  final List<String>? occasionsDeconseillees;
  final String? compositionEstimee;
  final String? lavage;
  final String? sechage;
  final String? repassage;
  final String? nettoyage;
  final String? boulochage;
  final String? taches;
  final List<String>? limitesAnalyse;
  final int wearCount;
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
    this.lastWorn,
    this.size,
    this.fit,
    this.composition,
    this.notes,
    this.imagePath,
    this.photos = const [],
    this.lastAnalyzedAt,
    this.aiAnalysisVersion,
    this.previousAnalysis,
    this.currentAnalysis,
    this.userModifiedFields = const {},
    this.sousCategorie,
    this.typePrecis,
    this.descriptionIA,
    this.couleurPrincipale,
    this.couleursSecondaires,
    this.motif,
    this.texture,
    this.logoVisible,
    this.stylePrincipal,
    this.stylesSecondaires,
    this.niveauFormalite,
    this.coupe,
    this.longueur,
    this.longueurManches,
    this.typeCol,
    this.typeFermeture,
    this.matierePrincipale,
    this.matieresSecondaires,
    this.confianceMatiere,
    this.saisons,
    this.occasions,
    this.temperatureMinimum,
    this.temperatureMaximum,
    this.compatiblePluie,
    this.compatibleChaleur,
    this.superposable,
    this.layerType,
    this.thermalProfile,
    this.styleAnalysis,
    this.etatVisuel,
    this.usureVisible,
    this.defautsVisibles,
    this.confianceGlobale,
    this.avertissementsIA,
    this.resumeStylistique,
    this.pointsForts,
    this.pointsFaibles,
    this.conseils,
    this.verdict,
    this.couleursCompatibles,
    this.couleursMoinsAdaptees,
    this.basCompatibles,
    this.chaussuresCompatibles,
    this.explicationPolyvalence,
    this.occasionsDeconseillees,
    this.compositionEstimee,
    this.lavage,
    this.sechage,
    this.repassage,
    this.nettoyage,
    this.boulochage,
    this.taches,
    this.limitesAnalyse,
    this.wearCount = 0,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  List<GarmentPhoto> get effectivePhotos => photos.isNotEmpty
      ? photos
      : [if (imagePath?.isNotEmpty == true) GarmentPhoto(id: 'legacy-$id', path: imagePath!, type: GarmentPhotoType.primary, createdAt: createdAt)];
  bool needsAiReanalysis(String currentVersion) => aiAnalysisVersion == null || aiAnalysisVersion != currentVersion;

  /// Saisons canoniques du vêtement, avec repli sur l'ancien champ unique.
  List<String> get effectiveSeasons {
    final source = saisons?.isNotEmpty == true ? saisons! : [if (season != null) season!];
    final expanded = source.expand(
      (value) => value.trim().toLowerCase() == 'toute saison'
          ? availableSeasons
          : [value],
    );
    return expanded
        .map(GarmentNormalizer.value)
        .whereType<String>()
        .where(availableSeasons.contains)
        .toSet()
        .toList(growable: false);
  }

  /// Utilisations du vêtement, avec repli sur l'ancien champ unique.
  List<String> get effectiveOccasions {
    final source = occasions?.isNotEmpty == true
        ? occasions!
        : [if (occasion != null) occasion!];
    return source
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  /// New records persist this value; legacy records receive a conservative
  /// adapter without rewriting their historical fields.
  ThermalProfile get effectiveThermalProfile => thermalProfile ?? ThermalProfile.fromLegacy(
    minimum: temperatureMinimum,
    maximum: temperatureMaximum,
    rain: compatiblePluie,
    layerType: layerType,
  );

  /// Progressive adapter for rows created before the style-v1 column existed.
  /// Reading old rows remains side-effect free; the result is persisted on the
  /// next normal insert/update.
  StyleAnalysis get effectiveStyleAnalysis => styleAnalysis ??
      const StyleClassifier().classify(styleInput);

  StyleInput get styleInput => StyleInput(
    category: category,
    subcategory: sousCategorie ?? typePrecis,
    material: matierePrincipale ?? material ?? composition,
    fit: coupe ?? fit,
    color: couleurPrincipale ?? color,
    pattern: motif,
    construction: [texture, typeCol, typeFermeture].whereType<String>().join(' '),
    formality: niveauFormalite,
    details: [descriptionIA, typePrecis, stylePrincipal, ...?stylesSecondaires]
        .whereType<String>().join(' '),
  );

  /// Recomputes only the style layer; no image scan is involved.
  Garment withCurrentStyleAnalysis({StyleClassifier classifier = const StyleClassifier(),
      DateTime? calculatedAt}) => copyWith(styleAnalysis: classifier.ensureCurrent(
        styleInput, styleAnalysis, calculatedAt: calculatedAt));

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
    DateTime? lastWorn,
    String? size,
    String? fit,
    String? composition,
    String? notes,
    String? imagePath,
    List<GarmentPhoto>? photos,
    DateTime? lastAnalyzedAt,
    String? aiAnalysisVersion,
    GarmentAnalysisSnapshot? previousAnalysis,
    GarmentAnalysisSnapshot? currentAnalysis,
    Set<String>? userModifiedFields,
    String? sousCategorie,
    String? typePrecis,
    String? descriptionIA,
    String? couleurPrincipale,
    List<String>? couleursSecondaires,
    String? motif,
    String? texture,
    bool? logoVisible,
    String? stylePrincipal,
    List<String>? stylesSecondaires,
    String? niveauFormalite,
    String? coupe,
    String? longueur,
    String? longueurManches,
    String? typeCol,
    String? typeFermeture,
    String? matierePrincipale,
    List<String>? matieresSecondaires,
    double? confianceMatiere,
    List<String>? saisons,
    List<String>? occasions,
    double? temperatureMinimum,
    double? temperatureMaximum,
    bool? compatiblePluie,
    bool? compatibleChaleur,
    bool? superposable,
    String? layerType,
    ThermalProfile? thermalProfile,
    StyleAnalysis? styleAnalysis,
    String? etatVisuel,
    String? usureVisible,
    List<String>? defautsVisibles,
    double? confianceGlobale,
    List<String>? avertissementsIA,
    String? resumeStylistique,
    List<String>? pointsForts,
    List<String>? pointsFaibles,
    List<String>? conseils,
    String? verdict,
    List<String>? couleursCompatibles,
    List<String>? couleursMoinsAdaptees,
    List<String>? basCompatibles,
    List<String>? chaussuresCompatibles,
    String? explicationPolyvalence,
    List<String>? occasionsDeconseillees,
    String? compositionEstimee,
    String? lavage,
    String? sechage,
    String? repassage,
    String? nettoyage,
    String? boulochage,
    String? taches,
    List<String>? limitesAnalyse,
    int? wearCount,
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
    lastWorn: lastWorn ?? this.lastWorn,
    size: size ?? this.size,
    fit: fit ?? this.fit,
    composition: composition ?? this.composition,
    notes: notes ?? this.notes,
    imagePath: imagePath ?? this.imagePath,
    photos: photos ?? this.photos,
    lastAnalyzedAt: lastAnalyzedAt ?? this.lastAnalyzedAt,
    aiAnalysisVersion: aiAnalysisVersion ?? this.aiAnalysisVersion,
    previousAnalysis: previousAnalysis ?? this.previousAnalysis,
    currentAnalysis: currentAnalysis ?? this.currentAnalysis,
    userModifiedFields: userModifiedFields ?? this.userModifiedFields,
    sousCategorie: sousCategorie ?? this.sousCategorie,
    typePrecis: typePrecis ?? this.typePrecis,
    descriptionIA: descriptionIA ?? this.descriptionIA,
    couleurPrincipale: couleurPrincipale ?? this.couleurPrincipale,
    couleursSecondaires: couleursSecondaires ?? this.couleursSecondaires,
    motif: motif ?? this.motif,
    texture: texture ?? this.texture,
    logoVisible: logoVisible ?? this.logoVisible,
    stylePrincipal: stylePrincipal ?? this.stylePrincipal,
    stylesSecondaires: stylesSecondaires ?? this.stylesSecondaires,
    niveauFormalite: niveauFormalite ?? this.niveauFormalite,
    coupe: coupe ?? this.coupe,
    longueur: longueur ?? this.longueur,
    longueurManches: longueurManches ?? this.longueurManches,
    typeCol: typeCol ?? this.typeCol,
    typeFermeture: typeFermeture ?? this.typeFermeture,
    matierePrincipale: matierePrincipale ?? this.matierePrincipale,
    matieresSecondaires: matieresSecondaires ?? this.matieresSecondaires,
    confianceMatiere: confianceMatiere ?? this.confianceMatiere,
    saisons: saisons ?? this.saisons,
    occasions: occasions ?? this.occasions,
    temperatureMinimum: temperatureMinimum ?? this.temperatureMinimum,
    temperatureMaximum: temperatureMaximum ?? this.temperatureMaximum,
    compatiblePluie: compatiblePluie ?? this.compatiblePluie,
    compatibleChaleur: compatibleChaleur ?? this.compatibleChaleur,
    superposable: superposable ?? this.superposable,
    layerType: layerType ?? this.layerType,
    thermalProfile: thermalProfile ?? this.thermalProfile,
    styleAnalysis: styleAnalysis ?? this.styleAnalysis,
    etatVisuel: etatVisuel ?? this.etatVisuel,
    usureVisible: usureVisible ?? this.usureVisible,
    defautsVisibles: defautsVisibles ?? this.defautsVisibles,
    confianceGlobale: confianceGlobale ?? this.confianceGlobale,
    avertissementsIA: avertissementsIA ?? this.avertissementsIA,
    resumeStylistique: resumeStylistique ?? this.resumeStylistique,
    pointsForts: pointsForts ?? this.pointsForts,
    pointsFaibles: pointsFaibles ?? this.pointsFaibles,
    conseils: conseils ?? this.conseils,
    verdict: verdict ?? this.verdict,
    couleursCompatibles: couleursCompatibles ?? this.couleursCompatibles,
    couleursMoinsAdaptees: couleursMoinsAdaptees ?? this.couleursMoinsAdaptees,
    basCompatibles: basCompatibles ?? this.basCompatibles,
    chaussuresCompatibles: chaussuresCompatibles ?? this.chaussuresCompatibles,
    explicationPolyvalence: explicationPolyvalence ?? this.explicationPolyvalence,
    occasionsDeconseillees: occasionsDeconseillees ?? this.occasionsDeconseillees,
    compositionEstimee: compositionEstimee ?? this.compositionEstimee,
    lavage: lavage ?? this.lavage,
    sechage: sechage ?? this.sechage,
    repassage: repassage ?? this.repassage,
    nettoyage: nettoyage ?? this.nettoyage,
    boulochage: boulochage ?? this.boulochage,
    taches: taches ?? this.taches,
    limitesAnalyse: limitesAnalyse ?? this.limitesAnalyse,
    wearCount: wearCount ?? this.wearCount,
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
    // Le champ historique reste alimenté pour les anciennes versions.
    'season': effectiveSeasons.length == 1 ? effectiveSeasons.single : season,
    'style': style,
    'occasion': occasion,
    'condition': condition,
    'purchase_price': purchasePrice,
    'purchase_date': purchaseDate?.toIso8601String(),
    'last_worn': lastWorn?.toIso8601String(),
    'size': size,
    'fit': fit,
    'composition': composition,
    'notes': notes,
    'image_path': imagePath,
    'photos': GarmentPhoto.encode(effectivePhotos),
    'last_analyzed_at': lastAnalyzedAt?.toIso8601String(),
    'ai_analysis_version': aiAnalysisVersion,
    'previous_analysis': GarmentAnalysisSnapshot.encode(previousAnalysis),
    'current_analysis': GarmentAnalysisSnapshot.encode(currentAnalysis),
    'user_modified_fields': jsonEncode(userModifiedFields.toList()..sort()),
    'sous_categorie': sousCategorie,
    'type_precis': typePrecis,
    'description_i_a': descriptionIA,
    'couleur_principale': couleurPrincipale,
    'couleurs_secondaires': couleursSecondaires == null ? null : jsonEncode(couleursSecondaires),
    'motif': motif,
    'texture': texture,
    'logo_visible': logoVisible == null ? null : (logoVisible! ? 1 : 0),
    'style_principal': stylePrincipal,
    'styles_secondaires': stylesSecondaires == null ? null : jsonEncode(stylesSecondaires),
    'niveau_formalite': niveauFormalite,
    'coupe': coupe,
    'longueur': longueur,
    'longueur_manches': longueurManches,
    'type_col': typeCol,
    'type_fermeture': typeFermeture,
    'matiere_principale': matierePrincipale,
    'matieres_secondaires': matieresSecondaires == null ? null : jsonEncode(matieresSecondaires),
    'confiance_matiere': confianceMatiere,
    'saisons': jsonEncode(effectiveSeasons),
    'occasions': occasions == null ? null : jsonEncode(occasions),
    'temperature_minimum': temperatureMinimum,
    'temperature_maximum': temperatureMaximum,
    'compatible_pluie': compatiblePluie == null ? null : (compatiblePluie! ? 1 : 0),
    'compatible_chaleur': compatibleChaleur == null ? null : (compatibleChaleur! ? 1 : 0),
    'superposable': superposable == null ? null : (superposable! ? 1 : 0),
    'layer_type': layerType,
    'thermal_profile': thermalProfile?.encode(),
    'style_analysis': styleAnalysis?.encode(),
    'etat_visuel': etatVisuel,
    'usure_visible': usureVisible,
    'defauts_visibles': defautsVisibles == null ? null : jsonEncode(defautsVisibles),
    'confiance_globale': confianceGlobale,
    'avertissements_i_a': avertissementsIA == null ? null : jsonEncode(avertissementsIA),
    'resume_stylistique': resumeStylistique,
    'points_forts': pointsForts == null ? null : jsonEncode(pointsForts),
    'points_faibles': pointsFaibles == null ? null : jsonEncode(pointsFaibles),
    'conseils': conseils == null ? null : jsonEncode(conseils),
    'verdict': verdict,
    'couleurs_compatibles': couleursCompatibles == null ? null : jsonEncode(couleursCompatibles),
    'couleurs_moins_adaptees': couleursMoinsAdaptees == null ? null : jsonEncode(couleursMoinsAdaptees),
    'bas_compatibles': basCompatibles == null ? null : jsonEncode(basCompatibles),
    'chaussures_compatibles': chaussuresCompatibles == null ? null : jsonEncode(chaussuresCompatibles),
    'explication_polyvalence': explicationPolyvalence,
    'occasions_deconseillees': occasionsDeconseillees == null ? null : jsonEncode(occasionsDeconseillees),
    'composition_estimee': compositionEstimee,
    'lavage': lavage,
    'sechage': sechage,
    'repassage': repassage,
    'nettoyage': nettoyage,
    'boulochage': boulochage,
    'taches': taches,
    'limites_analyse': limitesAnalyse == null ? null : jsonEncode(limitesAnalyse),
    'wear_count': wearCount,
    'is_favorite': isFavorite ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Garment.fromMap(Map<String, Object?> map) {
    String? text(String key) {
      final value = map[key];
      return value is String ? GarmentNormalizer.value(value) : null;
    }
    List<String>? list(String key) {
      final value = map[key];
      if (value == null) return null;
      Object? decoded = value;
      if (value is String) {
        try {
          decoded = jsonDecode(value);
        } on FormatException {
          return null;
        }
      }
      if (decoded is! List) return null;
      return GarmentNormalizer.values(decoded.map((e) => e.toString()));
    }
    double? number(String key) {
      final value = map[key];
      return value is num ? value.toDouble() : null;
    }
    bool? boolean(String key) {
      final value = map[key];
      if (value == null) return null;
      return value == true || value == 1;
    }

    final legacySeason = text('season');
    final storedSeasons = list('saisons');
    final canonicalSeasons = storedSeasons?.isNotEmpty == true
        ? storedSeasons
        : legacySeason == null
            ? null
            : legacySeason.toLowerCase() == 'toute saison'
                ? availableSeasons
                : [legacySeason];

    return Garment(
      id: text('id') ?? '',
      name: text('name') ?? '',
      category: text('category') ?? '',
      brand: text('brand'),
      color: text('color'),
      material: text('material'),
      season: legacySeason,
      style: text('style'),
      occasion: text('occasion'),
      condition: text('condition'),
      purchasePrice: number('purchase_price'),
      purchaseDate: _parseDate(map['purchase_date']),
      lastWorn: _parseDate(map['last_worn']),
      size: text('size'),
      fit: text('fit'),
      composition: text('composition'),
      notes: text('notes'),
      imagePath: text('image_path'),
      photos: GarmentPhoto.decode(map['photos']),
      lastAnalyzedAt: _parseDate(map['last_analyzed_at']),
      aiAnalysisVersion: text('ai_analysis_version'),
      previousAnalysis: GarmentAnalysisSnapshot.decode(map['previous_analysis']),
      currentAnalysis: GarmentAnalysisSnapshot.decode(map['current_analysis']),
      userModifiedFields: (list('user_modified_fields') ?? const []).toSet(),
      sousCategorie: text('sous_categorie'),
      typePrecis: text('type_precis'),
      descriptionIA: text('description_i_a'),
      couleurPrincipale: text('couleur_principale'),
      couleursSecondaires: list('couleurs_secondaires'),
      motif: text('motif'),
      texture: text('texture'),
      logoVisible: boolean('logo_visible'),
      stylePrincipal: text('style_principal'),
      stylesSecondaires: list('styles_secondaires'),
      niveauFormalite: text('niveau_formalite'),
      coupe: text('coupe'),
      longueur: text('longueur'),
      longueurManches: text('longueur_manches'),
      typeCol: text('type_col'),
      typeFermeture: text('type_fermeture'),
      matierePrincipale: text('matiere_principale'),
      matieresSecondaires: list('matieres_secondaires'),
      confianceMatiere: number('confiance_matiere'),
      saisons: canonicalSeasons,
      occasions: list('occasions'),
      temperatureMinimum: number('temperature_minimum'),
      temperatureMaximum: number('temperature_maximum'),
      compatiblePluie: boolean('compatible_pluie'),
      compatibleChaleur: boolean('compatible_chaleur'),
      superposable: boolean('superposable'),
      layerType: text('layer_type') ?? _legacyLayer(boolean('superposable'), text('category')),
      thermalProfile: ThermalProfile.decode(map['thermal_profile']),
      styleAnalysis: StyleAnalysis.decode(map['style_analysis']),
      etatVisuel: text('etat_visuel'),
      usureVisible: text('usure_visible'),
      defautsVisibles: list('defauts_visibles'),
      confianceGlobale: number('confiance_globale'),
      avertissementsIA: list('avertissements_i_a'),
      resumeStylistique: text('resume_stylistique'),
      pointsForts: list('points_forts'),
      pointsFaibles: list('points_faibles'),
      conseils: list('conseils'),
      verdict: text('verdict'),
      couleursCompatibles: list('couleurs_compatibles'),
      couleursMoinsAdaptees: list('couleurs_moins_adaptees'),
      basCompatibles: list('bas_compatibles'),
      chaussuresCompatibles: list('chaussures_compatibles'),
      explicationPolyvalence: text('explication_polyvalence'),
      occasionsDeconseillees: list('occasions_deconseillees'),
      compositionEstimee: text('composition_estimee'),
      lavage: text('lavage'),
      sechage: text('sechage'),
      repassage: text('repassage'),
      nettoyage: text('nettoyage'),
      boulochage: text('boulochage'),
      taches: text('taches'),
      limitesAnalyse: list('limites_analyse'),
      wearCount: number('wear_count')?.toInt() ?? 0,
      isFavorite: map['is_favorite'] == 1 || map['is_favorite'] == true,
      createdAt:
          _parseDate(map['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parseDate(map['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String? _legacyLayer(bool? superposable, String? category) {
    if (superposable == false) return null;
    if (category == 'Vestes') return 'Couche extérieure';
    if (category == 'Hauts' || category == 'Chemises') return 'Couche de base';
    return superposable == true ? 'Couche intermédiaire' : null;
  }

  String? validate() {
    if (temperatureMinimum != null && temperatureMaximum != null && temperatureMinimum! > temperatureMaximum!) return 'La température minimum doit être inférieure au maximum.';
    for (final confidence in [confianceMatiere, confianceGlobale]) {
      if (confidence != null && (confidence < 0 || confidence > 1)) return 'Une confiance doit être comprise entre 0 et 1.';
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is Garment && _mapEquals(toMap(), other.toMap());
  @override
  int get hashCode => Object.hashAll(toMap().entries.map((e) => Object.hash(e.key, e.value)));
  static bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) { if (a[key] != b[key]) return false; }
    return true;
  }
}
