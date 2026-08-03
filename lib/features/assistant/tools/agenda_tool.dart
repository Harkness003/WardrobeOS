import '../../agenda/agenda_service.dart';
import 'assistant_tool.dart';

class AgendaTool implements AssistantTool {
  final AgendaService service;
  final DateTime Function() clock;
  AgendaTool({required this.service, this.clock = DateTime.now});

  @override String get id => 'outfit_agenda';
  @override String get description => 'Tenues planifiées pour les prochains jours';

  @override Future<AssistantToolData> getData() async {
    final from = clock();
    final plans = await service.loadPeriod(from, from.add(const Duration(days: 8)));
    return {'plans': [for (final plan in plans) {
      'date': plan.date.toIso8601String(), 'outfitId': plan.outfitId,
      'outfit': plan.outfit?.name, 'status': plan.status.name,
      'strategy': plan.strategy.name, 'justification': plan.justification,
    }]};
  }
}
