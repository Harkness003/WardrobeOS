import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/personal_style.dart';
import 'style_enrichment_service.dart';
import 'style_repository.dart';

class PersonalStyleFormScreen extends StatefulWidget {
  final StyleRepository repository; final PersonalStyle? initial;
  final StyleEnrichmentService? enrichment;
  const PersonalStyleFormScreen({super.key, required this.repository, this.initial, this.enrichment});
  @override State<PersonalStyleFormScreen> createState() => _State();
}
class _State extends State<PersonalStyleFormScreen> {
  late final name = TextEditingController(text: widget.initial?.name);
  late final description = TextEditingController(text: widget.initial?.description);
  late final notes = TextEditingController(text: widget.initial?.notes);
  late final examples = TextEditingController(text: widget.initial?.examples.join(', '));
  bool busy = false;
  PersonalStyle get value => PersonalStyle(id: widget.initial?.id ?? 'personal_${const Uuid().v4()}',
    name: name.text.trim(), description: description.text.trim(), notes: notes.text.trim(),
    examples: examples.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    characteristics: widget.initial?.characteristics ?? const [], colors: widget.initial?.colors ?? const [],
    materials: widget.initial?.materials ?? const [], occasions: widget.initial?.occasions ?? const [],
    typicalPieces: widget.initial?.typicalPieces ?? const []);
  Future<void> enrich() async { setState(() => busy = true); try {
    final proposal = await widget.enrichment!.propose(value); if (!mounted) return;
    final accepted = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Proposition IA'), content: SingleChildScrollView(child: Text('${proposal.description}\n\n${proposal.notes}\n\nExemples : ${proposal.examples.join(', ')}')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Refuser')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Utiliser la proposition'))]));
    if (accepted == true) { description.text = proposal.description; notes.text = proposal.notes; examples.text = proposal.examples.join(', '); }
  } finally { if (mounted) setState(() => busy = false); }}
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.initial == null ? 'Créer un style' : 'Modifier le style')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      TextField(key: const Key('personal-style-name'), controller: name, decoration: const InputDecoration(labelText: 'Nom')),
      TextField(controller: description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
      TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
      TextField(controller: examples, decoration: const InputDecoration(labelText: 'Exemples (séparés par des virgules)')),
      if (widget.enrichment != null) OutlinedButton.icon(onPressed: busy ? null : enrich, icon: const Icon(Icons.auto_awesome), label: const Text('Enrichir avec l’IA')),
      FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; await widget.repository.save(value); if (context.mounted) Navigator.pop(context, true); }, child: const Text('Enregistrer')),
    ]));
}
