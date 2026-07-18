import 'intent_result.dart';

/// Contract for an intent engine, independent from its local or remote implementation.
abstract interface class AssistantIntent {
  IntentResult parse(String userMessage);
}
