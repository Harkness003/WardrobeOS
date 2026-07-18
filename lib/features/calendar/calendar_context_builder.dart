import 'calendar_event.dart';
import 'calendar_service.dart';

class CalendarContext {
  final CalendarEvent event;
  final String summary;

  const CalendarContext({required this.event, required this.summary});

  Map<String, Object?> toMap() => {
    'event': event.title,
    'type': event.type.label,
    'date': event.startsAt.toIso8601String(),
    if (event.location != null) 'location': event.location,
    'formality': event.formality.label,
    'summary': summary,
  };
}

class CalendarContextBuilder {
  final CalendarService _service;
  final DateTime Function() _clock;

  const CalendarContextBuilder({
    required CalendarService service,
    DateTime Function() clock = DateTime.now,
  }) : _service = service,
       _clock = clock;

  Future<CalendarContext?> build() async {
    final event = await _service.getNextImportantEvent(from: _clock());
    if (event == null) return null;
    final time = '${event.startsAt.hour.toString().padLeft(2, '0')}h'
        '${event.startsAt.minute == 0 ? '' : event.startsAt.minute.toString().padLeft(2, '0')}';
    final place = event.location == null ? '' : ' à ${event.location}';
    return CalendarContext(
      event: event,
      summary: '${event.title}$place à $time.\nFormalité : ${event.formality.label}.',
    );
  }
}
