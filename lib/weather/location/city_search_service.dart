import 'package:geocoding/geocoding.dart' as geocoding;

import 'location_service.dart';

abstract interface class CitySearchService {
  Future<List<LocationData>> search(String query);
}

class GeocodingCitySearchService implements CitySearchService {
  @override
  Future<List<LocationData>> search(String query) async {
    final city = query.trim();
    if (city.length < 2) return const [];
    final results = await geocoding.locationFromAddress(city);
    return results
        .map(
          (result) => LocationData(
            latitude: result.latitude,
            longitude: result.longitude,
            city: city,
          ),
        )
        .toList(growable: false);
  }
}
