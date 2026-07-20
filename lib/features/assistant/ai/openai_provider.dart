import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../settings/api_key_storage.dart';
import 'llm_provider.dart';

class OpenAiProvider implements LlmProvider {
  static const _endpoint = 'https://api.openai.com/v1/responses';

  final ApiKeyStorage _apiKeyStorage;
  final http.Client _client;
  final Duration timeout;
  final String model;

  OpenAiProvider({
    required ApiKeyStorage apiKeyStorage,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.model = 'gpt-5-mini',
  }) : _apiKeyStorage = apiKeyStorage,
       _client = client ?? http.Client();

  @override
  Future<String> generate(String prompt) async {
    final apiKey = await _apiKeyStorage.read();
    if (apiKey == null) throw const MissingApiKeyException();

    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $apiKey',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode({'model': model, 'input': prompt}),
          )
          .timeout(timeout);

      final body = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final apiMessage = _apiError(body);
        throw LlmApiException(
          response.statusCode == 401
              ? 'La clé API OpenAI est invalide.'
              : apiMessage ?? 'Le service IA a refusé la requête.',
        );
      }

      final text = _outputText(body);
      if (text == null || text.trim().isEmpty) {
        throw const LlmApiException(
          'Le service IA a renvoyé une réponse vide.',
        );
      }
      return text.trim();
    } on TimeoutException {
      throw const LlmTimeoutException();
    } on SocketException {
      throw const LlmNetworkException();
    } on http.ClientException {
      throw const LlmNetworkException();
    }
  }

  Map<String, dynamic> _decode(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  String? _apiError(Map<String, dynamic> body) {
    final error = body['error'];
    return error is Map<String, dynamic> && error['message'] is String
        ? error['message'] as String
        : null;
  }

  String? _outputText(Map<String, dynamic> body) {
    final direct = body['output_text'];
    if (direct is String) return direct;
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
}
