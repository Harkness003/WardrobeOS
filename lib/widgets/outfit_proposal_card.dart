import 'package:flutter/material.dart';

import '../core/outfit_generation/outfit_generation_engine.dart';
import 'garment_image.dart';

/// Canonical presentation of a generated outfit, shared by every feature.
class OutfitProposalCard extends StatelessWidget {
  final OutfitGenerationProposal proposal;
  final VoidCallback? onSave;
  final VoidCallback? onSelect;

  const OutfitProposalCard({super.key, required this.proposal, this.onSave, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final garments = proposal.outfit.allGarments;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 88, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: garments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => SizedBox(width: 88, child: GarmentImage(
              imagePath: garments[index].effectivePhotos.firstOrNull?.path,
              borderRadius: BorderRadius.circular(8),
            )),
          )),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text(proposal.outfit.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            Text('${(proposal.score * 100).round()} %'),
          ]),
          const SizedBox(height: 6),
          Text(garments.map((item) => item.name).join(' • ')),
          const SizedBox(height: 6),
          ...proposal.reasons.take(3).map((reason) => Text('• $reason')),
          if (onSave != null || onSelect != null) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (onSelect != null) TextButton(onPressed: onSelect, child: const Text('Choisir')),
              if (onSave != null) FilledButton.icon(onPressed: onSave,
                icon: const Icon(Icons.bookmark_add_outlined), label: const Text('Enregistrer')),
            ]),
          ],
        ]),
      ),
    );
  }
}
