enum GarmentAnalysisError {
  missingApiKey,
  invalidApiKey,
  accessDenied,
  quotaExceeded,
  network,
  timeout,
  emptyResponse,
  invalidJson,
  invalidSchema,
  missingImage,
  unsupportedFormat,
  rejectedImage,
}

class GarmentAnalysisException implements Exception {
  final GarmentAnalysisError error;
  final String message;

  const GarmentAnalysisException(this.error, this.message);

  @override
  String toString() => message;
}
