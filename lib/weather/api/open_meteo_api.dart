import 'dart:convert';

import 'package:http/http.dart' as http;

import 'weather_api.dart';

class OpenMeteoApi implements WeatherApi {
  final http.Client _client;
  OpenMeteoApi({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> fetchCurrent({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'current': [
        'temperature_2m',
        'apparent_temperature',
        'relative_humidity_2m',
        'wind_speed_10m',
        'wind_direction_10m',
        'weather_code',
      ].join(','),
      'timezone': 'auto',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw WeatherApiException(response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class WeatherApiException implements Exception {
  final int statusCode;
  const WeatherApiException(this.statusCode);
  @override
  String toString() => 'Erreur météo HTTP $statusCode';
}
