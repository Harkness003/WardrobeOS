import 'dart:io';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/catalogs/system_catalogs.dart';
import 'package:wardrobeos/l10n/app_localizations.dart';
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

  test('regional and unknown locales follow the documented fallback policy', () {
    expect(AppLocalizations.resolveLocale(const Locale('fr', 'FR')), const Locale('fr'));
    expect(AppLocalizations.resolveLocale(const Locale('fr', 'CA')), const Locale('fr'));
    expect(AppLocalizations.resolveLocale(const Locale('en', 'GB')), const Locale('en'));
    expect(AppLocalizations.resolveLocale(const Locale('en', 'US')), const Locale('en'));
    expect(AppLocalizations.resolveLocale(const Locale('de', 'DE')), AppLocalizations.defaultLocale);
  });

  test('all locales expose the same complete translation surface', () {
    Set<String> leaves(Object? value, [String prefix = '']) => value is Map
        ? {for (final entry in value.entries) ...leaves(entry.value, '$prefix.${entry.key}')}
        : {prefix};
    final en = jsonDecode(File('assets/i18n/en.json').readAsStringSync());
    final fr = jsonDecode(File('assets/i18n/fr.json').readAsStringSync());
    expect(leaves(fr), leaves(en));
  });
}
