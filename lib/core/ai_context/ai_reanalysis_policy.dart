/// Result of comparing a new AI analysis with the value originally analyzed
/// and the current (possibly user-corrected) record.
class AiReanalysisDecision {
  final Map<String, Object?> applicable;
  final Map<String, Object?> protectedUserValues;

  AiReanalysisDecision({
    required Map<String, Object?> applicable,
    required Map<String, Object?> protectedUserValues,
  })  : applicable = Map.unmodifiable(applicable),
        protectedUserValues = Map.unmodifiable(protectedUserValues);
}

/// Pure three-way comparison used by future garment reanalysis flows.
///
/// A suggestion is applicable only when the stored value still equals the
/// baseline that was sent to the model. Any intervening edit is treated as a
/// user correction and returned separately for explicit confirmation.
class AiReanalysisPolicy {
  const AiReanalysisPolicy();

  AiReanalysisDecision compare({
    required Map<String, Object?> baseline,
    required Map<String, Object?> current,
    required Map<String, Object?> suggested,
  }) {
    final applicable = <String, Object?>{};
    final protected = <String, Object?>{};
    for (final entry in suggested.entries) {
      if (current[entry.key] == baseline[entry.key]) {
        applicable[entry.key] = entry.value;
      } else {
        protected[entry.key] = current[entry.key];
      }
    }
    return AiReanalysisDecision(
      applicable: applicable,
      protectedUserValues: protected,
    );
  }
}
