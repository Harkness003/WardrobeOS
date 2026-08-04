import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/weather/location/city_search_service.dart';
import 'package:wardrobeos/weather/location/location_preferences_store.dart';
import 'package:wardrobeos/weather/location/location_service.dart';
import 'package:wardrobeos/weather/location/unified_location_service.dart';

void main() {
  const paris = LocationData(
    latitude: 48.8566,
    longitude: 2.3522,
    city: 'Paris',
  );
  const lyon = LocationData(latitude: 45.764, longitude: 4.8357, city: 'Lyon');

  test('conserve le comportement GPS par défaut', () async {
    final gps = _Gps(lyon);
    final service = _service(gps: gps);

    expect(await service.getCurrentLocation(), same(lyon));
    expect(gps.calls, 1);
  });

  test('la ville manuelle est prioritaire et évite tout appel GPS', () async {
    final gps = _Gps(lyon);
    final store = _Store(
      const LocationPreferences(
        mode: LocationMode.manual,
        manualLocation: paris,
      ),
    );
    final service = _service(gps: gps, store: store);

    expect(await service.getCurrentLocation(), same(paris));
    expect(gps.calls, 0);
  });

  test('changement et suppression de ville sont persistés', () async {
    final gps = _Gps(lyon);
    final store = _Store();
    final service = _service(gps: gps, store: store);

    await service.useManualLocation(paris);
    expect(store.value.manualLocation, same(paris));
    expect(await service.getCurrentLocation(), same(paris));

    await service.useManualLocation(lyon);
    expect(await service.getCurrentLocation(), same(lyon));

    await service.clearManualLocation();
    expect(store.value.mode, LocationMode.manual);
    expect(store.value.manualLocation, isNull);
    expect(await service.getCurrentLocation(), same(lyon));
    expect(gps.calls, 1);
  });

  test(
    'une erreur ou un refus GPS reste une absence de localisation explicite',
    () async {
      final service = _service(
        gps: _Gps.error(const LocationPermissionDeniedException()),
      );

      expect(
        service.getCurrentLocation(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
    },
  );

  test('restaure le mode et les coordonnées après redémarrage', () async {
    final store = _Store(
      const LocationPreferences(
        mode: LocationMode.manual,
        manualLocation: paris,
      ),
    );
    final restarted = _service(gps: _Gps(lyon), store: store);

    await restarted.load();
    expect(restarted.mode, LocationMode.manual);
    expect(restarted.manualLocation?.latitude, paris.latitude);
  });
}

UnifiedLocationService _service({
  required _Gps gps,
  _Store? store,
}) => UnifiedLocationService(
  gpsService: gps,
  preferencesStore: store ?? _Store(),
  citySearchService: _Search(),
);

class _Gps implements LocationService {
  final LocationData? value;
  final Object? error;
  int calls = 0;

  _Gps(this.value) : error = null;
  _Gps.error(this.error) : value = null;

  @override
  Future<LocationData> getCurrentLocation() async {
    calls++;
    if (error != null) throw error!;
    return value!;
  }
}

class _Store implements LocationPreferencesStore {
  LocationPreferences value;
  _Store([this.value = const LocationPreferences()]);

  @override
  Future<LocationPreferences> read() async => value;

  @override
  Future<void> write(LocationPreferences preferences) async =>
      value = preferences;
}

class _Search implements CitySearchService {
  @override
  Future<List<LocationData>> search(String query) async => const [];
}
