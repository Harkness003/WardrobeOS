import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../assistant/settings/api_key_storage.dart';
import 'garment_analysis_exception.dart';
import 'garment_analysis_request.dart';
import 'garment_analysis_result.dart';
import 'garment_vision_analyzer.dart';
import 'garment_image_processing.dart';

class GarmentAnalysisTimings {
  final Duration imagePreparation;
  final Duration aiCall;
  final Duration parsing;
  const GarmentAnalysisTimings({required this.imagePreparation, required this.aiCall, required this.parsing});
}

class OpenAiGarmentVisionAnalyzer implements GarmentVisionAnalyzer {
  static final Uri endpoint = Uri.parse('https://api.openai.com/v1/responses');
  static const defaultModel = 'gpt-4.1-mini';
  static const supportedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

  final ApiKeyStorage apiKeyStorage;
  final http.Client client;
  final Duration timeout;
  final String model;
  final GarmentImagePreprocessor preprocessor;
  final int maxRetries;
  final bool _ownsClient;
  GarmentAnalysisTimings? lastTimings;

  OpenAiGarmentVisionAnalyzer({
    required this.apiKeyStorage,
    http.Client? client,
    this.timeout = const Duration(seconds: 45),
    this.model = defaultModel,
    this.preprocessor = const GarmentImagePreprocessor(),
    this.maxRetries = 1,
  }) : client = client ?? http.Client(),
       _ownsClient = client == null;

  /// Releases the HTTP client created by this analyzer.
  void close() {
    if (_ownsClient) client.close();
  }

  @override
  Future<GarmentAnalysisResult> analyze(GarmentAnalysisRequest request) async {
    if (request.imageBytes.isEmpty) {
      throw const GarmentAnalysisException(
        GarmentAnalysisError.missingImage,
        'Aucune image à analyser.',
      );
    }
    if (!supportedMimeTypes.contains(request.mimeType)) {
      throw const GarmentAnalysisException(
        GarmentAnalysisError.unsupportedFormat,
        'Ce format d’image n’est pas pris en charge.',
      );
    }
    final apiKey = await apiKeyStorage.read();
    if (apiKey == null) {
      throw const GarmentAnalysisException(
        GarmentAnalysisError.missingApiKey,
        'Configurez votre clé OpenAI pour utiliser l’analyse IA.',
      );
    }

    final preparationWatch = Stopwatch()..start();
    final prepared = preprocessor.prepareBytes(request.imageBytes, mimeType: request.mimeType);
    final previous = request.previousImageBytes.map((bytes) => preprocessor.prepareBytes(
      bytes, mimeType: GarmentImageValidator.detectMimeType(bytes) ?? 'image/jpeg',
    ).bytes).toList(growable: false);
    final preparedRequest = request.copyWith(imageBytes: prepared.bytes, mimeType: prepared.mimeType, previousImageBytes: previous);
    preparationWatch.stop();
    final body = _requestBody(preparedRequest);
    var attempt = 0;
    while (true) {
      try {
        final aiWatch = Stopwatch()..start();
        final response = await client.post(
          endpoint,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${apiKey.trim()}',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(body),
        ).timeout(timeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final exception = _httpException(response.statusCode);
          if (attempt++ < maxRetries && _isTransient(response.statusCode)) {
            await Future<void>.delayed(Duration(milliseconds: 100 * attempt));
            continue;
          }
          throw exception;
        }
        aiWatch.stop();
        final parsingWatch = Stopwatch()..start();
        final responseBody = _decodeObject(response.body);
        final output = _outputText(responseBody);
        if (output == null || output.trim().isEmpty) {
          throw const GarmentAnalysisException(
            GarmentAnalysisError.emptyResponse,
            'OpenAI a renvoyé une réponse vide.',
          );
        }
        final result = GarmentAnalysisResult.fromJsonString(output);
        parsingWatch.stop();
        lastTimings = GarmentAnalysisTimings(imagePreparation: preparationWatch.elapsed, aiCall: aiWatch.elapsed, parsing: parsingWatch.elapsed);
        return result;
      } on GarmentAnalysisException {
        rethrow;
      } on TimeoutException {
        if (attempt++ < maxRetries) continue;
        throw const GarmentAnalysisException(
          GarmentAnalysisError.timeout,
          'L’analyse prend trop de temps. Réessayez.',
        );
      } on SocketException {
        throw const GarmentAnalysisException(
          GarmentAnalysisError.network,
          'Impossible de joindre OpenAI. Vérifiez votre connexion.',
        );
      } on http.ClientException {
        throw const GarmentAnalysisException(
          GarmentAnalysisError.network,
          'Impossible de joindre OpenAI. Vérifiez votre connexion.',
        );
      }
    }
  }

