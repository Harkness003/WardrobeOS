import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'backup_file.dart';
import 'backup_service.dart';
import 'restore_service.dart';

class BackupController extends ChangeNotifier {
  final BackupService backupService; final RestoreService restoreService;
  final Future<void> Function()? afterRestore;
  bool busy = false; BackupManifest? lastBackup; String? lastLocation; String? result;
  String? pendingPath; BackupArchive? pendingRestore;
  BackupController({required this.backupService, required this.restoreService,
    this.afterRestore});

  static String defaultFileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'WardrobeOS_backup_${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}-${two(now.minute)}.zip';
  }
  Future<void> createBackup() async {
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Enregistrer la sauvegarde WardrobeOS',
      fileName: defaultFileName(DateTime.now()), type: FileType.custom, allowedExtensions: const ['zip']);
    if (path == null) return;
    await _run(() async { final archive = await backupService.createBackup();
      lastBackup = await backupService.writeBackup(archive, path); lastLocation = path;
      result = 'Sauvegarde réussie : ${lastBackup!.garmentCount} vêtements et ${lastBackup!.photoCount} photos exportés.'; });
  }
  Future<bool> selectRestore() async {
    final selection = await FilePicker.platform.pickFiles(dialogTitle: 'Choisir une sauvegarde WardrobeOS',
      type: FileType.custom, allowedExtensions: const ['zip']);
    final path = selection?.files.single.path; if (path == null) return false;
    var ready = false; await _run(() async { pendingRestore = await restoreService.inspectFile(path); pendingPath = path; ready = true; }); return ready;
  }
  Future<void> confirmRestore() async { final archive = pendingRestore; if (archive == null) return;
    await _run(() async { final report = await restoreService.restore(archive);
      await afterRestore?.call();
      final total = report.restored.values.fold<int>(0, (a, b) => a + b);
      result = '$total éléments restaurés (${report.manifest.garmentCount} vêtements, ${report.manifest.photoCount} photos).'
        '${report.warnings.isEmpty ? '' : ' Avertissements : ${report.warnings.join(' ')}'}'; pendingRestore = null; pendingPath = null; }); }
  Future<void> _run(Future<void> Function() operation) async { busy = true; result = null; notifyListeners();
    try { await operation(); } catch (error) { result = 'Échec : ${_friendlyError(error)}'; } finally { busy = false; notifyListeners(); } }

  String _friendlyError(Object error) {
    if (error is BackupFormatException) return error.message;
    final text = error.toString().toLowerCase();
    if (text.contains('cancel')) return 'Opération annulée.';
    if (text.contains('permission') || text.contains('denied')) {
      return 'WardrobeOS n’a pas accès à cet emplacement. Choisis un autre dossier.';
    }
    if (text.contains('space') || text.contains('no space')) {
      return 'Espace de stockage insuffisant pour terminer l’opération.';
    }
    return 'Opération impossible. Vérifie le fichier ou l’emplacement choisi, puis réessaie.';
  }
}
