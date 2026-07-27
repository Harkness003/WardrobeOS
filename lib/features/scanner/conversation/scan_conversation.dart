import '../ai/garment_analysis_result.dart';
import '../decision/scanner_decision_engine.dart';
import 'requested_photo.dart';

class ScanProgressItem {
  final String field;
  final String label;
  final bool confirmed;

  const ScanProgressItem(this.field, this.label, this.confirmed);
}

class ScanConversationDecision {
  final bool canFinishAutomatically;
  final RequestedPhoto? requestedPhoto;
  final List<ScanProgressItem> progress;

  const ScanConversationDecision({
    required this.canFinishAutomatically,
    required this.requestedPhoto,
    required this.progress,
  });
}

/// Compatibility adapter between the scanner flow and its decision engine.
/// Presentation code receives progress and follow-up decisions without owning
/// confidence or photo-selection rules.
class ScanConversationPolicy {
  static const confidenceThreshold = .72;

  const ScanConversationPolicy();

  ScanConversationDecision evaluate(GarmentAnalysisResult result) {
    final decision = const ScannerDecisionEngine().evaluate(result);
    const visibleFields = {
      'category',
      'primaryColor',
      'preciseType',
      'material',
      'style',
    };
    final progress = decision.fields
        .where((field) => visibleFields.contains(field.field))
        .map((field) => ScanProgressItem(
              field.field,
              field.label,
              !field.requiresVerification,
            ))
        .toList(growable: false);

    return ScanConversationDecision(
      canFinishAutomatically: decision.canFinishAutomatically,
      requestedPhoto: decision.requestedPhoto,
      progress: progress,
    );
  }
}
