import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'backup_file.dart';
import 'backup_service.dart';
import '../../models/garment_photo.dart';

class RestoreReport {
  final BackupManifest manifest;
  final Map<String, int> restored;
  final List<String> warnings;
  const RestoreReport(this.manifest, this.restored, this.warnings);
}

class RestoreService {
  static const sections = ['garments','outfits','outfitItems','wishlist','wearHistory',
    'userMemories','userMemoryRevisions','personalGoals','styleProfiles','plannedOutfits'];
  final BackupRepository repository;
  final Future<Directory> Function() imageDirectory;
  RestoreService({required this.repository, Future<Directory> Function()? imageDirectory})
      : imageDirectory = imageDirectory ?? _defaultImageDirectory;
  static Future<Directory> _defaultImageDirectory() async => Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'garment_images'));

  Future<BackupArchive> inspectFile(String path) async => inspect(await File(path).readAsBytes());
  BackupArchive inspect(List<int> bytes) {
    final Archive zip;
    try { zip = ZipDecoder().decodeBytes(bytes, verify: true); }
    catch (_) { throw const BackupFormatException('Archive ZIP corrompue ou illisible.'); }
    final files = {for (final file in zip.files.where((f) => f.isFile)) file.name: file};
    final manifestFile = files['manifest.json'];
    if (manifestFile == null) throw const BackupFormatException('Fichier manifest.json manquant.');
    final BackupManifest manifest;
    try { manifest = BackupManifest.fromJson(jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, Object?>); }
    catch (e) { if (e is BackupFormatException) rethrow; throw const BackupFormatException('Manifeste corrompu.'); }
    final expectedDataFiles = sections.map((section) => 'data/$section.json').toSet();
    if (!manifest.content.keys.toSet().containsAll(sections) ||
        !manifest.checksums.keys.toSet().containsAll(expectedDataFiles)) {
      throw const BackupFormatException('Le manifeste ne déclare pas toutes les sections obligatoires.');
    }
    for (final entry in manifest.checksums.entries) {
      final file = files[entry.key];
      if (file == null) throw BackupFormatException('Fichier requis manquant : ${entry.key}.');
      if (sha256.convert(file.content as List<int>).toString() != entry.value) {
        throw BackupFormatException('Contrôle d’intégrité échoué : ${entry.key}.');
      }
    }
    final data = <String, List<Map<String, Object?>>>{};
    for (final section in sections) {
      final file = files['data/$section.json'];
      if (file == null) throw BackupFormatException('Section requise manquante : $section.');
      data[section] = decodeRows(file.content as List<int>, section);
      if (data[section]!.length != manifest.content[section]) {
        throw BackupFormatException('Nombre d’éléments incohérent dans la section « $section ».');
      }
    }
    final photos = <String, List<int>>{for (final e in files.entries.where((e) => e.key.startsWith('photos/'))) e.key: e.value.content as List<int>};
    final expectedChecksums = {...expectedDataFiles, ...photos.keys};
    if (manifest.checksums.keys.toSet().difference(expectedChecksums).isNotEmpty ||
        expectedChecksums.difference(manifest.checksums.keys.toSet()).isNotEmpty) {
      throw const BackupFormatException('La liste des fichiers ne correspond pas au manifeste.');
    }
    final referencedPhotos = <String>{};
    for (final garment in data['garments']!) {
      final List<GarmentPhoto> garmentPhotos;
      try {
        garmentPhotos = GarmentPhoto.decodeStrict(garment['photos']);
      } on FormatException {
        throw BackupFormatException('Photos canoniques invalides pour le vêtement ${garment['id']}.');
      }
      for (final photo in garmentPhotos) {
        if (photo.id.isEmpty || photo.path.isEmpty || !photos.containsKey(photo.path)) {
          throw BackupFormatException('Photo manquante ou invalide pour le vêtement ${garment['id']}.');
        }
        if (!referencedPhotos.add(photo.path)) {
          throw BackupFormatException('Référence de photo dupliquée : ${photo.path}.');
        }
      }
    }
    if (photos.length != manifest.photoCount || photos.keys.toSet().difference(referencedPhotos).isNotEmpty) {
      throw const BackupFormatException('Le nombre de photos ne correspond pas au manifeste.');
    }
    if (data['garments']!.length != manifest.garmentCount) {
      throw const BackupFormatException('Le nombre de vêtements ne correspond pas au manifeste.');
    }
    return BackupArchive(manifest: manifest, sections: data, photos: photos);
  }

  Future<RestoreReport> restoreFile(String path) async => restore(await inspectFile(path));
  Future<RestoreReport> restore(BackupArchive backup) async {
    // Re-validate archives constructed in memory as strictly as ZIP imports.
    if (backup.manifest.schemaVersion != BackupManifest.currentSchemaVersion) {
      throw const BackupFormatException('Version de sauvegarde incompatible.');
    }
    final imagePaths = <String, String>{};
    final createdFiles = <File>[];
    Directory? directory;
    try {
      for (final entry in backup.photos.entries) {
        directory ??= await imageDirectory(); await directory.create(recursive: true);
        final target = File(p.join(directory.path, '${DateTime.now().microsecondsSinceEpoch}_${p.basename(entry.key)}'));
        await target.writeAsBytes(entry.value, flush: true);
        createdFiles.add(target); imagePaths[entry.key] = target.path;
      }
      final data = Map<String, List<Map<String, Object?>>>.from(backup.sections);
      data['garments'] = (data['garments'] ?? const []).map((source) {
        final row = Map<String, Object?>.from(source);
        final restored = GarmentPhoto.decodeStrict(row['photos']).map((photo) {
          final localPath = imagePaths[photo.path];
          if (localPath == null) {
            throw BackupFormatException('Photo manquante pour le vêtement ${row['id']}.');
          }
          return GarmentPhoto(id: photo.id, path: localPath, type: photo.type,
            createdAt: photo.createdAt, semanticType: photo.semanticType);
        }).toList();
        row['photos'] = GarmentPhoto.encode(restored);
        return row;
      }).toList();
      await repository.restoreData(data);
      return RestoreReport(backup.manifest,
        {for (final e in data.entries) e.key: e.value.length}, const []);
    } catch (error) {
      for (final file in createdFiles) {
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Best-effort cleanup; the database transaction was not partially restored.
        }
      }
      rethrow;
    }
  }
}
