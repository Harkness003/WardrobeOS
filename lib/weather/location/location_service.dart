class LocationData {
  final double latitude;
  final double longitude;
  final String city;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
  });
}

enum LocationMode { gps, manual }

class LocationPreferences {
  final LocationMode mode;
  final LocationData? manualLocation;

  const LocationPreferences({
    this.mode = LocationMode.gps,
    this.manualLocation,
  });

  bool get usesManualLocation =>
      mode == LocationMode.manual && manualLocation != null;
}

sealed class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => message;
}

class LocationServicesDisabledException extends LocationException {
  const LocationServicesDisabledException() : super('Le GPS est désactivé.');
}

class LocationPermissionDeniedException extends LocationException {
  const LocationPermissionDeniedException()
    : super('Permission de localisation refusée.');
}

class LocationPermissionPermanentlyDeniedException extends LocationException {
  const LocationPermissionPermanentlyDeniedException()
    : super('Permission de localisation refusée définitivement.');
}

abstract interface class LocationService {
  Future<LocationData> getCurrentLocation();
}
