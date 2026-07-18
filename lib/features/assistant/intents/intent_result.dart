import 'intent_type.dart';

class IntentResult {
  final AssistantIntentType type;
  final String originalText;
  final Map<String, String> parameters;

  IntentResult({
    required this.type,
    required this.originalText,
    Map<String, String> parameters = const {},
  }) : parameters = Map.unmodifiable(parameters);
}
