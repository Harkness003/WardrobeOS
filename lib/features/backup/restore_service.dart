import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup_file.dart';
import 'backup_service.dart';

class RestoreService {
  final BackupRepository repository;
  final Future<Directory> Function() imageDirectory;

  RestoreService({
    required this.repository,
    Future<Directory> Function()? imageDirectory,
  }) : imageDirectory = imageDirectory ?? _defaultImageDirectory;

  static Future<Directory> _defaultImageDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'garment_images'));
  }

  Future<BackupFile> restoreFile(String path) async =>
      restore(await File(path).readAsString());

  Future<BackupFile> restore(String source) async {
    final backup = BackupFile.decode(source);
    final imagePaths = <String, String>{};
    Directory? directory;

    for (final image in backup.images) {
      try {
        directory ??= await imageDirectory();
        await directory.create(recursive: true);
        final reference = image['reference'] as String;
        final safeName = p.basename(
          image['fileName'] as String? ?? '$reference.jpg',
        );
        final timestamp = DateTime.now().microsecondsSinceEpoch;
        final target = File(p.join(directory.path, '${timestamp}_$safeName'));
        await target.writeAsBytes(
          base64Decode(image['data'] as String),
          flush: true,
        );
        imagePaths[reference] = target.path;
      } catch (_) {
        // Image restoration is best-effort; relational data must still restore.
      }
    }

    final garments = backup.garments
        .map((row) {
          final restored = Map<String, Object?>.from(row);
          final reference = restored.remove('image_reference') as String?;
          restored['image_path'] =
              reference == null ? null : imagePaths[reference];
          return restored;
        })
        .toList(growable: false);

    await repository.restoreData({
      'garments': garments,
      'outfits': backup.outfits,
      'outfitItems': backup.outfitItems,
      'wishlist': backup.wishlist,
      'wearHistory': backup.wearHistory,
    });
    return backup;
  }
}
