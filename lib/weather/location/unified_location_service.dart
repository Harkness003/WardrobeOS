import 'package:flutter/foundation.dart';

import 'city_search_service.dart';
import 'location_preferences_store.dart';
import 'location_service.dart';

/// Unique location source for weather and every feature that needs a place.
/// A configured manual city wins; otherwise resolution falls back to GPS.
class UnifiedLocationService extends ChangeNotifier
    implements LocationService {
  final LocationService gpsService;
  final LocationPreferencesStore preferencesStore;
  final CitySearchService citySearchService;

  LocationPreferences _preferences = const LocationPreferences();
  Future<void>? _loading;

  UnifiedLocationService({
    required this.gpsService,
    required this.preferencesStore,
    required this.citySearchService,
  });

  LocationPreferences get preferences => _preferences;
  LocationMode get mode => _preferences.mode;
  LocationData? get manualLocation => _preferences.manualLocation;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    _preferences = await preferencesStore.read();
    notifyListeners();
  }

  Future<List<LocationData>> searchCities(String query) =>
      citySearchService.search(query);

  Future<void> useGps() => _save(
    LocationPreferences(
      mode: LocationMode.gps,
      manualLocation: _preferences.manualLocation,
    ),
  );

  Future<void> useManualMode() => _save(
    LocationPreferences(
      mode: LocationMode.manual,
      manualLocation: _preferences.manualLocation,
    ),
  );

  Future<void> useManualLocation(LocationData location) => _save(
    LocationPreferences(mode: LocationMode.manual, manualLocation: location),
  );

  Future<void> clearManualLocation() =>
      _save(const LocationPreferences(mode: LocationMode.manual));

  Future<void> _save(LocationPreferences preferences) async {
    await load();
    await preferencesStore.write(preferences);
    _preferences = preferences;
    notifyListeners();
  }

  @override
  Future<LocationData> getCurrentLocation() async {
    await load();
    if (_preferences.usesManualLocation) return _preferences.manualLocation!;
    return gpsService.getCurrentLocation();
  }
}
