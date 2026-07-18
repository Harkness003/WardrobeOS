import 'calendar_event.dart';

abstract interface class CalendarService {
  Future<List<CalendarEvent>> getUpcomingEvents({DateTime? from});

  Future<List<CalendarEvent>> getTodayEvents({DateTime? day});

  Future<CalendarEvent?> getNextImportantEvent({DateTime? from});
}
