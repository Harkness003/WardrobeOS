import '../api/weather_api.dart';
import '../location/location_service.dart';
import '../mapping/weather_code_mapper.dart';
import '../models/weather_data.dart';
import 'weather_service.dart';

class CachedWeatherService implements WeatherService {
  static const cacheDuration = Duration(minutes: 15);
  final LocationService locationService;
  final WeatherApi weatherApi;
  final DateTime Function() _now;
  WeatherData? _cached;
  DateTime? _cachedAt;

  CachedWeatherService({
    required this.locationService,
    required this.weatherApi,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  Future<WeatherData> getCurrentWeather({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cached != null &&
        _now().difference(_cachedAt!) < cacheDuration) {
      return _cached!;
    }
    final location = await locationService.getCurrentLocation();
    final json = await weatherApi.fetchCurrent(
      latitude: location.latitude,
      longitude: location.longitude,
    );
    final parsed = WeatherData.fromOpenMeteoJson(json, city: location.city);
    _cached = parsed.copyWith(
      description: WeatherCodeMapper.description(parsed.weatherCode),
    );
    _cachedAt = _now();
    return _cached!;
  }

  @override
  void clearCache() {
    _cached = null;
    _cachedAt = null;
  }
}
