import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/widgets/content_state.dart';

void main() {
  testWidgets('présente un chargement explicite et accessible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: ContentState.loading(title: 'Chargement', message: 'Patiente un instant.'),
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Chargement'), findsOneWidget);
    expect(find.text('Patiente un instant.'), findsOneWidget);
  });

  testWidgets('présente une erreur avec une action', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ContentState.error(
      title: 'Échec', message: 'Une cause compréhensible.', onAction: () => retried = true,
    ))));
    await tester.tap(find.text('Réessayer'));
    expect(retried, isTrue);
  });

  testWidgets('supporte une grande taille de texte sur écran étroit', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MediaQuery(
      data: MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(2)),
      child: Scaffold(body: SingleChildScrollView(child: ContentState.empty(
        title: 'Aucun contenu disponible',
        message: 'Ajoute un premier élément pour commencer.',
      ))),
    )));
    expect(tester.takeException(), isNull);
  });

  testWidgets('présente un état vide avec une action contextuelle', (tester) async {
    var created = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ContentState.empty(
      title: 'Bibliothèque vide',
      message: 'Crée un premier élément.',
      actionLabel: 'Créer',
      onAction: () => created = true,
    ))));
    await tester.tap(find.text('Créer'));
    expect(created, isTrue);
  });

  testWidgets('annonce un succès détaillé fourni par l’écran', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ContentState.success(
      child: Text('12 vêtements et 24 photos restaurés.'),
    ))));
    expect(find.text('12 vêtements et 24 photos restaurés.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
