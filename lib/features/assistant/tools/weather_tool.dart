import '../../../weather/services/weather_service.dart';
import 'assistant_tool.dart';

class WeatherTool implements AssistantTool {
  final WeatherService _weatherService;

  const WeatherTool({required WeatherService weatherService})
    : _weatherService = weatherService;

  @override
  String get id => 'weather';

  @override
  String get description => 'Conditions météo à la position actuelle.';

  @override
  Future<AssistantToolData> getData() async {
    final weather = await _weatherService.getCurrentWeather();
    return {
      'city': weather.city,
      'temperature': weather.temperature,
      'condition': weather.description,
    };
  }
}
