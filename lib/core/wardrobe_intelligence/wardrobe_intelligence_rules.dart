import '../../models/garment.dart';
import 'wardrobe_intelligence_models.dart';

class WardrobeRuleContext {
  final List<Garment> garments;
  final WardrobeDistribution categories;
  final WardrobeDistribution colors;
  final WardrobeDistribution seasons;
  final List<WardrobeDuplicateGroup> duplicates;

  const WardrobeRuleContext({
    required this.garments,
    required this.categories,
    required this.colors,
    required this.seasons,
    required this.duplicates,
  });
}

abstract interface class WardrobeGapRule {
  String get code;
  WardrobeGap? evaluate(WardrobeRuleContext context);
}

class MissingRainwearRule implements WardrobeGapRule {
  const MissingRainwearRule();
  @override
  String get code => 'missing_rainwear';

  @override
  WardrobeGap? evaluate(WardrobeRuleContext context) {
    if (context.garments.isEmpty ||
        context.garments.any((item) => item.compatiblePluie == true)) {
      return null;
    }
    return const WardrobeGap(
      code: 'missing_rainwear',
      label: 'Pièce imperméable',
      explanation: 'Aucun vêtement n’est identifié comme compatible avec la pluie.',
      impact: .9,
    );
  }
}

class InsufficientWinterRule implements WardrobeGapRule {
  final double minimumShare;
  const InsufficientWinterRule({this.minimumShare = .2});
  @override
  String get code => 'insufficient_winter';

  @override
  WardrobeGap? evaluate(WardrobeRuleContext context) {
    if (context.garments.length < 5 ||
        context.seasons.shareOf('Hiver') >= minimumShare) return null;
    return WardrobeGap(
      code: code,
      label: 'Vêtements d’hiver',
      explanation: 'La part de vêtements adaptés à l’hiver est inférieure au seuil attendu.',
      impact: .75,
      evidence: {'share': context.seasons.shareOf('Hiver'), 'minimumShare': minimumShare},
    );
  }
}

class MissingFormalShoesRule implements WardrobeGapRule {
  const MissingFormalShoesRule();
  @override
  String get code => 'missing_formal_shoes';

  @override
  WardrobeGap? evaluate(WardrobeRuleContext context) {
    if (context.garments.isEmpty) return null;
    final hasFormalShoes = context.garments.any((item) {
      final category = _text(item.category);
      final type = _text('${item.sousCategorie ?? ''} ${item.typePrecis ?? ''}');
      final formality = _text(item.niveauFormalite);
      return category.contains('chauss') &&
          (formality.contains('formel') || formality.contains('habill') ||
              type.contains('richelieu') || type.contains('derby') ||
              type.contains('mocassin') || type.contains('escarpin'));
    });
    return hasFormalShoes ? null : const WardrobeGap(
      code: 'missing_formal_shoes',
      label: 'Chaussures habillées',
      explanation: 'Aucune chaussure habillée n’a été identifiée.',
      impact: .65,
    );
  }
}

class InsufficientNeutralColorsRule implements WardrobeGapRule {
  final double minimumShare;
  const InsufficientNeutralColorsRule({this.minimumShare = .3});
  @override
  String get code => 'insufficient_neutrals';

  @override
  WardrobeGap? evaluate(WardrobeRuleContext context) {
    if (context.colors.knownCount < 5) return null;
    const neutrals = {'noir', 'blanc', 'gris', 'beige', 'ecru', 'bleu marine', 'marine', 'marron'};
    final count = context.colors.counts.entries
        .where((entry) => neutrals.contains(_text(entry.key)))
        .fold<int>(0, (sum, entry) => sum + entry.value);
    final share = count / context.colors.knownCount;
    return share >= minimumShare ? null : WardrobeGap(
      code: code,
      label: 'Couleurs neutres',
      explanation: 'La base de couleurs neutres est limitée pour composer des tenues.',
      impact: .55,
      evidence: {'share': share, 'minimumShare': minimumShare},
    );
  }
}

class ExcessSimilarItemsRule implements WardrobeGapRule {
  final int minimumGroupSize;
  const ExcessSimilarItemsRule({this.minimumGroupSize = 3});
  @override
  String get code => 'excess_similar_items';

  @override
  WardrobeGap? evaluate(WardrobeRuleContext context) {
    final groups = context.duplicates
        .where((group) => group.garments.length >= minimumGroupSize)
        .toList(growable: false);
    if (groups.isEmpty) return null;
    return WardrobeGap(
      code: code,
      label: 'Pièces très similaires',
      explanation: 'Plusieurs vêtements remplissent le même rôle stylistique.',
      impact: .45,
      evidence: {'groupCount': groups.length, 'roles': groups.map((group) => group.role).toList()},
    );
  }
}

String _text(String? value) => (value ?? '')
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[éèêë]'), 'e')
    .replaceAll(RegExp(r'[àâä]'), 'a')
    .replaceAll(RegExp(r'[îï]'), 'i')
    .replaceAll(RegExp(r'[ôö]'), 'o')
    .replaceAll(RegExp(r'[ùûü]'), 'u');

const defaultWardrobeGapRules = <WardrobeGapRule>[
  MissingRainwearRule(),
  InsufficientWinterRule(),
  MissingFormalShoesRule(),
  InsufficientNeutralColorsRule(),
  ExcessSimilarItemsRule(),
];