  bool _isTransient(int status) => status == 429 || status >= 500;

  Map<String, dynamic> _requestBody(GarmentAnalysisRequest request) => {
    'model': model,
    'instructions': _prompt(request),
    'input': [
      {
        'role': 'user',
        'content': [
          {
            'type': 'input_text',
            'text': request.previousImageBytes.isEmpty
                ? 'Analyse cette première photo selon les instructions.'
                : 'Mets à jour l’analyse en combinant toutes les photos. La dernière image répond à la demande précédente.',
          },
          ...request.previousImageBytes.map((bytes) => {
            'type': 'input_image',
            'image_url':
                'data:${GarmentImageValidator.detectMimeType(bytes) ?? 'image/jpeg'};base64,${base64Encode(bytes)}',
          }),
          {
            'type': 'input_image',
            'image_url':
                'data:${request.mimeType};base64,${base64Encode(request.imageBytes)}',
          },
        ],
      },
    ],
    'text': {
      'format': {
        'type': 'json_schema',
        'name': 'garment_analysis',
        'strict': true,
        'schema': _schema,
      },
    },
  };

  String _prompt(GarmentAnalysisRequest request) => '''
Tu analyses uniquement le vêtement principal visible. Ignore la personne, le
visage, le décor, le cintre et l'arrière-plan. N'identifie jamais une personne.
Réponds en ${request.language} et uniquement selon le schéma JSON. N'invente
jamais une marque ou une matière : utilise null lorsque ce n'est pas clairement
observable. Distingue une photo utilisable, imparfaite et inutilisable. Un léger
défaut produit un avertissement ; un vêtement minuscule ou plusieurs vêtements
principaux indissociables produisent un rejet. N'identifie personne, ne déduis
ni taille, ni prix, ni authenticité. L'entretien est une estimation visuelle et
l'étiquette reste prioritaire. Pour une étiquette, retranscris d'abord le texte
par OCR. Ne déduis jamais une composition depuis l'apparence et ne demande une
photo plus nette que si le texte est réellement illisible. Baisse la confiance si texture, couleur ou logo
sont peu visibles, si le vêtement est distant, froissé, masqué ou superposé.
Signale les incohérences et utilise null plutôt que d'inventer. Utilise exclusivement ces valeurs :
Combine toutes les images : une nouvelle photo complète l'analyse précédente et
ne la remplace jamais. Réévalue chaque champ et sa confiance. La plupart des
pièces doivent être finalisées avec une seule photo. Mets needsMorePhotos à true
uniquement si une photo ciblée peut améliorer de façon importante un champ
encore incertain. Ne demande qu'une seule photo à la fois, explique précisément
pourquoi elle est utile et indique les champs visés. Ne redemande jamais une vue
déjà fournie. Sinon mets needsMorePhotos à false et requestedPhoto à null.
Adapte la demande au vêtement : semelle, intérieur ou usure pour des chaussures ;
étiquette, col ou poignets pour une chemise ; doublure, fermeture ou rembourrage
pour un manteau. Explique toujours le bénéfice concret de la photo.
Dans compositions, conserve toutes les fibres et pourcentages lus, séparés en
main, lining et padding. Utilise la source ocr pour le texte lu et visual
seulement pour une matière directement observable. Ne crée aucune valeur incertaine.
« category » est la catégorie générale, choisie uniquement parmi les catégories
autorisées ci-dessous. « preciseType » est le type concret et précis observé
(par exemple chemise Oxford, blazer croisé, jean droit, pantalon cargo,
cardigan, trench ou baskets basses). Utilise null si l'image ne permet pas de
conclure et ne répète jamais exactement « category » dans « preciseType ».
Agis comme un styliste professionnel : observe, explique, argumente et nuance.
Produis un résumé, des points forts et faibles, des conseils concrets, les
couleurs, bas et chaussures compatibles, les couleurs moins adaptées, les
occasions idéales et déconseillées, une polyvalence expliquée et un verdict
franc. Ne flatte pas systématiquement et ne qualifie jamais une pièce
d'élégante, polyvalente ou belle sans justification. Tu peux dire qu'une coupe
est datée, une couleur difficile, un motif chargé ou la pièce peu polyvalente.
Chaque critique doit indiquer pourquoi et tout défaut doit mener à une solution
concrète. Mentionne dans analysisLimitations ce que l'image ne permet pas de
conclure (intérieur invisible, matière estimée, vêtement masqué, par exemple).
category=${jsonEncode(request.allowedCategories)}
primaryColor=${jsonEncode(request.allowedColors)}
material=${jsonEncode(request.allowedMaterials)}
season=${jsonEncode(request.allowedSeasons)}
Valeurs déjà saisies (contexte seulement, ne pas prétendre les avoir observées) :
${jsonEncode(request.existingValues)}
Analyse cumulée précédente : ${jsonEncode(request.previousAnalysis)}
''';

