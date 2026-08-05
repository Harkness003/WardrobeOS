enum CalendarEventType {
  work,
  appointment,
  restaurant,
  sport,
  travel,
  party,
  other,
}

enum EventFormality { casual, smartCasual, formal, business, sport }

class CalendarEvent {
  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final CalendarEventType type;
  final String? location;
  final String? description;
  final bool isAllDay;
  final EventFormality formality;
  final Map<String, Object?> metadata;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.type,
    this.location,
    this.description,
    this.isAllDay = false,
    required this.formality,
    this.metadata = const {},
  }) : assert(!endsAt.isBefore(startsAt));

  CalendarEvent copyWith({
    CalendarEventType? type,
    EventFormality? formality,
    String? description,
    bool? isAllDay,
  }) => CalendarEvent(
    id: id,
    title: title,
    startsAt: startsAt,
    endsAt: endsAt,
    type: type ?? this.type,
    location: location,
    description: description ?? this.description,
    isAllDay: isAllDay ?? this.isAllDay,
    formality: formality ?? this.formality,
    metadata: metadata,
  );
}

extension CalendarEventLabels on CalendarEventType {
  String get label => switch (this) {
    CalendarEventType.work => 'travail',
    CalendarEventType.appointment => 'rendez-vous',
    CalendarEventType.restaurant => 'restaurant',
    CalendarEventType.sport => 'sport',
    CalendarEventType.travel => 'voyage',
    CalendarEventType.party => 'soirée',
    CalendarEventType.other => 'autre',
  };
}

extension EventFormalityLabels on EventFormality {
  String get label => switch (this) {
    EventFormality.casual => 'décontractée',
    EventFormality.smartCasual => 'élégante décontractée',
    EventFormality.formal => 'formelle',
    EventFormality.business => 'professionnelle',
    EventFormality.sport => 'sportive',
  };
}
