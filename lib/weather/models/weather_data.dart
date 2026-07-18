class WeatherData {
  final String city;
  final double latitude;
  final double longitude;
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double windSpeed;
  final int windDirection;
  final int weatherCode;
  final String description;
  final DateTime measuredAt;

  const WeatherData({
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    required this.description,
    required this.measuredAt,
  });

  factory WeatherData.fromOpenMeteoJson(
    Map<String, dynamic> json, {
    required String city,
  }) {
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) throw const FormatException('Champ current manquant');
    double number(String key) => (current[key] as num).toDouble();

    return WeatherData(
      city: city,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      temperature: number('temperature_2m'),
      apparentTemperature: number('apparent_temperature'),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      windSpeed: number('wind_speed_10m'),
      windDirection: (current['wind_direction_10m'] as num).toInt(),
      weatherCode: (current['weather_code'] as num).toInt(),
      description: '',
      measuredAt: DateTime.parse(current['time'] as String),
    );
  }

  WeatherData copyWith({String? description}) => WeatherData(
    city: city,
    latitude: latitude,
    longitude: longitude,
    temperature: temperature,
    apparentTemperature: apparentTemperature,
    humidity: humidity,
    windSpeed: windSpeed,
    windDirection: windDirection,
    weatherCode: weatherCode,
    description: description ?? this.description,
    measuredAt: measuredAt,
  );

  @override
  bool operator ==(Object other) =>
      other is WeatherData &&
      city == other.city &&
      latitude == other.latitude &&
      longitude == other.longitude &&
      temperature == other.temperature &&
      apparentTemperature == other.apparentTemperature &&
      humidity == other.humidity &&
      windSpeed == other.windSpeed &&
      windDirection == other.windDirection &&
      weatherCode == other.weatherCode &&
      description == other.description &&
      measuredAt == other.measuredAt;

  @override
  int get hashCode => Object.hash(
    city,
    latitude,
    longitude,
    temperature,
    apparentTemperature,
    humidity,
    windSpeed,
    windDirection,
    weatherCode,
    description,
    measuredAt,
  );
}
