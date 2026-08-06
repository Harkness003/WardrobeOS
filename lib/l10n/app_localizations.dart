import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The only user-facing translation gateway.
///
/// Business objects retain canonical identifiers. Catalogue resources are
/// loaded for the resolved application locale and never persisted.
class AppLocalizations {
  AppLocalizations._(this.locale, this._resources, this._fallbackResources,
      this._searchResources);

  final Locale locale;
  final Map<String, Object?> _resources;
  final Map<String, Object?> _fallbackResources;
  final List<Map<String, Object?>> _searchResources;

  static const defaultLocale = Locale('en');

  static const supportedLocales = [Locale('en'), Locale('fr')];
  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  /// Resolves regional variants to their supported language. Unknown locales
  /// deliberately use English; no persistence or business data is involved.
  static Locale resolveLocale(Locale locale) => switch (locale.languageCode.toLowerCase()) {
        'fr' => const Locale('fr'),
        'en' => const Locale('en'),
        _ => defaultLocale,
      };

  String text(String key, {String fallback = '—'}) =>
      _lookup(_resources, key) as String? ??
      _lookup(_fallbackResources, key) as String? ??
      fallback;

  Map<String, Object?> catalogEntry(String catalog, String id) {
    final path = 'catalogs.$catalog.$id';
    final value = _lookup(_resources, path) ?? _lookup(_fallbackResources, path);
    return value is Map ? Map<String, Object?>.from(value) : const {};
  }

  /// Localized names and synonyms from every supported resource. Search never
  /// indexes the canonical identifier itself.
  Iterable<String> catalogSearchTerms(String catalog, String id) sync* {
    for (final resources in _searchResources) {
      final entry = _lookup(resources, 'catalogs.$catalog.$id');
      if (entry is! Map) continue;
      final name = entry['name'];
      if (name is String) yield name;
      final synonyms = entry['synonyms'];
      if (synonyms is List) yield* synonyms.whereType<String>();
    }
  }

  static Object? _lookup(Map<String, Object?> resources, String path) {
    Object? current = resources;
    for (final segment in path.split('.')) {
      if (current is! Map || !current.containsKey(segment)) return null;
      current = current[segment];
    }
    return current;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((value) => value.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final resolved = AppLocalizations.resolveLocale(locale);
    final loaded = <String, Map<String, Object?>>{};
    for (final language in AppLocalizations.supportedLocales.map((e) => e.languageCode)) {
      final raw = await rootBundle.loadString('assets/i18n/$language.json');
      loaded[language] = Map<String, Object?>.from(jsonDecode(raw) as Map);
    }
    return AppLocalizations._(
      resolved,
      loaded[resolved.languageCode]!,
      loaded[AppLocalizations.defaultLocale.languageCode]!,
      List.unmodifiable(loaded.values),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
