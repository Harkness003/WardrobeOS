abstract interface class LlmProvider {
  Future<String> generate(String prompt);
}

sealed class LlmException implements Exception {
  final String message;

  const LlmException(this.message);

  @override
  String toString() => message;
}

class MissingApiKeyException extends LlmException {
  const MissingApiKeyException() : super('Aucune clé API OpenAI configurée.');
}

class LlmNetworkException extends LlmException {
  const LlmNetworkException()
    : super('Impossible de joindre le service IA. Vérifiez votre connexion.');
}

class LlmTimeoutException extends LlmException {
  const LlmTimeoutException()
    : super('Le service IA met trop de temps à répondre. Réessayez.');
}

class LlmApiException extends LlmException {
  const LlmApiException(super.message);
}
