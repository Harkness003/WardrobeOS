enum AssistantResponseType {
  conversation,
  outfitSuggestions,
  shoppingAdvice,
  care,
}

class AssistantResponse {
  final String message;
  final AssistantResponseType type;
  final List<String> suggestions;

  const AssistantResponse({
    required this.message,
    this.type = AssistantResponseType.conversation,
    this.suggestions = const [],
  });
}
