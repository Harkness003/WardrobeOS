import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/styles/style_library_screen.dart';
import 'package:wardrobeos/features/styles/style_repository.dart';
import 'package:wardrobeos/models/personal_style.dart';
import 'package:wardrobeos/models/style_analysis.dart';

class FakeStyles implements StyleRepository {
  final values = <LibraryStyle>[
    const LibraryStyle(id: 'system', name: 'Élégant', definition: 'Une allure soignée',
      description: 'Cérémonies et belles matières', isSystem: true,
      synonyms: ['habillé'], characteristics: ['raffiné']),
  ];
  bool deleteCalled = false;
  @override Future<List<LibraryStyle>> all() async => values;
  @override Future<LibraryStyle?> find(String id) async => values.where((e) => e.id == id).isEmpty ? null : values.firstWhere((e) => e.id == id);
  @override Future<void> save(PersonalStyle style) async { values.removeWhere((e) => e.id == style.id); values.add(LibraryStyle.personal(style)); }
  @override Future<void> delete(String id) async { deleteCalled = true; values.removeWhere((e) => e.id == id); }
}
void main() {
  test('search normalizes accents, case and simple separators', () {
    expect(StyleCatalog.normalize('  CHIC-Décontracté '), 'chic decontracte');
    expect(StyleCatalog.matches(const LibraryStyle(id: 'x', name: 'Élégant', definition: '', description: '', isSystem: true), 'elegant'), isTrue);
  });
  test('traduit les identifiants internes en libellés français', () {
    expect(StyleCatalog.displayName('smart_casual'), 'Chic décontracté');
    expect(StyleCatalog.displayName('dressy'), 'Habillé');
  });
  test('catalogue canonique sans doublon ni définition placeholder', () {
    expect(StyleTaxonomy.entries, hasLength(65));
    expect(StyleTaxonomy.entries.entries.every((entry) =>
      entry.key == entry.value.id &&
      entry.value.name.trim().isNotEmpty &&
      entry.value.definition.trim().isNotEmpty &&
      entry.value.description.trim().isNotEmpty &&
      entry.value.characteristics.isNotEmpty &&
      entry.value.typicalPieces.isNotEmpty), isTrue);
  });

  testWidgets('library opens, searches and displays a definition', (tester) async {
    await tester.pumpWidget(MaterialApp(home: StyleLibraryScreen(repository: FakeStyles())));
    await tester.pumpAndSettle();
    expect(find.text('Bibliothèque des styles'), findsOneWidget);
    await tester.enterText(find.byType(SearchBar), 'habille'); await tester.pump();
    expect(find.text('Élégant'), findsOneWidget);
    await tester.tap(find.text('Élégant')); await tester.pumpAndSettle();
    expect(find.text('Une allure soignée'), findsOneWidget);
  });
  testWidgets('system styles expose no destructive menu', (tester) async {
    await tester.pumpWidget(MaterialApp(home: StyleLibraryScreen(repository: FakeStyles())));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });
  testWidgets('personal style creation is available', (tester) async {
    final repository = FakeStyles();
    await tester.pumpWidget(MaterialApp(home: StyleLibraryScreen(repository: repository)));
    await tester.pumpAndSettle(); await tester.tap(find.text('Style personnel')); await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('personal-style-name')), 'Mon style');
    await tester.tap(find.text('Enregistrer')); await tester.pumpAndSettle();
    expect(repository.values.any((e) => e.name == 'Mon style'), isTrue);
  });
}
