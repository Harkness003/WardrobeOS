import 'dart:io';
import 'dart:math' as math;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;
import 'garment_scan_result.dart';

class GarmentScannerService {
  Future<GarmentScanResult> analyze(String imagePath) async {
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.35),
    );

    List<ImageLabel> detected = const [];
    try {
      detected = await labeler.processImage(InputImage.fromFilePath(imagePath));
    } finally {
      await labeler.close();
    }

    final labels =
        detected.take(10).map((label) => label.label.toLowerCase()).toList();

    final category = _categoryFrom(labels);
    final material = _materialFrom(labels, category);
    final season = _seasonFrom(category, material);
    final color = await _dominantColorName(imagePath);
    final confidence =
        detected.isEmpty
            ? 0.35
            : detected.map((label) => label.confidence).reduce(math.max);

    return GarmentScanResult(
      suggestedName: _suggestedName(category, color),
      category: category,
      color: color,
      material: material,
      season: season,
      confidence: confidence.clamp(0.0, 1.0),
      labels: labels,
      typePrecis: labels.isEmpty ? null : labels.first,
      descriptionIA:
          labels.isEmpty ? null : 'Vêtement identifié : ${labels.take(3).join(', ')}.',
      saisons: [season],
      avertissementsIA:
          detected.isEmpty ? const ['Analyse visuelle peu concluante'] : const [],
    );
  }

  String _categoryFrom(List<String> labels) {
    bool containsAny(List<String> words) =>
        labels.any((label) => words.any(label.contains));

    if (containsAny([
      'shoe',
      'footwear',
      'sneaker',
      'boot',
      'sandal',
      'high heels',
    ])) {
      return 'Chaussures';
    }
    if (containsAny([
      'jacket',
      'coat',
      'blazer',
      'outerwear',
      'hoodie',
      'suit',
    ])) {
      return 'Vestes';
    }
    if (containsAny(['shirt', 'dress shirt', 'collar', 'blouse'])) {
      return 'Chemises';
    }
    if (containsAny(['trousers', 'pants', 'jeans', 'shorts', 'skirt'])) {
      return 'Bas';
    }
    if (containsAny([
      'bag',
      'handbag',
      'watch',
      'belt',
      'hat',
      'glasses',
      'jewellery',
    ])) {
      return 'Accessoires';
    }
    if (containsAny([
      'clothing',
      't-shirt',
      'sweater',
      'jersey',
      'top',
      'sportswear',
    ])) {
      return 'Hauts';
    }
    return 'Autre';
  }

  String _materialFrom(List<String> labels, String category) {
    bool contains(String word) => labels.any((label) => label.contains(word));

    if (contains('denim') || contains('jeans')) return 'Denim';
    if (contains('leather') || contains('shoe')) return 'Cuir';
    if (contains('wool') || contains('knit') || contains('sweater')) {
      return 'Laine';
    }
    if (contains('silk')) return 'Soie';
    if (contains('linen')) return 'Lin';
    if (category == 'Chaussures') return 'Cuir';
    if (category == 'Vestes') return 'Textile';
    return 'Coton';
  }

  String _seasonFrom(String category, String material) {
    if (material == 'Laine') return 'Hiver';
    if (material == 'Lin') return 'Été';
    if (category == 'Vestes') return 'Automne';
    if (category == 'Chaussures' || category == 'Accessoires') {
      return 'Toute saison';
    }
    return 'Toute saison';
  }

  String _suggestedName(String category, String color) {
    final singular = switch (category) {
      'Chaussures' => 'Chaussures',
      'Vestes' => 'Veste',
      'Chemises' => 'Chemise',
      'Bas' => 'Pantalon',
      'Accessoires' => 'Accessoire',
      'Hauts' => 'Haut',
      _ => 'Nouvelle pièce',
    };
    return '$singular ${color.toLowerCase()}';
  }

  Future<String> _dominantColorName(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return 'Non détectée';

    final reduced = img.copyResize(
      decoded,
      width: 48,
      height: 48,
      interpolation: img.Interpolation.average,
    );

    double red = 0;
    double green = 0;
    double blue = 0;
    double weightTotal = 0;

    for (final pixel in reduced) {
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();

      final maxChannel = math.max(r, math.max(g, b));
      final minChannel = math.min(r, math.min(g, b));
      final saturation = maxChannel - minChannel;
      final brightness = (r + g + b) / 3;

      // White studio backgrounds are deliberately down-weighted.
      var weight = 1.0;
      if (brightness > 230 && saturation < 20) weight = 0.06;
      if (brightness < 18) weight = 0.25;

      red += r * weight;
      green += g * weight;
      blue += b * weight;
      weightTotal += weight;
    }

    if (weightTotal == 0) return 'Non détectée';

    return _nearestColorName(
      red / weightTotal,
      green / weightTotal,
      blue / weightTotal,
    );
  }

  String _nearestColorName(double r, double g, double b) {
    const palette = <String, List<int>>{
      'Noir': [28, 28, 28],
      'Blanc': [238, 238, 232],
      'Gris': [135, 135, 135],
      'Bleu marine': [35, 48, 72],
      'Bleu': [55, 105, 165],
      'Beige': [194, 174, 143],
      'Marron': [105, 72, 48],
      'Camel': [176, 124, 66],
      'Vert': [69, 112, 75],
      'Kaki': [105, 107, 65],
      'Rouge': [165, 48, 45],
      'Bordeaux': [105, 35, 48],
      'Rose': [205, 128, 148],
      'Violet': [105, 72, 135],
      'Jaune': [213, 178, 59],
      'Orange': [207, 112, 42],
    };

    var winner = 'Gris';
    var best = double.infinity;

    for (final entry in palette.entries) {
      final pr = entry.value[0].toDouble();
      final pg = entry.value[1].toDouble();
      final pb = entry.value[2].toDouble();
      final distance =
          math.pow(r - pr, 2) + math.pow(g - pg, 2) + math.pow(b - pb, 2);
      if (distance < best) {
        best = distance.toDouble();
        winner = entry.key;
      }
    }
    return winner;
  }
}
