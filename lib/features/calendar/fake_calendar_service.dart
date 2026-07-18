import 'calendar_event.dart';
import 'calendar_service.dart';

typedef CalendarClock = DateTime Function();

class FakeCalendarService implements CalendarService {
  final List<CalendarEvent> _events;
  final CalendarClock _clock;

  FakeCalendarService({
    List<CalendarEvent> events = const [],
    CalendarClock clock = DateTime.now,
  }) : _events = List.unmodifiable(events),
       _clock = clock;

  @override
  Future<List<CalendarEvent>> getUpcomingEvents({DateTime? from}) async {
    final start = from ?? _clock();
    final events =
        _events.where((event) => !event.endsAt.isBefore(start)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return List.unmodifiable(events);
  }

  @override
  Future<List<CalendarEvent>> getTodayEvents({DateTime? day}) async {
    final date = day ?? _clock();
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return List.unmodifiable(
      _events.where(
        (event) =>
            event.startsAt.isBefore(end) && event.endsAt.isAfter(start),
      ),
    );
  }

  @override
  Future<CalendarEvent?> getNextImportantEvent({DateTime? from}) async {
    final upcoming = await getUpcomingEvents(from: from);
    for (final event in upcoming) {
      if (event.type != CalendarEventType.other) return event;
    }
    return upcoming.isEmpty ? null : upcoming.first;
  }
}
