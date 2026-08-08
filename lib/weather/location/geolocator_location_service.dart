import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';
import '../../core/diagnostics/diagnostic_service.dart';

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationData> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServicesDisabledException();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationPermissionDeniedException();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDeniedException();
    }
    final position = await Geolocator.getCurrentPosition();
    // Reverse geocoding is only a label enrichment. Some Android geocoding
    // implementations throw PlatformException even though coordinates are
    // valid; that must not prevent Open-Meteo from receiving those coordinates.
    var city = 'Position actuelle';
    try {
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isNotEmpty) city = places.first.locality ?? city;
    } on Object catch (error) {
      DiagnosticService.instance.publish(module: DiagnosticModule.weather,
        level: AppDiagnosticLevel.warning, state: 'Coordonnées disponibles',
        summary: 'Nom de ville indisponible', source: 'GeolocatorLocationService',
        reason: 'reverseGeocodingUnavailable',
        details: {'technical': error.runtimeType.toString()});
    }
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      city: city,
    );
  }
}
