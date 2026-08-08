import 'package:flutter/material.dart';
import 'garment_reanalysis_models.dart';

class GarmentReanalysisComparison extends StatefulWidget {
  final GarmentReanalysisProposal proposal;
  final Future<void> Function(Set<String> acceptedFields) onApply;
  const GarmentReanalysisComparison({super.key, required this.proposal, required this.onApply});
  @override State<GarmentReanalysisComparison> createState() => _GarmentReanalysisComparisonState();
}

class _GarmentReanalysisComparisonState extends State<GarmentReanalysisComparison> {
  final Set<String> accepted = {};
  bool saving = false;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Proposition de réanalyse')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text('${widget.proposal.changes.length} champ(s) modifié(s)', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      for (final change in widget.proposal.changes) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(change.field, style: const TextStyle(fontWeight: FontWeight.bold))), if (change.conflict) const Chip(label: Text('Conflit'))]),
        Text('Ancienne analyse : ${change.oldAnalysis ?? '—'}'), Text('Valeur actuelle : ${change.currentValue ?? '—'}'), Text('Proposition IA : ${change.proposedValue ?? '—'}'),
        RadioGroup<bool>(
          groupValue: accepted.contains(change.field),
          onChanged: (value) => setState(() {
            if (value == true) {
              accepted.add(change.field);
            } else {
              accepted.remove(change.field);
            }
          }),
          child: Row(children: [
            Expanded(child: RadioListTile<bool>(value: false, title: const Text('Conserver ma valeur'))),
            Expanded(child: RadioListTile<bool>(value: true, title: const Text('Accepter l’IA'))),
          ]),
        ),
      ]))),
      Wrap(spacing: 8, children: [
        OutlinedButton(onPressed: () => setState(accepted.clear), child: const Text('Conserver toutes mes modifications')),
        FilledButton.tonal(onPressed: () => setState(() { accepted.clear(); accepted.addAll(widget.proposal.nonConflicting.map((c) => c.field)); }), child: const Text('Accepter toutes sans conflit')),
      ]),
      const SizedBox(height: 12), FilledButton(onPressed: saving ? null : () async { setState(() => saving = true); try { await widget.onApply(Set.unmodifiable(accepted)); if (!context.mounted) return; Navigator.pop(context, true); } finally { if (mounted) setState(() => saving = false); } }, child: Text(saving ? 'Enregistrement…' : 'Appliquer la sélection')),
    ]),
  );
}
