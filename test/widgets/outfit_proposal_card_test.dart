import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/outfit_generation/outfit_generation_engine.dart';
import 'package:wardrobeos/models/garment.dart';
import 'package:wardrobeos/models/outfit.dart';
import 'package:wardrobeos/widgets/outfit_proposal_card.dart';

void main() {
  testWidgets('affiche toutes les informations de la proposition canonique', (tester) async {
    final now = DateTime(2026, 8, 4);
    final garment = Garment(
      id: 'top',
      name: 'Chemise bleue',
      category: 'Hauts',
      createdAt: now,
      updatedAt: now,
    );
    final proposal = OutfitGenerationProposal(
      outfit: Outfit(
        id: 'proposal',
        name: 'Tenue recommandée',
        createdAt: now,
        updatedAt: now,
        garments: {OutfitCategory.top: [garment]},
      ),
      score: .87,
      reasons: const ['Couleurs et styles harmonieux.'],
      respectedConstraints: const ['Style souhaité'],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: OutfitProposalCard(proposal: proposal, onSave: () {})),
    ));

    expect(find.text('Tenue recommandée'), findsOneWidget);
    expect(find.text('Chemise bleue · Hauts'), findsOneWidget);
    expect(find.text('87 %'), findsOneWidget);
    expect(find.text('• Couleurs et styles harmonieux.'), findsOneWidget);
    expect(find.text('Style souhaité'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
  });

  testWidgets('reste lisible avec un titre long et une grande taille de texte', (tester) async {
    final now = DateTime(2026, 8, 4);
    final garments = List.generate(8, (index) => Garment(
      id: 'item-$index',
      name: 'Pièce numéro $index au nom volontairement très long',
      category: 'Accessoires',
      createdAt: now,
      updatedAt: now,
    ));
    final proposal = OutfitGenerationProposal(
      outfit: Outfit(id: 'long', name: 'Une tenue au titre extrêmement long qui doit rester lisible',
        createdAt: now, updatedAt: now,
        garments: {OutfitCategory.accessory: garments}),
      score: .75,
      reasons: const ['Adaptée à la demande.'],
    );

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(data: const MediaQueryData(size: Size(320, 800), textScaler: TextScaler.linear(2)),
        child: Scaffold(body: SingleChildScrollView(child: OutfitProposalCard(
          proposal: proposal, onSave: () {}, onSelect: () {})))),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('Choisir'), findsOneWidget);
  });
}
