import '../../core/recommendation/recommendation_context.dart';
import 'calendar_event.dart';

class CalendarEventContextMapper {
  const CalendarEventContextMapper();

  RecommendationContext map({
    required DateTime date,
    required List<CalendarEvent> events,
    RecommendationWeather? weather,
    Map<String, Object?> metadata = const {},
  }) {
    final inferredEvents = events.map(_classify).toList(growable: false);
    final dominant = inferredEvents.isEmpty ? null :
        (inferredEvents.toList()..sort((a, b) => b.priority.compareTo(a.priority))).first;
    return RecommendationContext(
      occasion: dominant?.context,
      desiredStyle: dominant?.style,
      weather: weather,
      isTravel: events.any((event) => event.type == CalendarEventType.travel),
      metadata: {
        ...metadata,
        'planner': 'agenda',
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'events': events.map((event) => {
          'id': event.id,
          'title': event.title,
          'start': event.startsAt.toIso8601String(),
          'end': event.endsAt.toIso8601String(),
          'durationMinutes': event.endsAt.difference(event.startsAt).inMinutes,
          'context': event.type.label,
          'formality': event.formality.label,
          'allDay': event.isAllDay,
          if (event.location != null) 'location': event.location,
        }).toList(),
        if (dominant != null) ...{
          'eventContext': dominant.context,
          'eventPriority': dominant.priority,
          'eventScope': 'day',
        },
      },
    );
  }

  CalendarEvent applyInferredConstraints(CalendarEvent event) {
    final inferred = _classify(event);
    return event.copyWith(type: inferred.type, formality: inferred.formality);
  }

  _InferredEventContext _classify(CalendarEvent event) {
    final text = '${event.title} ${event.description ?? ''}'.toLowerCase();
    if (event.formality == EventFormality.business || event.type == CalendarEventType.work ||
        _containsAny(text, const ['réunion client', 'reunion client', 'client meeting', 'comité', 'comite', 'présentation', 'presentation'])) {
      return const _InferredEventContext(CalendarEventType.work, EventFormality.business, 'contexte professionnel', 'professionnel', 100);
    }
    if (_containsAny(text, const ['mariage', 'wedding', 'gala', 'cérémonie', 'ceremonie'])) {
      return const _InferredEventContext(CalendarEventType.party, EventFormality.formal, 'événement élégant', 'élégant', 90);
    }
    if (_containsAny(text, const ['sport', 'gym', 'running', 'course', 'yoga', 'entraînement', 'entrainement'])) {
      return const _InferredEventContext(CalendarEventType.sport, EventFormality.sport, 'activité physique', 'confort', 60);
    }
    if (_containsAny(text, const ['restaurant', 'dîner', 'diner', 'déjeuner', 'dejeuner', 'brunch'])) {
      return const _InferredEventContext(CalendarEventType.restaurant, EventFormality.smartCasual, 'sortie', 'casual chic', 70);
    }
    if (event.type == CalendarEventType.party || event.type == CalendarEventType.travel) {
      return _InferredEventContext(event.type, event.formality, event.type.label, null, 90);
    }
    if (event.type == CalendarEventType.restaurant) {
      return _InferredEventContext(event.type, event.formality, 'sortie', 'casual chic', 70);
    }
    if (event.type == CalendarEventType.sport || event.formality == EventFormality.sport) {
      return const _InferredEventContext(CalendarEventType.sport, EventFormality.sport, 'activité physique', 'confort', 60);
    }
    return _InferredEventContext(event.type, event.formality, event.type.label, null, 10);
  }

  static bool _containsAny(String value, List<String> needles) => needles.any(value.contains);
}

class _InferredEventContext {
  final CalendarEventType type;
  final EventFormality formality;
  final String context;
  final String? style;
  final int priority;
  const _InferredEventContext(this.type, this.formality, this.context, this.style, this.priority);
}
