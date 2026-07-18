import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/weather/models/weather_data.dart';

void main() {
  const json = <String, dynamic>{
    'latitude': 48.86,
    'longitude': 2.35,
    'current': <String, dynamic>{
      'temperature_2m': 18.4,
      'apparent_temperature': 17.2,
      'relative_humidity_2m': 72,
      'wind_speed_10m': 12.5,
      'wind_direction_10m': 245,
      'weather_code': 2,
      'time': '2026-07-18T10:15',
    },
  };

  test('parse tous les champs courants Open-Meteo', () {
    final weather = WeatherData.fromOpenMeteoJson(json, city: 'Paris');
    expect(weather.city, 'Paris');
    expect(weather.latitude, 48.86);
    expect(weather.longitude, 2.35);
    expect(weather.temperature, 18.4);
    expect(weather.apparentTemperature, 17.2);
    expect(weather.humidity, 72);
    expect(weather.windSpeed, 12.5);
    expect(weather.windDirection, 245);
    expect(weather.weatherCode, 2);
    expect(weather.measuredAt, DateTime(2026, 7, 18, 10, 15));
  });

  test('WeatherData fournit une égalité métier stable et copyWith', () {
    final first = WeatherData.fromOpenMeteoJson(
      json,
      city: 'Paris',
    ).copyWith(description: 'Nuageux');
    final second = WeatherData.fromOpenMeteoJson(
      json,
      city: 'Paris',
    ).copyWith(description: 'Nuageux');
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first.copyWith(description: 'Clair').description, 'Clair');
  });

  test('rejette une réponse sans météo courante', () {
    expect(
      () => WeatherData.fromOpenMeteoJson(const {
        'latitude': 0,
        'longitude': 0,
      }, city: 'Test'),
      throwsFormatException,
    );
  });
}
