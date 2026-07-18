import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageStorageService {
  static const _uuid = Uuid();

  static Future<String> persist(String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(docs.path, 'garment_images'));
    if (!await folder.exists()) await folder.create(recursive: true);
    final extension = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final target = p.join(folder.path, '${_uuid.v4()}$extension');
    await File(sourcePath).copy(target);
    return target;
  }

  static Future<void> remove(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    final file = File(imagePath);
    if (await file.exists()) await file.delete();
  }
}
