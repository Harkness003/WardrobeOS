import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

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
    final places = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    final city =
        places.isEmpty
            ? 'Position actuelle'
            : (places.first.locality ?? 'Position actuelle');
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      city: city,
    );
  }
}
