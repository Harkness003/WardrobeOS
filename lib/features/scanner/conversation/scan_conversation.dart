import '../ai/garment_analysis_result.dart';
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

/// Centralizes the completion policy so presentation code never decides which
/// photo is useful. The model proposes one request; this policy accepts it only
/// when it targets information that is still uncertain.
class ScanConversationPolicy {
  static const confidenceThreshold = .72;

  const ScanConversationPolicy();

  ScanConversationDecision evaluate(GarmentAnalysisResult result) {
    final values = <String, String?>{
      'category': result.category,
      'primaryColor': result.primaryColor,
      'preciseType': result.preciseType,
      'material': result.material,
      'style': result.styleSummary,
    };
    const labels = <String, String>{
      'category': 'Catégorie',
      'primaryColor': 'Couleur',
      'preciseType': 'Sous-catégorie',
      'material': 'Matière',
      'style': 'Style',
    };
    bool confirmed(String field) =>
        values[field] != null &&
        (result.fieldConfidences[field] ?? result.globalConfidence) >=
            confidenceThreshold;

    final progress = labels.entries
        .map((entry) => ScanProgressItem(
              entry.key,
              entry.value,
              confirmed(entry.key),
            ))
        .toList(growable: false);
    final proposal = result.requestedPhoto;
    final requestIsUseful = proposal != null &&
        proposal.targetFields.any((field) => !confirmed(field));
    final essentialFieldsReady =
        confirmed('category') && confirmed('primaryColor');
    final canFinish = essentialFieldsReady &&
        result.globalConfidence >= confidenceThreshold &&
        (!result.needsMorePhotos || !requestIsUseful);

    return ScanConversationDecision(
      canFinishAutomatically: canFinish,
      requestedPhoto: canFinish || !requestIsUseful ? null : proposal,
      progress: progress,
    );
  }
}
