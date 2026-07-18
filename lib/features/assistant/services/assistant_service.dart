import '../context/assistant_context.dart';
import '../context/assistant_context_builder.dart';

class AssistantService {
  final AssistantContextBuilder _contextBuilder;

  const AssistantService({required AssistantContextBuilder contextBuilder})
    : _contextBuilder = contextBuilder;

  Future<AssistantContext> buildContext() => _contextBuilder.build();

  Future<String> generateMessage() async {
    final context = await buildContext();
    final temperature = _formatTemperature(context.weather.temperature);
    return 'Bonjour 👋\n\n'
        'Aujourd’hui nous sommes ${context.date.day}.\n\n'
        'Il fait $temperature°C à ${context.weather.city}.\n\n'
        'Votre dressing contient ${context.statistics.garmentCount} vêtements.\n\n'
        'Vous avez enregistré ${context.statistics.outfitCount} tenues.';
  }

  String _formatTemperature(double value) =>
      value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
}
