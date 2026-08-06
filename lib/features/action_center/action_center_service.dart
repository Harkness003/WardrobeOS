import 'dart:async';

import 'package:flutter/foundation.dart';

import '../scanner/analysis/wardrobe_import_service.dart';

enum ActionCenterKind { garmentsToReview, importFailed, importCompleted, backupSucceeded, backupFailed, calendarSyncFailed, weatherUnavailable, conflict, reanalysisAvailable }
enum ActionCenterPriority { urgent, high, normal, low }

@immutable
class ActionCenterItem {
  final String id;
  final ActionCenterKind kind;
  final ActionCenterPriority priority;
  final int count;
  final String title;
  final String description;
  final String primaryLabel;

  const ActionCenterItem({required this.id, required this.kind, required this.priority,
    required this.count, required this.title, required this.description, required this.primaryLabel});
}

/// Application-scoped UX inbox. It only projects already-computed module state:
/// it performs no database scan, polling, diagnosis, or business decision.
class ActionCenterService extends ChangeNotifier {
  final WardrobeImportService importService;
  final Map<String, ActionCenterItem> _transient = {};
  final Set<String> _ignoredImportTasks = {};
  StreamSubscription<WardrobeImportEvent>? _importEvents;

  ActionCenterService({required this.importService}) {
    importService.addListener(_moduleStateChanged);
    _importEvents = importService.events.listen((_) => _moduleStateChanged());
  }

  List<ActionCenterItem> get items {
    final result = <ActionCenterItem>[..._importItems(), ..._transient.values];
    result.sort((a, b) {
      final priority = a.priority.index.compareTo(b.priority.index);
      return priority != 0 ? priority : a.title.compareTo(b.title);
    });
    return List.unmodifiable(result);
  }

  List<ActionCenterItem> _importItems() {
    final tasks = importService.tasks.where((task) => !_ignoredImportTasks.contains(task.id));
    final review = tasks.where((task) => task.status == WardrobeImportStatus.needsReview).toList();
    final failed = tasks.where((task) => task.status == WardrobeImportStatus.failed).toList();
    final completed = tasks.where((task) => task.status == WardrobeImportStatus.completed).toList();
    return [
      if (review.isNotEmpty) ActionCenterItem(id: 'import-review', kind: ActionCenterKind.garmentsToReview,
        priority: ActionCenterPriority.high, count: review.length,
        title: '${review.length} vêtement${review.length > 1 ? 's' : ''} à vérifier',
        description: 'Confirme la catégorie, le type ou la couleur pour finaliser ${review.length > 1 ? 'ces fiches' : 'cette fiche'}.', primaryLabel: 'Corriger'),
      if (failed.isNotEmpty) ActionCenterItem(id: 'import-failed', kind: ActionCenterKind.importFailed,
        priority: ActionCenterPriority.urgent, count: failed.length,
        title: '${failed.length} import${failed.length > 1 ? 's' : ''} à reprendre',
        description: 'Les fiches n’ont pas été créées. Réessaie maintenant ou ignore ces photos.', primaryLabel: 'Réessayer'),
      if (completed.isNotEmpty) ActionCenterItem(id: 'import-completed', kind: ActionCenterKind.importCompleted,
        priority: ActionCenterPriority.low, count: completed.length,
        title: 'Import terminé', description: '${completed.length} vêtement${completed.length > 1 ? 's ont été ajoutés' : ' a été ajouté'} au dressing.', primaryLabel: 'Ouvrir'),
    ];
  }

  Future<void> retryFailedImports() async {
    final failed = importService.tasks.where((task) => task.status == WardrobeImportStatus.failed).toList();
    await Future.wait(failed.map((task) => importService.retry(task.id)));
  }

  void publishBackupResult({required bool succeeded, String? detail}) {
    final kind = succeeded ? ActionCenterKind.backupSucceeded : ActionCenterKind.backupFailed;
    _transient.remove(succeeded ? 'backup-failed' : 'backup-succeeded');
    _transient[succeeded ? 'backup-succeeded' : 'backup-failed'] = ActionCenterItem(
      id: succeeded ? 'backup-succeeded' : 'backup-failed', kind: kind,
      priority: succeeded ? ActionCenterPriority.low : ActionCenterPriority.high, count: 1,
      title: succeeded ? 'Sauvegarde prête' : 'Sauvegarde à relancer',
      description: succeeded ? (detail ?? 'La sauvegarde a été créée et peut être conservée en lieu sûr.')
        : (detail ?? 'La sauvegarde n’a pas pu être créée. Choisis un emplacement puis réessaie.'),
      primaryLabel: succeeded ? 'Ignorer' : 'Réessayer');
    notifyListeners();
  }

  void dismiss(String id) {
    if (id.startsWith('import-')) {
      final status = switch (id) {
        'import-review' => WardrobeImportStatus.needsReview,
        'import-failed' => WardrobeImportStatus.failed,
        _ => WardrobeImportStatus.completed,
      };
      _ignoredImportTasks.addAll(importService.tasks.where((task) => task.status == status).map((task) => task.id));
    } else {
      _transient.remove(id);
    }
    notifyListeners();
  }

  void restoreDismissed(ActionCenterItem item) {
    if (item.id.startsWith('import-')) {
      _ignoredImportTasks.clear();
    } else {
      _transient[item.id] = item;
    }
    notifyListeners();
  }

  void _moduleStateChanged() => notifyListeners();

  @override
  void dispose() {
    importService.removeListener(_moduleStateChanged);
    _importEvents?.cancel();
    super.dispose();
  }
}
