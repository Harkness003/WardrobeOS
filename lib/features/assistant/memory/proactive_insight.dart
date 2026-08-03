enum ProactiveInsightType {
  outfit,
  relevantRemark,
  forgottenGarment,
  wardrobeImprovement,
  styleEvolution,
}

/// Candidate only: this sprint deliberately does not schedule notifications.
class ProactiveInsight {
  final String id;
  final ProactiveInsightType type;
  final String message;
  final double relevance;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const ProactiveInsight({
    required this.id,
    required this.type,
    required this.message,
    required this.relevance,
    required this.createdAt,
    this.expiresAt,
  }) : assert(relevance >= 0 && relevance <= 1);
}
