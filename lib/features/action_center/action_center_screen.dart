import 'package:flutter/material.dart';

import 'action_center_service.dart';

class ActionCenterScreen extends StatelessWidget {
  final ActionCenterService service;
  final VoidCallback openWardrobe;
  final VoidCallback retryBackup;
  const ActionCenterScreen({super.key, required this.service, required this.openWardrobe, required this.retryBackup});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Actions')),
    body: ListenableBuilder(listenable: service, builder: (context, _) {
      final items = service.items;
      if (items.isEmpty) return const Center(child: Semantics(liveRegion: true,
        label: 'Aucune action en attente', child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.task_alt, size: 48), SizedBox(height: 12), Text('Tout est à jour'),
          SizedBox(height: 4), Text('Aucune action n’attend ton intervention.'),
        ])));
      return ListView.separated(padding: const EdgeInsets.all(16), itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (context, index) => _card(context, items[index]));
    }),
  );

  Widget _card(BuildContext context, ActionCenterItem item) => Semantics(
    container: true, label: '${item.title}. ${item.description}. Priorité ${_priority(item.priority)}',
    child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(_icon(item.kind), color: _color(context, item.priority)), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 4), Text(item.description),
        ])),
      ]),
      const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton(onPressed: () => _primary(item), child: Text(item.primaryLabel)),
        TextButton(onPressed: () => _dismiss(context, item), child: const Text('Ignorer')),
      ]),
    ])),
  );

  Future<void> _primary(ActionCenterItem item) async {
    switch (item.kind) {
      case ActionCenterKind.importFailed:
        await service.retryFailedImports();
        return;
      case ActionCenterKind.backupFailed:
        retryBackup();
        return;
      case ActionCenterKind.garmentsToReview:
      case ActionCenterKind.importCompleted:
        openWardrobe();
        return;
      default:
        service.dismiss(item.id);
        return;
    }
  }

  void _dismiss(BuildContext context, ActionCenterItem item) {
    service.dismiss(item.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Action ignorée'), action: SnackBarAction(
      label: 'Annuler', onPressed: () => service.restoreDismissed(item))));
  }

  static String _priority(ActionCenterPriority value) => switch (value) {
    ActionCenterPriority.urgent => 'urgente', ActionCenterPriority.high => 'haute',
    ActionCenterPriority.normal => 'normale', ActionCenterPriority.low => 'basse'};
  static IconData _icon(ActionCenterKind kind) => switch (kind) {
    ActionCenterKind.garmentsToReview => Icons.fact_check_outlined,
    ActionCenterKind.importFailed => Icons.file_upload_outlined,
    ActionCenterKind.importCompleted => Icons.inventory_2_outlined,
    ActionCenterKind.backupSucceeded => Icons.cloud_done_outlined,
    ActionCenterKind.backupFailed => Icons.cloud_off_outlined,
    ActionCenterKind.calendarSyncFailed => Icons.event_busy_outlined,
    ActionCenterKind.weatherUnavailable => Icons.cloud_off_outlined,
    ActionCenterKind.conflict => Icons.compare_arrows,
    ActionCenterKind.reanalysisAvailable => Icons.auto_awesome_outlined,
  };
  static Color _color(BuildContext context, ActionCenterPriority value) => switch (value) {
    ActionCenterPriority.urgent => Theme.of(context).colorScheme.error,
    ActionCenterPriority.high => Colors.orange.shade800,
    ActionCenterPriority.normal => Theme.of(context).colorScheme.primary,
    ActionCenterPriority.low => Theme.of(context).colorScheme.secondary,
  };
}
