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

    final prepared = preprocessor.prepareBytes(request.imageBytes, mimeType: request.mimeType);
    final preparedRequest = request.copyWith(imageBytes: prepared.bytes, mimeType: prepared.mimeType);
    final body = _requestBody(preparedRequest);
    var attempt = 0;
    while (true) {
    try {
      final response = await client
          .post(
            endpoint,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $apiKey',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final exception = _httpException(response.statusCode);
        if (attempt++ < maxRetries && _isTransient(response.statusCode)) {
          await Future<void>.delayed(Duration(milliseconds: 100 * attempt));
          continue;
        }
        throw exception;
      }
      final responseBody = _decodeObject(response.body);
      final output = _outputText(responseBody);
      if (output == null || output.trim().isEmpty) {
        throw const GarmentAnalysisException(
          GarmentAnalysisError.emptyResponse,
          'OpenAI a renvoyé une réponse vide.',
        );
      }
      return GarmentAnalysisResult.fromJsonString(output);
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
            'text': 'Analyse cette photo selon les instructions.',
          },
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
l'étiquette reste prioritaire. Baisse la confiance si texture, couleur ou logo
sont peu visibles, si le vêtement est distant, froissé, masqué ou superposé.
Signale les incohérences et utilise null plutôt que d'inventer. Utilise exclusivement ces valeurs :
category=${jsonEncode(request.allowedCategories)}
primaryColor=${jsonEncode(request.allowedColors)}
material=${jsonEncode(request.allowedMaterials)}
season=${jsonEncode(request.allowedSeasons)}
Valeurs déjà saisies (contexte seulement, ne pas prétendre les avoir observées) :
${jsonEncode(request.existingValues)}
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
      'primaryColor',
      'material',
      'season',
      'visibleBrand',
      'globalConfidence',
      'fieldConfidences',
      'warnings',
      'imageQualityConfidence', 'isBlurry', 'isTooDark', 'isOverexposed',
      'garmentIsPartiallyHidden', 'garmentIsTooSmall',
      'multipleMainGarments', 'backgroundIsProblematic',
      'imageQualityWarnings',
    ],
    'properties': {
      'isUsableImage': {'type': 'boolean'},
      'rejectionReason': _nullableString,
      'suggestedName': _nullableString,
      'category': _nullableString,
      'primaryColor': _nullableString,
      'material': _nullableString,
      'season': _nullableString,
      'visibleBrand': _nullableString,
      'globalConfidence': {'type': 'number', 'minimum': 0, 'maximum': 1},
      'fieldConfidences': {
        'type': 'object',
        'additionalProperties': {'type': 'number', 'minimum': 0, 'maximum': 1},
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
