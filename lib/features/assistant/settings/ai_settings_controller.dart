import 'package:flutter/foundation.dart';

import '../ai/llm_provider.dart';
import 'api_key_storage.dart';

class AiSettingsController extends ChangeNotifier {
  final ApiKeyStorage _storage;
  final LlmProvider _provider;

  bool _configured = false;
  bool _busy = false;

  AiSettingsController({
    required ApiKeyStorage storage,
    required LlmProvider provider,
  }) : _storage = storage,
       _provider = provider;

  bool get configured => _configured;
  bool get busy => _busy;

  Future<void> load() async {
    _configured = await _storage.exists();
    notifyListeners();
  }

  Future<void> save(String apiKey) async {
    await _run(() async {
      await _storage.save(apiKey);
      _configured = true;
    });
  }

  Future<void> delete() async {
    await _run(() async {
      await _storage.delete();
      _configured = false;
    });
  }

  Future<String> testConnection() async {
    try {
      final response = await _run(
        () => _provider.generate(
          'Réponds uniquement par OK pour tester la connexion.',
        ),
      );
      if (response.trim().isEmpty) {
        return 'Le service IA a renvoyé une réponse vide.';
      }
      return 'Connexion IA réussie';
    } on LlmException catch (error) {
      return error.message;
    } catch (_) {
      return 'Impossible de tester la connexion IA.';
    }
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
