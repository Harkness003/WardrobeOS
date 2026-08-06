import 'dart:convert';
import 'dart:io';

/// CI gate for the single `assets/i18n` localization system.
void main() {
  final errors = <String>[];
  final files = Directory('assets/i18n').listSync().whereType<File>()
      .where((file) => file.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (files.map((f) => f.uri.pathSegments.last).join(',') != 'en.json,fr.json') {
    errors.add('Locales must be en.json and fr.json until one is explicitly added.');
  }
  final resources = <String, Map<String, Object?>>{};
  for (final file in files) {
    try {
      resources[file.path] = Map<String, Object?>.from(jsonDecode(file.readAsStringSync()) as Map);
    } on Object catch (error) {
      errors.add('${file.path}: invalid JSON ($error)');
    }
  }
  if (resources.isNotEmpty) {
    final reference = _leafPaths(resources.values.first);
    for (final entry in resources.entries.skip(1)) {
      final paths = _leafPaths(entry.value);
      for (final missing in reference.difference(paths)) {
        errors.add('${entry.key}: missing translation $missing');
      }
      for (final extra in paths.difference(reference)) {
        errors.add('${entry.key}: unexpected translation $extra');
      }
    }
    for (final entry in resources.entries) {
      final catalogs = entry.value['catalogs'];
      if (catalogs is! Map) { errors.add('${entry.key}: missing catalogs'); continue; }
      for (final kind in const ['style', 'category', 'material', 'color']) {
        final catalog = catalogs[kind];
        if (catalog is! Map || catalog.isEmpty) { errors.add('${entry.key}: empty $kind catalog'); continue; }
        for (final item in catalog.entries) {
          final value = item.value;
          if (value is! Map || (value['name'] as String?)?.trim().isEmpty != false) {
            errors.add('${entry.key}: $kind.${item.key} has no clean name');
          }
        }
      }
    }
  }
  final dartFiles = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  final canonicalDisplay = RegExp(r'''Text\s*\(\s*(?:[^\n;]*\.)?(?:id|styleId|category|material|color)\b''');
  final translatedComparison = RegExp(r'''(?:name|label|displayName)\s*(?:==|!=)\s*['\"]''');
  for (final file in dartFiles) {
    final source = file.readAsStringSync();
    if (canonicalDisplay.hasMatch(source)) errors.add('${file.path}: possible canonical identifier rendered by Text');
    if (translatedComparison.hasMatch(source)) errors.add('${file.path}: possible comparison against displayed text');
    if (source.contains("rootBundle.loadString('assets/i18n/") && !file.path.endsWith('lib/l10n/app_localizations.dart')) {
      errors.add('${file.path}: competing localization loader');
    }
  }
  if (errors.isNotEmpty) {
    stderr.writeln('i18n audit failed (${errors.length} issue(s)):');
    for (final error in errors) stderr.writeln(' - $error');
    exitCode = 1;
  } else {
    stdout.writeln('i18n audit passed: resources and architecture are consistent.');
  }
}

Set<String> _leafPaths(Object? value, [String prefix = '']) {
  if (value is Map) {
    return {for (final entry in value.entries) ..._leafPaths(entry.value, prefix.isEmpty ? '${entry.key}' : '$prefix.${entry.key}')};
  }
  return {prefix};
}
