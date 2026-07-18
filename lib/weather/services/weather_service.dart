import '../models/weather_data.dart';

abstract interface class WeatherService {
  Future<WeatherData> getCurrentWeather({bool forceRefresh = false});
  void clearCache();
}
