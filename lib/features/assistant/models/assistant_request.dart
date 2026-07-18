enum AssistantRequestType {
  conversation,
  outfitSuggestion,
  shoppingAdvice,
  care,
}

class AssistantRequest {
  final String message;
  final AssistantRequestType type;
  final Map<String, Object?> constraints;

  const AssistantRequest({
    this.message = '',
    this.type = AssistantRequestType.conversation,
    this.constraints = const {},
  });
}
