import 'dart:convert';

import 'garment_normalizer.dart';

class Garment {
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
  final String? etatVisuel;
  final String? usureVisible;
  final List<String>? defautsVisibles;
  final double? confianceGlobale;
  final List<String>? avertissementsIA;
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
    this.etatVisuel,
    this.usureVisible,
    this.defautsVisibles,
    this.confianceGlobale,
    this.avertissementsIA,
    this.wearCount = 0,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

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
    String? etatVisuel,
    String? usureVisible,
    List<String>? defautsVisibles,
    double? confianceGlobale,
    List<String>? avertissementsIA,
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
    etatVisuel: etatVisuel ?? this.etatVisuel,
    usureVisible: usureVisible ?? this.usureVisible,
    defautsVisibles: defautsVisibles ?? this.defautsVisibles,
    confianceGlobale: confianceGlobale ?? this.confianceGlobale,
    avertissementsIA: avertissementsIA ?? this.avertissementsIA,
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
    'season': season,
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
    'saisons': saisons == null ? null : jsonEncode(saisons),
    'occasions': occasions == null ? null : jsonEncode(occasions),
    'temperature_minimum': temperatureMinimum,
    'temperature_maximum': temperatureMaximum,
    'compatible_pluie': compatiblePluie == null ? null : (compatiblePluie! ? 1 : 0),
    'compatible_chaleur': compatibleChaleur == null ? null : (compatibleChaleur! ? 1 : 0),
    'superposable': superposable == null ? null : (superposable! ? 1 : 0),
    'etat_visuel': etatVisuel,
    'usure_visible': usureVisible,
    'defauts_visibles': defautsVisibles == null ? null : jsonEncode(defautsVisibles),
    'confiance_globale': confianceGlobale,
    'avertissements_i_a': avertissementsIA == null ? null : jsonEncode(avertissementsIA),
    'wear_count': wearCount,
    'is_favorite': isFavorite ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Garment.fromMap(Map<String, Object?> map) {
    String? text(String key) => GarmentNormalizer.value(map[key] as String?);
    List<String>? list(String key) {
      final value = map[key];
      if (value == null) return null;
      final decoded = value is String ? jsonDecode(value) : value;
      if (decoded is! List) return null;
      return GarmentNormalizer.values(decoded.map((e) => e.toString()));
    }
    double? number(String key) => (map[key] as num?)?.toDouble();
    bool? boolean(String key) {
      final value = map[key];
      if (value == null) return null;
      return value == true || value == 1;
    }

    return Garment(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      brand: text('brand'),
      color: text('color'),
      material: text('material'),
      season: text('season'),
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
      saisons: list('saisons'),
      occasions: list('occasions'),
      temperatureMinimum: number('temperature_minimum'),
      temperatureMaximum: number('temperature_maximum'),
      compatiblePluie: boolean('compatible_pluie'),
      compatibleChaleur: boolean('compatible_chaleur'),
      superposable: boolean('superposable'),
      etatVisuel: text('etat_visuel'),
      usureVisible: text('usure_visible'),
      defautsVisibles: list('defauts_visibles'),
      confianceGlobale: number('confiance_globale'),
      avertissementsIA: list('avertissements_i_a'),
      wearCount: (map['wear_count'] as num?)?.toInt() ?? 0,
      isFavorite: map['is_favorite'] == 1 || map['is_favorite'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
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
