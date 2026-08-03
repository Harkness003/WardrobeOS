import 'package:flutter/material.dart';
import '../outfits/outfits_controller.dart';
import 'agenda_controller.dart';
import 'agenda_models.dart';

class AgendaScreen extends StatefulWidget {
  final AgendaController controller;
  final OutfitsController outfitsController;
  const AgendaScreen({super.key, required this.controller, required this.outfitsController});
  @override State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  @override void initState() { super.initState(); widget.controller.addListener(_refresh); widget.controller.load(); widget.outfitsController.load(); }
  void _refresh() { if (mounted) setState(() {}); }
  @override void dispose() { widget.controller.removeListener(_refresh); super.dispose(); }

  @override Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(appBar: AppBar(title: const Text('Agenda vestimentaire')),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 8), child: Column(children: [
          Row(children: [IconButton(onPressed: c.loading ? null : () => c.changeWeek(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text('${_date(c.weekStart)} — ${_date(c.weekStart.add(const Duration(days: 6)))}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
            IconButton(onPressed: c.loading ? null : () => c.changeWeek(1), icon: const Icon(Icons.chevron_right))]),
          Row(children: [Expanded(child: DropdownButtonFormField<PlanningStrategy>(value: c.preferences.strategy,
            decoration: const InputDecoration(labelText: 'Stratégie', isDense: true),
            items: PlanningStrategy.values.map((v) => DropdownMenuItem(value: v, child: Text(v.label))).toList(), onChanged: (v) { if (v != null) c.setStrategy(v); })),
            const SizedBox(width: 8), FilledButton.icon(onPressed: c.loading ? null : c.proposeWeek,
              icon: const Icon(Icons.auto_awesome, size: 18), label: const Text('Proposer ma semaine'))]),
          if (c.error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Certaines données sont indisponibles. Vos planifications sont conservées.', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ])),
        if (c.loading) const LinearProgressIndicator(),
        Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), itemCount: 7, itemBuilder: (_, i) {
          final day = c.weekStart.add(Duration(days: i)); return _DayCard(date: day, plan: c.forDay(day), onAction: (action) => _act(day, c.forDay(day), action));
        })),
      ])));
  }

  Future<void> _act(DateTime day, PlannedOutfit? plan, String action) async {
    switch (action) {
      case 'choose': case 'replace':
        final outfits = widget.outfitsController.outfits;
        final choice = await showModalBottomSheet(context: context, builder: (_) => SafeArea(child: ListView(shrinkWrap: true, children: [
          const ListTile(title: Text('Choisir une tenue')),
          for (final outfit in outfits) ListTile(title: Text(outfit.name), onTap: () => Navigator.pop(context, outfit)),
          if (outfits.isEmpty) const ListTile(title: Text('Aucune tenue enregistrée'), subtitle: Text('La proposition automatique peut composer une tenue depuis le dressing.')),
        ])));
        if (choice == null) return;
        if (plan == null) await widget.controller.plan(day, choice); else await widget.controller.replace(plan, choice);
        return;
      case 'another': await widget.controller.another(day, plan); return;
      case 'confirm': if (plan != null) await widget.controller.confirm(plan); return;
      case 'worn': if (plan != null) await widget.controller.markWorn(plan); return;
      case 'delete': if (plan != null) await widget.controller.remove(plan); return;
    }
  }
  static String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _DayCard extends StatelessWidget {
  final DateTime date; final PlannedOutfit? plan; final ValueChanged<String> onAction;
  const _DayCard({required this.date, required this.plan, required this.onAction});
  @override Widget build(BuildContext context) {
    final localeDays = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('${localeDays[date.weekday - 1]} ${date.day}', style: Theme.of(context).textTheme.titleMedium)),
        if (plan != null) Chip(label: Text(_status(plan!.status)), visualDensity: VisualDensity.compact)]),
      if (plan?.event != null) Text('Événement · ${plan!.event!.title}'),
      if (plan?.weather != null) Text('Météo · ${plan!.weather!.temperature.round()}° · ${plan!.weather!.description}')
      else if (plan != null) const Text('Météo non utilisée', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 6), Text(plan?.outfit?.name ?? 'Aucune tenue planifiée', style: const TextStyle(fontWeight: FontWeight.w600)),
      if (plan?.justification.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 4), child: Text(plan!.justification)),
      Wrap(spacing: 4, children: plan == null ? [TextButton(onPressed: () => onAction('choose'), child: const Text('Planifier')), TextButton(onPressed: () => onAction('another'), child: const Text('Proposer'))] : [
        TextButton(onPressed: () => onAction('replace'), child: const Text('Modifier / remplacer')),
        TextButton(onPressed: () => onAction('another'), child: const Text('Autre proposition')),
        if (plan!.status == PlannedOutfitStatus.proposed) TextButton(onPressed: () => onAction('confirm'), child: const Text('Confirmer')),
        if (plan!.status != PlannedOutfitStatus.worn) TextButton(onPressed: () => onAction('worn'), child: const Text('Marquer portée')),
        TextButton(onPressed: () => onAction('delete'), child: const Text('Supprimer')),
      ])
    ])));
  }
  static String _status(PlannedOutfitStatus value) => switch(value) { PlannedOutfitStatus.proposed => 'Proposée', PlannedOutfitStatus.confirmed => 'Confirmée', PlannedOutfitStatus.worn => 'Portée', PlannedOutfitStatus.ignored => 'Ignorée', PlannedOutfitStatus.cancelled => 'Annulée' };
}
