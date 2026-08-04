import 'package:flutter/material.dart';
import '../../core/outfit_generation/outfit_generation_engine.dart';
import '../../widgets/outfit_proposal_card.dart';
import '../../widgets/content_state.dart';
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
          if (!c.calendarAvailable) const Padding(padding: EdgeInsets.only(top: 8), child: ContentState.error(
            title: 'Calendrier indisponible',
            message: 'Les journées restent visibles, mais leurs événements ne peuvent pas être pris en compte.',
            actionLabel: null)),
          if (c.error != null) Padding(padding: const EdgeInsets.only(top: 8), child: ContentState.error(
            title: 'Impossible de charger cette semaine',
            message: 'L’agenda n’a pas pu être actualisé. Vérifie l’accès au calendrier puis réessaie.',
            onAction: c.load)),
        ])),
        if (c.loading) const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: ContentState.loading(
          title: 'Chargement de l’agenda', message: 'Préparation des événements et des tenues de la semaine…')),
        Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), itemCount: 7, itemBuilder: (_, i) {
          final day = c.weekStart.add(Duration(days: i)); return _DayCard(date: day,
            plan: c.forDay(day), state: c.stateFor(day),
            failure: c.dayErrors[DateTime(day.year, day.month, day.day)],
            onDetails: () => _showDetails(c.forDay(day)),
            onAction: (action) => _act(day, c.forDay(day), action));
        })),
      ])));
  }

  Future<void> _showDetails(PlannedOutfit? plan) async {
    if (plan == null) return;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (context) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (plan.outfit case final outfit?)
            OutfitProposalCard(proposal: OutfitGenerationProposal(
              outfit: outfit,
              score: outfit.score?.overallConfidence.value ?? 0,
              reasons: plan.justification.isEmpty ? outfit.justification : [plan.justification],
            )),
          if (plan.outfit == null)
            Text('Tenue indisponible', style: Theme.of(context).textTheme.titleLarge),
          if (plan.event != null) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_outlined), title: Text(plan.event!.title)),
          if (plan.weather != null) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.cloud_outlined), title: Text('${plan.weather!.temperature.round()}° · ${plan.weather!.description}')),
        ]))));
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
  final DateTime date; final PlannedOutfit? plan; final AgendaDayState state;
  final String? failure;
  final ValueChanged<String> onAction; final VoidCallback onDetails;
  const _DayCard({required this.date, required this.plan, required this.state, this.failure,
    required this.onAction, required this.onDetails});
  @override Widget build(BuildContext context) {
    final localeDays = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'];
    return Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: plan == null ? null : onDetails,
      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('${localeDays[date.weekday - 1]} ${date.day}', style: Theme.of(context).textTheme.titleMedium)),
        _StateBadge(state: state, status: plan?.status)]),
      const SizedBox(height: 6),
      Text(_summary, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600)),
      if (failure != null) ContentState.error(
        title: 'Proposition impossible pour cette journée',
        message: failure!, actionLabel: 'Réessayer', onAction: () => onAction('another')),
      if (failure == null && plan == null && state == AgendaDayState.noOutfit)
        const ContentState.empty(title: 'Journée sans tenue',
          message: 'Aucune tenue n’est encore planifiée. Tu peux demander une proposition.'),
      if (plan != null) Row(children: [
        Expanded(child: Text('${plan!.outfit?.allGarments.length ?? 0} pièces · Toucher pour les détails',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
        PopupMenuButton<String>(tooltip: 'Actions', onSelected: onAction, itemBuilder: (_) => [
          const PopupMenuItem(value: 'another', child: Text('Autre proposition')),
          const PopupMenuItem(value: 'replace', child: Text('Choisir une tenue enregistrée')),
          if (plan!.status == PlannedOutfitStatus.proposed) const PopupMenuItem(value: 'confirm', child: Text('Confirmer')),
          if (plan!.status != PlannedOutfitStatus.worn) const PopupMenuItem(value: 'worn', child: Text('Marquer portée')),
          const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
        ]),
      ]) else if (state != AgendaDayState.generating) Align(alignment: Alignment.centerRight,
        child: TextButton(onPressed: () => onAction('another'), child: const Text('Réessayer'))),
    ]))));
  }
  String get _summary => switch (state) {
    AgendaDayState.generating => 'Génération en cours…',
    AgendaDayState.noOutfit => 'Aucune tenue planifiée',
    AgendaDayState.error => 'Erreur de génération',
    AgendaDayState.generated => plan?.outfit?.name ?? 'Tenue générée',
    AgendaDayState.planned => plan?.outfit?.name ?? 'Tenue planifiée',
  };
  static String _status(PlannedOutfitStatus value) => switch(value) { PlannedOutfitStatus.proposed => 'Proposée', PlannedOutfitStatus.confirmed => 'Confirmée', PlannedOutfitStatus.worn => 'Portée', PlannedOutfitStatus.ignored => 'Ignorée', PlannedOutfitStatus.cancelled => 'Annulée' };
}

class _StateBadge extends StatelessWidget {
  final AgendaDayState state; final PlannedOutfitStatus? status;
  const _StateBadge({required this.state, required this.status});
  @override Widget build(BuildContext context) => Chip(label: Text(switch (state) {
    AgendaDayState.generating => 'Génération', AgendaDayState.noOutfit => 'Vide',
    AgendaDayState.error => 'Erreur', AgendaDayState.generated => 'Générée',
    AgendaDayState.planned => _DayCard._status(status!),
  }), visualDensity: VisualDensity.compact);
}
