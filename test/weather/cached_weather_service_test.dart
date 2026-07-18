import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/weather/api/weather_api.dart';
import 'package:wardrobeos/weather/location/location_service.dart';
import 'package:wardrobeos/weather/services/cached_weather_service.dart';

void main() {
  late _FakeLocationService location;
  late _FakeWeatherApi api;
  late DateTime now;
  late CachedWeatherService service;

  setUp(() {
    location = _FakeLocationService();
    api = _FakeWeatherApi();
    now = DateTime(2026, 7, 18, 10);
    service = CachedWeatherService(
      locationService: location,
      weatherApi: api,
      now: () => now,
    );
  });

  test('réutilise la météo pendant moins de quinze minutes', () async {
    final first = await service.getCurrentWeather();
    now = now.add(const Duration(minutes: 14, seconds: 59));
    final second = await service.getCurrentWeather();
    expect(identical(first, second), isTrue);
    expect(api.calls, 1);
    expect(location.calls, 1);
  });

  test('rafraîchit un cache arrivé à expiration', () async {
    await service.getCurrentWeather();
    now = now.add(const Duration(minutes: 15));
    await service.getCurrentWeather();
    expect(api.calls, 2);
  });

  test('force le rafraîchissement et permet de vider le cache', () async {
    await service.getCurrentWeather();
    await service.getCurrentWeather(forceRefresh: true);
    service.clearCache();
    await service.getCurrentWeather();
    expect(api.calls, 3);
  });
}

class _FakeLocationService implements LocationService {
  int calls = 0;
  @override
  Future<LocationData> getCurrentLocation() async {
    calls++;
    return const LocationData(latitude: 48.86, longitude: 2.35, city: 'Paris');
  }
}

class _FakeWeatherApi implements WeatherApi {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> fetchCurrent({
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    return {
      'latitude': latitude,
      'longitude': longitude,
      'current': {
        'temperature_2m': 20,
        'apparent_temperature': 19,
        'relative_humidity_2m': 60,
        'wind_speed_10m': 8,
        'wind_direction_10m': 180,
        'weather_code': 1,
        'time': '2026-07-18T10:00',
      },
    };
  }
}
