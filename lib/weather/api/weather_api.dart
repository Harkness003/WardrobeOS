abstract interface class WeatherApi {
  Future<Map<String, dynamic>> fetchCurrent({
    required double latitude,
    required double longitude,
  });
}
