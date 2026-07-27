import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../settings/api_key_storage.dart';
import 'llm_provider.dart';

class OpenAiProvider implements StreamingLlmProvider {
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
    final chunks = <String>[];
    await for (final chunk in generateStream(prompt)) {
      chunks.add(chunk);
    }
    final text = chunks.join().trim();
    if (text.isEmpty) {
      throw const LlmApiException('Le service IA a renvoyé une réponse vide.');
    }
    return text;
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    final apiKey = await _apiKeyStorage.read();
    if (apiKey == null) throw const MissingApiKeyException();

    try {
      final request = http.Request('POST', Uri.parse(_endpoint))
        ..headers.addAll({
          HttpHeaders.authorizationHeader: 'Bearer $apiKey',
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'text/event-stream',
        })
        ..body = jsonEncode({'model': model, 'input': prompt, 'stream': true});
      final response = await _client.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = _decode(await response.stream.bytesToString());
        final apiMessage = _apiError(body);
        throw LlmApiException(
          response.statusCode == 401
              ? 'La clé API OpenAI est invalide.'
              : apiMessage ?? 'Le service IA a refusé la requête.',
        );
      }

      var emittedText = false;
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty || data == '[DONE]') continue;
        final event = _decode(data);
        if (event['type'] == 'response.output_text.delta' &&
            event['delta'] is String) {
          yield event['delta'] as String;
          emittedText = true;
        } else if (event['type'] == 'error') {
          throw LlmApiException(_apiError(event) ?? 'Erreur de streaming IA.');
        }
      }
      if (!emittedText) {
        throw const LlmApiException(
          'Le service IA a renvoyé une réponse vide.',
        );
      }
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
}
