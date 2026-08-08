import 'dart:convert';

import 'style_analysis.dart';

class StyleInput {
  final String category;
  final String? subcategory, material, fit, color, pattern, construction,
      formality, details;
  const StyleInput({required this.category, this.subcategory, this.material,
    this.fit, this.color, this.pattern, this.construction, this.formality,
    this.details});

  String get normalized => [category, subcategory, material, fit, color,
    pattern, construction, formality, details]
      .map((v) => (v ?? '').trim().toLowerCase()).join('|');
  String get fingerprint => base64Url.encode(utf8.encode(normalized));
}

/// Deterministic baseline classifier. Its evidence makes every decision
/// inspectable and it can later be replaced by an AI provider without changing
/// the persisted contract.
class StyleClassifier {
  const StyleClassifier();
  StyleAnalysis classify(StyleInput input, {StyleAnalysis? previous,
    DateTime? calculatedAt}) {
    final text = input.normalized;
    bool has(String expression) => RegExp(expression).hasMatch(text);
    final evidence = <String>[];
    String register;
    if (has(r'parka|softshell|imperm[eé]able|gore.?tex|technique')) {
      register = 'technical'; evidence.add('Construction ou matière technique');
    } else if (has(r'jogging|surv[eê]tement|legging|maillot|sport')) {
      register = 'sport'; evidence.add('Construction destinée au sport');
    } else if (has(r'costume|smoking|tailleur|formel|habill[eé]')) {
      register = 'dressy'; evidence.add('Construction ou formalité habillée');
    } else if (has(r'oxford|chino|blazer|polo|smart.?casual|semi.?formel')) {
      register = 'smart_casual'; evidence.add('Détails intermédiaires casual/habillés');
    } else {
      register = 'casual'; evidence.add('Construction principalement décontractée');
    }
    // Hard coherence constraints beat generic formality hints.
    if (has(r'sweat|hoodie|capuche')) {
      register = 'casual'; evidence.add('Contrainte: un sweat reste décontracté');
    }

    final secondary = <String>[];
    void add(String id, String reason) { secondary.add(id); evidence.add(reason); }
    if (has(r'oxford|chino|polo|mocassin|preppy')) { add('preppy', 'Codes preppy visibles'); }
    if (has(r'cargo|toile|denim|poche.*plaqu[eé]e|workwear')) { add('workwear', 'Détails utilitaires/workwear'); }
    if (has(r'oversize|graphique|streetwear') && !has(r'costume|smoking')) { add('streetwear', 'Volume ou graphisme streetwear'); }
    if (has(r'outdoor|randonn[eé]e|parka|polaire')) { add('outdoor', 'Usage outdoor identifiable'); }
    if (has(r'vintage|ann[eé]es? [0-9]|r[eé]tro')) { add('vintage', 'Référence rétro explicite'); }
    if (has(r'cuir|clou|rock')) { add('rock', 'Codes rock visibles'); }
    if (has(r'uni|neutre|minimal')) { add('minimalist', 'Palette ou motif minimaliste'); }

    final characteristics = <String>[];
    if (has(r'uni|marine|noir|gris|beige|sobre')) { characteristics.add('understated'); }
    if (has(r'blazer|costume|tailleur|structur[eé]|revers')) { characteristics.add('structured'); }
    if (has(r'moderne|contemporain|technique')) { characteristics.add('modern'); }
    if (has(r'vintage|r[eé]tro')) { characteristics.add('retro'); }
    if (register == 'dressy' || has(r'[eé]l[eé]gant')) { characteristics.add('elegant'); }
    if (has(r'cargo|poche|utilitaire|workwear')) { characteristics.add('utility'); }

    final compatibilityReasons = <String, String>{register: evidence.first};
    for (final id in secondary) {
      compatibilityReasons[id] = evidence.lastWhere(
        (reason) => reason.toLowerCase().contains(id == 'preppy' ? 'preppy' : id),
        orElse: () => 'Codes ${StyleTaxonomy.entries[id]?.name ?? id} compatibles',
      );
    }
    if (has(r'oxford')) {
      compatibilityReasons.addAll({
        'ivy_league': 'La chemise Oxford est un pilier du vestiaire universitaire américain',
        'old_money': 'Sa construction classique et discrète convient à une élégance patrimoniale',
        'business_casual': 'Elle assouplit naturellement une tenue de bureau',
        'quiet_luxury': 'Sans logo ni effet marqué, elle soutient un luxe discret',
      });
    }
    final compatibilities = compatibilityReasons.entries.map((entry) {
      final index = compatibilityReasons.keys.toList().indexOf(entry.key);
      return StyleCompatibility(styleId: entry.key,
        score: (0.92 - index * .06).clamp(.55, .95).toDouble(),
        confidence: has(r'oxford') ? .86 : .72,
        justification: entry.value);
    }).toList(growable: false);

    return StyleAnalysis(inputFingerprint: input.fingerprint,
      suggestedRegister: register,
      suggestedSecondaryStyles: secondary.toSet().toList(),
      suggestedCharacteristics: characteristics.toSet().toList(),
      suggestedCompatibilities: compatibilities,
      evidence: evidence, calculatedAt: calculatedAt ?? DateTime.now().toUtc(),
    ).retainCorrectionsFrom(previous);
  }

  StyleAnalysis ensureCurrent(StyleInput input, StyleAnalysis? current,
      {DateTime? calculatedAt}) {
    if (current != null && current.modelVersion == StyleAnalysis.currentModelVersion &&
        current.taxonomyVersion == StyleTaxonomy.version &&
        current.inputFingerprint == input.fingerprint) {
      return current;
    }
    return classify(input, previous: current, calculatedAt: calculatedAt);
  }
}
