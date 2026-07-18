import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/calendar/calendar_context_builder.dart';
import 'package:wardrobeos/features/calendar/calendar_event.dart';
import 'package:wardrobeos/features/calendar/fake_calendar_service.dart';

void main() {
  final now = DateTime(2026, 7, 18, 12);
  final event = CalendarEvent(
    id: 'dinner',
    title: 'Restaurant',
    startsAt: DateTime(2026, 7, 18, 20),
    endsAt: DateTime(2026, 7, 18, 22),
    type: CalendarEventType.restaurant,
    location: 'Lyon',
    formality: EventFormality.smartCasual,
  );

  test('crée un événement extensible', () {
    expect(event.id, 'dinner');
    expect(event.type, CalendarEventType.restaurant);
    expect(event.formality.label, 'élégante décontractée');
  });

  test('récupère le prochain événement important', () async {
    final service = FakeCalendarService(events: [event], clock: () => now);
    expect(await service.getNextImportantEvent(), same(event));
  });

  test('construit le contexte calendrier', () async {
    final context = await CalendarContextBuilder(
      service: FakeCalendarService(events: [event]),
      clock: () => now,
    ).build();
    expect(context!.summary, contains('Restaurant à Lyon à 20h'));
    expect(context.summary, contains('élégante décontractée'));
  });

  test("retourne null en l'absence d'événement", () async {
    final context = await CalendarContextBuilder(
      service: FakeCalendarService(),
      clock: () => now,
    ).build();
    expect(context, isNull);
  });
}
