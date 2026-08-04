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
}