  static const _nullableString = {'type': ['string', 'null']};
  static const _schema = {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      'isUsableImage',
      'rejectionReason',
      'suggestedName',
      'category',
      'preciseType',
      'primaryColor',
      'material',
      'compositions',
      'season',
      'visibleBrand',
      'globalConfidence',
      'fieldConfidences',
      'warnings',
      'imageQualityConfidence', 'isBlurry', 'isTooDark', 'isOverexposed',
      'garmentIsPartiallyHidden', 'garmentIsTooSmall',
      'multipleMainGarments', 'backgroundIsProblematic',
      'imageQualityWarnings',
      'styleSummary', 'styleStrengths', 'styleWeaknesses', 'styleAdvice',
      'compatibleColors', 'lessSuitableColors', 'compatibleBottoms',
      'compatibleShoes', 'idealOccasions', 'discouragedOccasions',
      'versatilityExplanation', 'styleVerdict', 'analysisLimitations',
      'needsMorePhotos', 'requestedPhoto',
    ],
    'properties': {
      'isUsableImage': {'type': 'boolean'},
      'rejectionReason': _nullableString,
      'suggestedName': _nullableString,
      'category': _nullableString,
      'preciseType': _nullableString,
      'primaryColor': _nullableString,
      'material': _nullableString,
      'compositions': {
        'type': 'array',
        'items': {
          'type': 'object', 'additionalProperties': false,
          'required': ['section', 'material', 'percentage', 'source'],
          'properties': {
            'section': {'type': 'string', 'enum': ['main', 'lining', 'padding']},
            'material': {'type': 'string'},
            'percentage': {'type': ['number', 'null'], 'minimum': 0, 'maximum': 100},
            'source': {'type': 'string', 'enum': ['ocr', 'visual']},
          },
        },
      },
      'season': _nullableString,
      'visibleBrand': _nullableString,
      'globalConfidence': {'type': 'number', 'minimum': 0, 'maximum': 1},
      'fieldConfidences': {
  'type': 'array',
  'items': {
    'type': 'object',
    'additionalProperties': false,
    'required': ['field', 'confidence'],
    'properties': {
      'field': {'type': 'string'},
      'confidence': {
        'type': 'number',
        'minimum': 0,
        'maximum': 1,
      },
    },
  },
},
      'warnings': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'imageQualityConfidence': {'type': 'number', 'minimum': 0, 'maximum': 1},
      'isBlurry': {'type': ['boolean', 'null']},
      'isTooDark': {'type': ['boolean', 'null']},
      'isOverexposed': {'type': ['boolean', 'null']},
      'garmentIsPartiallyHidden': {'type': ['boolean', 'null']},
      'garmentIsTooSmall': {'type': ['boolean', 'null']},
      'multipleMainGarments': {'type': ['boolean', 'null']},
      'backgroundIsProblematic': {'type': ['boolean', 'null']},
      'imageQualityWarnings': {'type': 'array', 'items': {'type': 'string'}},
      'styleSummary': _nullableString,
      'styleStrengths': {'type': 'array', 'items': {'type': 'string'}},
      'styleWeaknesses': {'type': 'array', 'items': {'type': 'string'}},
      'styleAdvice': {'type': 'array', 'items': {'type': 'string'}},
      'compatibleColors': {'type': 'array', 'items': {'type': 'string'}},
      'lessSuitableColors': {'type': 'array', 'items': {'type': 'string'}},
      'compatibleBottoms': {'type': 'array', 'items': {'type': 'string'}},
      'compatibleShoes': {'type': 'array', 'items': {'type': 'string'}},
      'idealOccasions': {'type': 'array', 'items': {'type': 'string'}},
      'discouragedOccasions': {'type': 'array', 'items': {'type': 'string'}},
      'versatilityExplanation': _nullableString,
      'styleVerdict': _nullableString,
      'analysisLimitations': {'type': 'array', 'items': {'type': 'string'}},
      'needsMorePhotos': {'type': 'boolean'},
      'requestedPhoto': {
        'type': ['object', 'null'],
        'additionalProperties': false,
        'required': ['type', 'instruction', 'reason', 'targetFields'],
        'properties': {
          'type': {
            'type': 'string',
            'enum': ['composition_label', 'back', 'fabric_close_up', 'collar',
              'cuffs', 'lining', 'buttons', 'zipper', 'sole', 'interior',
              'wear', 'padding', 'logo', 'other'],
          },
          'instruction': {'type': 'string'},
          'reason': {'type': 'string'},
          'targetFields': {'type': 'array', 'items': {'type': 'string'}},
        },
      },
    },
  };

  Map<String, dynamic> _decodeObject(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Translated below without exposing the response body.
    }
    throw const GarmentAnalysisException(
      GarmentAnalysisError.invalidJson,
      'OpenAI a renvoyé une réponse illisible.',
    );
  }

  String? _outputText(Map<String, dynamic> body) {
    if (body['output_text'] is String) return body['output_text'] as String;
    final output = body['output'];
    if (output is! List) return null;
    for (final item in output.whereType<Map>()) {
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content.whereType<Map>()) {
        if (part['type'] == 'output_text' && part['text'] is String) {
          return part['text'] as String;
        }
      }
    }
    return null;
  }

  GarmentAnalysisException _httpException(int statusCode) => switch (
    statusCode
  ) {
    401 => const GarmentAnalysisException(
      GarmentAnalysisError.invalidApiKey,
      'La clé API OpenAI est invalide.',
    ),
    403 => const GarmentAnalysisException(
      GarmentAnalysisError.accessDenied,
      'OpenAI a refusé l’accès à l’analyse.',
    ),
    429 => const GarmentAnalysisException(
      GarmentAnalysisError.quotaExceeded,
      'Le quota OpenAI est dépassé. Réessayez plus tard.',
    ),
    _ => const GarmentAnalysisException(
      GarmentAnalysisError.network,
      'Le service OpenAI est temporairement indisponible.',
    ),
  };
}
