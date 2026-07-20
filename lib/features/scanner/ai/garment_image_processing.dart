import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class GarmentImageValidationResult {
  final bool isValid;
  final List<String> warnings;
  final String? rejectionReason;
  final int? width;
  final int? height;
  final int? originalSizeBytes;

  const GarmentImageValidationResult({
    required this.isValid,
    this.warnings = const [],
    this.rejectionReason,
    this.width,
    this.height,
    this.originalSizeBytes,
  });
}

class GarmentImageValidator {
  static const supportedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};
  static const int maximumInputBytes = 20 * 1024 * 1024;
  static const int minimumDimension = 64;

  const GarmentImageValidator();

  Future<GarmentImageValidationResult> validateFile(
    String path, {
    String? mimeType,
  }) async {
    final file = File(path);
    if (!await file.exists()) return _rejected('Le fichier image est introuvable.');
    try {
      return validateBytes(await file.readAsBytes(), mimeType: mimeType ?? mimeTypeForPath(path));
    } on FileSystemException {
      return _rejected('Le fichier image est illisible.');
    }
  }

  GarmentImageValidationResult validateBytes(
    Uint8List bytes, {
    String? mimeType,
  }) {
    if (bytes.isEmpty) return _rejected('L’image est vide.', size: 0);
    final detected = detectMimeType(bytes);
    final type = detected ?? mimeType;
    if (type == null || !supportedMimeTypes.contains(type)) {
      return _rejected('Ce format d’image n’est pas pris en charge.', size: bytes.length);
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return _rejected('L’image est endommagée ou illisible.', size: bytes.length);
    if (decoded.width < minimumDimension || decoded.height < minimumDimension) {
      return _rejected('Les dimensions de l’image sont trop petites.', size: bytes.length);
    }
    final warnings = <String>[];
    if (bytes.length > maximumInputBytes) warnings.add('L’image sera réduite avant analyse.');
    if (decoded.width < 400 || decoded.height < 400) warnings.add('La définition de la photo est faible.');
    return GarmentImageValidationResult(
      isValid: true,
      warnings: List.unmodifiable(warnings),
      width: decoded.width,
      height: decoded.height,
      originalSizeBytes: bytes.length,
    );
  }

  GarmentImageValidationResult _rejected(String reason, {int? size}) =>
      GarmentImageValidationResult(isValid: false, rejectionReason: reason, originalSizeBytes: size);

  static String? mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return null;
  }

  static String? detectMimeType(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return 'image/jpeg';
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e && bytes[3] == 0x47) return 'image/png';
    if (bytes.length >= 12 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') return 'image/webp';
    return null;
  }
}

class PreparedGarmentImage {
  final Uint8List bytes;
  final String mimeType;
  final int originalSizeBytes;
  final int preparedSizeBytes;
  final int width;
  final int height;
  final bool wasResized;
  final bool wasCompressed;

  const PreparedGarmentImage({required this.bytes, required this.mimeType, required this.originalSizeBytes, required this.preparedSizeBytes, required this.width, required this.height, required this.wasResized, required this.wasCompressed});
}

class GarmentImagePreprocessor {
  final int maxDimension;
  final int jpegQuality;
  const GarmentImagePreprocessor({this.maxDimension = 1800, this.jpegQuality = 86});

  Future<PreparedGarmentImage> prepareFile(String path) async => prepareBytes(await File(path).readAsBytes(), mimeType: GarmentImageValidator.mimeTypeForPath(path));

  PreparedGarmentImage prepareBytes(Uint8List source, {String? mimeType}) {
    var image = img.decodeImage(source);
    if (image == null) throw const FormatException('Image indécodable');
    image = img.bakeOrientation(image);
    final resized = image.width > maxDimension || image.height > maxDimension;
    if (resized) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxDimension)
          : img.copyResize(image, height: maxDimension);
    }
    final detected = GarmentImageValidator.detectMimeType(source) ?? mimeType ?? 'image/jpeg';
    final encoded = detected == 'image/png'
        ? Uint8List.fromList(img.encodePng(image, level: 6))
        : Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
    final outputType = detected == 'image/png' ? 'image/png' : 'image/jpeg';
    return PreparedGarmentImage(bytes: encoded, mimeType: outputType, originalSizeBytes: source.length, preparedSizeBytes: encoded.length, width: image.width, height: image.height, wasResized: resized, wasCompressed: encoded.length < source.length || outputType != detected);
  }
}
