import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'backup_file.dart';
import 'backup_service.dart';

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
    // V1 (pre-ZIP) was a single JSON document. Keep this adapter isolated so
    // future migrations can be appended without weakening the current format.
    if (bytes.isNotEmpty && utf8.decode(bytes, allowMalformed: true).trimLeft().startsWith('{')) {
      return _inspectLegacyJson(bytes);
    }
    final Archive zip;
    try { zip = ZipDecoder().decodeBytes(bytes, verify: true); }
    catch (_) { throw const BackupFormatException('Archive ZIP corrompue ou illisible.'); }
    final files = {for (final file in zip.files.where((f) => f.isFile)) file.name: file};
    final manifestFile = files['manifest.json'];
    if (manifestFile == null) throw const BackupFormatException('Fichier manifest.json manquant.');
    final BackupManifest manifest;
    try { manifest = BackupManifest.fromJson(jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, Object?>); }
    catch (e) { if (e is BackupFormatException) rethrow; throw const BackupFormatException('Manifeste corrompu.'); }
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
      // Progressive migration: absent sections from older schemas are empty.
      data[section] = file == null ? [] : decodeRows(file.content as List<int>, section);
    }
    final photos = <String, List<int>>{for (final e in files.entries.where((e) => e.key.startsWith('photos/'))) e.key: e.value.content as List<int>};
    return BackupArchive(manifest: manifest, sections: data, photos: photos);
  }

  BackupArchive _inspectLegacyJson(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      if (json['version'] != 1) {
        throw BackupFormatException('Ancienne version non prise en charge : ${json['version']}.');
      }
      final date = DateTime.tryParse(json['createdAt']?.toString() ?? '');
      if (date == null) throw const FormatException();
      final data = <String, List<Map<String, Object?>>>{};
      for (final section in sections) {
        final value = json[section];
        data[section] = value == null ? [] : decodeRows(utf8.encode(jsonEncode(value)), section);
      }
      final photos = <String, List<int>>{};
      for (final item in (json['images'] as List? ?? const [])) {
        if (item is Map && item['data'] is String && item['reference'] != null) {
          photos['photos/${item['reference']}.jpg'] = base64Decode(item['data'] as String);
        }
      }
      data['garments'] = data['garments']!.map((source) {
        final row = Map<String, Object?>.from(source);
        final reference = row.remove('image_reference');
        row['backup_photo_references'] = reference == null
            ? <String>[] : <String>['photos/$reference.jpg'];
        return row;
      }).toList();
      return BackupArchive(
        manifest: BackupManifest(appVersion: 'ancienne', schemaVersion: 1,
          createdAt: date, garmentCount: data['garments']!.length,
          photoCount: photos.length,
          content: {for (final entry in data.entries) entry.key: entry.value.length}),
        sections: data, photos: photos,
      );
    } on BackupFormatException { rethrow; }
      catch (_) { throw const BackupFormatException('Ancienne sauvegarde JSON corrompue.'); }
  }

  Future<RestoreReport> restoreFile(String path) async => restore(await inspectFile(path));
  Future<RestoreReport> restore(BackupArchive backup) async {
    final warnings = <String>[]; final imagePaths = <String, String>{};
    Directory? directory;
    for (final entry in backup.photos.entries) {
      try {
        directory ??= await imageDirectory(); await directory.create(recursive: true);
        final target = File(p.join(directory.path, '${DateTime.now().microsecondsSinceEpoch}_${p.basename(entry.key)}'));
        await target.writeAsBytes(entry.value, flush: true); imagePaths[entry.key] = target.path;
      } catch (_) { warnings.add('Photo non restaurée : ${p.basename(entry.key)}'); }
    }
    final data = Map<String, List<Map<String, Object?>>>.from(backup.sections);
    data['garments'] = (data['garments'] ?? const []).map((source) {
      final row = Map<String, Object?>.from(source);
      final refs = (row.remove('backup_photo_references') as List?)?.cast<String>() ?? const [];
      row['image_path'] = refs.isEmpty ? null : imagePaths[refs.first];
      if (refs.any((ref) => !imagePaths.containsKey(ref))) warnings.add('Photos absentes pour « ${row['name'] ?? row['id']} ».');
      return row;
    }).toList();
    await repository.restoreData(data);
    return RestoreReport(backup.manifest, {for (final e in data.entries) e.key: e.value.length}, warnings);
  }
}
