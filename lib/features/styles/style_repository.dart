import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/personal_style.dart';
import '../../models/style_analysis.dart';

class LibraryStyle {
  final String id, name, definition, description;
  final bool isSystem;
  final List<String> synonyms, characteristics, colors, materials, occasions,
      typicalPieces, examples, relatedStyleIds, oppositeStyleIds;
  const LibraryStyle({required this.id, required this.name, required this.definition,
    required this.description, required this.isSystem, this.synonyms = const [],
    this.characteristics = const [], this.colors = const [], this.materials = const [],
    this.occasions = const [], this.typicalPieces = const [], this.examples = const [],
    this.relatedStyleIds = const [], this.oppositeStyleIds = const []});

  factory LibraryStyle.system(StyleDefinition value) => LibraryStyle(id: value.id,
    name: value.name, definition: value.definition, description: value.description,
    isSystem: true, synonyms: value.synonyms, characteristics: value.characteristics,
    colors: value.colors, materials: value.materials, occasions: value.occasions,
    typicalPieces: value.typicalPieces, examples: value.typicalPieces,
    relatedStyleIds: value.relatedStyleIds, oppositeStyleIds: value.oppositeStyleIds);
  factory LibraryStyle.personal(PersonalStyle value) => LibraryStyle(id: value.id,
    name: value.name, definition: value.description, description: value.description,
    isSystem: false, characteristics: value.characteristics, colors: value.colors,
    materials: value.materials, occasions: value.occasions,
    typicalPieces: value.typicalPieces, examples: value.examples);
}

abstract interface class StyleRepository {
  Future<List<LibraryStyle>> all();
  Future<LibraryStyle?> find(String id);
  Future<void> save(PersonalStyle style);
  Future<void> delete(String id);
}

class StyleCatalog extends ChangeNotifier implements StyleRepository {
  static const _key = 'personal_styles_v1';
  final FlutterSecureStorage _storage;
  StyleCatalog({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override Future<List<LibraryStyle>> all() async {
    final personal = await _load();
    return [...StyleTaxonomy.entries.values.map(LibraryStyle.system),
      ...personal.map(LibraryStyle.personal)];
  }
  @override Future<LibraryStyle?> find(String id) async {
    final system = StyleTaxonomy.entries[id];
    if (system != null) return LibraryStyle.system(system);
    for (final value in await _load()) { if (value.id == id) return LibraryStyle.personal(value); }
    return null;
  }
  @override Future<void> save(PersonalStyle style) async {
    final values = await _load();
    final index = values.indexWhere((e) => e.id == style.id);
    if (index < 0) { values.add(style); } else { values[index] = style; }
    await _storage.write(key: _key, value: jsonEncode(values.map((e) => e.toMap()).toList()));
    notifyListeners();
  }
  @override Future<void> delete(String id) async {
    if (StyleTaxonomy.entries.containsKey(id)) throw StateError('Un style système est immuable.');
    final values = await _load()..removeWhere((e) => e.id == id);
    await _storage.write(key: _key, value: jsonEncode(values.map((e) => e.toMap()).toList()));
    notifyListeners();
  }
  Future<List<PersonalStyle>> _load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e) => PersonalStyle.fromMap(Map<String, Object?>.from(e as Map))).toList();
  }

  static String normalize(String value) {
    const accented = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿœ';
    const plain =    'aaaaaaceeeeiiiinooooouuuuyyoe';
    var result = value.toLowerCase().trim();
    for (var i = 0; i < accented.length; i++) { result = result.replaceAll(accented[i], plain[i]); }
    return result.replaceAll(RegExp(r'[_-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  static String displayName(String idOrLabel) {
    final normalized = normalize(idOrLabel);
    for (final entry in StyleTaxonomy.entries.entries) {
      if (normalize(entry.key) == normalized ||
          normalize(entry.value.name) == normalized ||
          entry.value.synonyms.map(normalize).contains(normalized)) {
        return entry.value.name;
      }
    }
    return idOrLabel.replaceAll('_', ' ');
  }

  static bool matches(LibraryStyle style, String query) {
    final needle = normalize(query);
    if (needle.isEmpty) return true;
    final searchable = [style.name, ...style.synonyms, style.description,
      style.definition, ...style.characteristics].map(normalize).join(' ');
    return searchable.contains(needle) || needle.split(' ').every(searchable.contains);
  }
}
