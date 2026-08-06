import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The only user-facing translation gateway.
///
/// Business objects retain canonical identifiers. Catalogue resources are
/// loaded for the resolved application locale and never persisted.
class AppLocalizations {
  AppLocalizations._(this.locale, this._resources);

  final Locale locale;
  final Map<String, Object?> _resources;

  static const supportedLocales = [Locale('en'), Locale('fr')];
  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String text(String key) => _lookup(key) as String? ?? key;

  Map<String, Object?> catalogEntry(String catalog, String id) {
    final value = _lookup('catalogs.$catalog.$id');
    return value is Map ? Map<String, Object?>.from(value) : const {};
  }

  Object? _lookup(String path) {
    Object? current = _resources;
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
    final language = isSupported(locale) ? locale.languageCode : 'en';
    final raw = await rootBundle.loadString('assets/i18n/$language.json');
    return AppLocalizations._(Locale(language), Map<String, Object?>.from(jsonDecode(raw) as Map));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
