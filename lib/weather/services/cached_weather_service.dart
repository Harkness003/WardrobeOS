import '../api/weather_api.dart';
import '../location/location_service.dart';
import '../mapping/weather_code_mapper.dart';
import '../models/weather_data.dart';
import 'weather_service.dart';
import '../../core/diagnostics/diagnostic_service.dart';

class CachedWeatherService implements WeatherService {
  static const cacheDuration = Duration(minutes: 15);
  final LocationService locationService;
  final WeatherApi weatherApi;
  final DateTime Function() _now;
  WeatherData? _cached;
  DateTime? _cachedAt;
  Future<WeatherData>? _inFlight;

  CachedWeatherService({
    required this.locationService,
    required this.weatherApi,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  Future<WeatherData> getCurrentWeather({bool forceRefresh = false}) async {
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        _now().difference(cachedAt) < cacheDuration) {
      return cached;
    }
    if (!forceRefresh && _inFlight != null) return _inFlight!;
    final request = _fetch();
    _inFlight = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  Future<WeatherData> _fetch() async {
    final stopwatch = Stopwatch()..start();
    try {
      final location = await locationService.getCurrentLocation();
      final json = await weatherApi.fetchCurrent(
        latitude: location.latitude, longitude: location.longitude,
      );
      final parsed = WeatherData.fromOpenMeteoJson(json, city: location.city);
      final result = parsed.copyWith(description: WeatherCodeMapper.description(parsed.weatherCode));
      _cached = result;
      _cachedAt = _now();
      DiagnosticService.instance.publish(module: DiagnosticModule.weather,
        level: AppDiagnosticLevel.success, state: 'Disponible', summary: 'Météo actualisée',
        source: weatherApi.runtimeType.toString(), duration: stopwatch.elapsed,
        details: {'ville': location.city, 'température': result.temperature, 'cache': false});
      return result;
    } catch (error) {
      DiagnosticService.instance.publish(module: DiagnosticModule.weather,
        level: AppDiagnosticLevel.error, state: 'Indisponible', summary: 'Actualisation météo impossible',
        source: weatherApi.runtimeType.toString(), duration: stopwatch.elapsed,
        reason: 'La source météo ou la localisation n’a pas répondu.');
      rethrow;
    }
  }

  @override
  void clearCache() {
    _cached = null;
    _cachedAt = null;
    _inFlight = null;
  }
}
