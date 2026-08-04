import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'location_service.dart';

abstract interface class LocationPreferencesStore {
  Future<LocationPreferences> read();
  Future<void> write(LocationPreferences preferences);
}

class SecureLocationPreferencesStore implements LocationPreferencesStore {
  static const _modeKey = 'location_mode';
  static const _cityKey = 'location_city';
  static const _latitudeKey = 'location_latitude';
  static const _longitudeKey = 'location_longitude';

  final FlutterSecureStorage _storage;

  SecureLocationPreferencesStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<LocationPreferences> read() async {
    final values = await _storage.readAll();
    final latitude = double.tryParse(values[_latitudeKey] ?? '');
    final longitude = double.tryParse(values[_longitudeKey] ?? '');
    final city = values[_cityKey];
    return LocationPreferences(
      mode:
          values[_modeKey] == LocationMode.manual.name
              ? LocationMode.manual
              : LocationMode.gps,
      manualLocation:
          city == null || city.isEmpty || latitude == null || longitude == null
              ? null
              : LocationData(
                latitude: latitude,
                longitude: longitude,
                city: city,
              ),
    );
  }

  @override
  Future<void> write(LocationPreferences preferences) async {
    final location = preferences.manualLocation;
    await Future.wait([
      _storage.write(key: _modeKey, value: preferences.mode.name),
      if (location == null) ...[
        _storage.delete(key: _cityKey),
        _storage.delete(key: _latitudeKey),
        _storage.delete(key: _longitudeKey),
      ] else ...[
        _storage.write(key: _cityKey, value: location.city),
        _storage.write(key: _latitudeKey, value: '${location.latitude}'),
        _storage.write(key: _longitudeKey, value: '${location.longitude}'),
      ],
    ]);
  }
}
