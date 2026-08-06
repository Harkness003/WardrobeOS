import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/catalogs/system_catalogs.dart';
import 'package:wardrobeos/models/style_analysis.dart';

void main() {
  test('every canonical style has resources in every locale', () {
    for (final locale in ['en', 'fr']) {
      final resource = jsonDecode(File('assets/i18n/$locale.json').readAsStringSync()) as Map;
      final styles = (resource['catalogs'] as Map)['style'] as Map;
      expect(styles.keys.toSet(), containsAll(StyleTaxonomy.entries.keys));
    }
  });

  test('legacy labels resolve without changing stored canonical IDs', () {
    expect(SystemCatalogs.canonicalId(SystemCatalogs.categories, 'Hauts'), 'tops');
    expect(SystemCatalogs.canonicalId(SystemCatalogs.materials, 'Mérinos'), 'merino_wool');
    expect(SystemCatalogs.canonicalId(SystemCatalogs.colors, 'Bleu marine'), 'dark_blue');
  });

  test('style analysis serializes canonical style identifiers unchanged', () {
    final value = StyleCompatibility(styleId: 'quiet_luxury', score: .8, justification: 'fixture');
    expect(value.toMap()['styleId'], 'quiet_luxury');
  });
}
