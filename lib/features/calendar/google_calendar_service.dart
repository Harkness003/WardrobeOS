import 'dart:convert';

import 'package:http/http.dart' as http;

import 'calendar_event.dart';
import 'calendar_event_context_mapper.dart';
import 'calendar_service.dart';
import 'google_calendar_auth_store.dart';
import 'google_calendar_authenticator.dart';
import '../../core/diagnostics/diagnostic_service.dart';

enum GoogleCalendarStatus { disconnected, connecting, connected, syncing, authenticationError, apiError, mappingError }

class GoogleCalendarInfo {
  final String id;
  final String summary;
  final bool primary;
  const GoogleCalendarInfo({required this.id, required this.summary, this.primary = false});
}

class GoogleCalendarSyncState {
  final GoogleCalendarStatus status;
  final String? accountEmail;
  final Set<String> selectedCalendarIds;
  final DateTime? lastRefreshAt;
  final int eventCount;
  final String? userMessage;
  const GoogleCalendarSyncState({
    this.status = GoogleCalendarStatus.disconnected,
    this.accountEmail,
    this.selectedCalendarIds = const {},
    this.lastRefreshAt,
    this.eventCount = 0,
    this.userMessage,
  });
}

class GoogleCalendarService implements CalendarService, CalendarAvailability {
  final GoogleCalendarAuthStore authStore;
  final http.Client _client;
  final DateTime Function() _clock;
  final CalendarEventContextMapper _mapper;
  final GoogleCalendarAuthenticator authenticator;
  GoogleCalendarConnection? _connection;
  List<GoogleCalendarInfo> _calendars = const [];
  Set<String> _selectedCalendarIds = const {};
  List<CalendarEvent> _cache = const [];
  DateTime? _lastRefreshAt;
  GoogleCalendarStatus _status = GoogleCalendarStatus.disconnected;
  String? _message;
  bool _connecting = false;
  bool _syncing = false;

  GoogleCalendarService({
    required this.authStore,
    required this.authenticator,
    http.Client? client,
    DateTime Function() clock = DateTime.now,
    CalendarEventContextMapper mapper = const CalendarEventContextMapper(),
  }) : _client = client ?? http.Client(), _clock = clock, _mapper = mapper;

  GoogleCalendarSyncState get syncState => GoogleCalendarSyncState(
    status: _status,
    accountEmail: _connection?.accountEmail,
    selectedCalendarIds: _selectedCalendarIds,
    lastRefreshAt: _lastRefreshAt,
    eventCount: _cache.length,
    userMessage: _message,
  );

  List<GoogleCalendarInfo> get calendars => List.unmodifiable(_calendars);
  @override bool get isCalendarAvailable =>
      (_status == GoogleCalendarStatus.connected ||
       _status == GoogleCalendarStatus.syncing) &&
      _selectedCalendarIds.isNotEmpty;

  Future<void> loadConnection() async {
    final diagnostics = DiagnosticService.instance;
    final correlationId = diagnostics.newCorrelationId('google-calendar-connection');
    _connection = await authStore.read();
    _selectedCalendarIds = await authStore.readSelectedCalendarIds();
    _status = _connection == null ? GoogleCalendarStatus.disconnected
        : _connection!.calendarReadGranted ? GoogleCalendarStatus.connected : GoogleCalendarStatus.authenticationError;
    diagnostics.publish(module: DiagnosticModule.googleCalendar,
      level: _connection == null ? AppDiagnosticLevel.warning : AppDiagnosticLevel.info,
      state: _status.name, summary: 'État de connexion calendrier chargé',
      source: 'GoogleCalendarService.loadConnection', correlationId: correlationId,
      reason: _connection == null ? 'notConnectedOptionalContext' : null,
      details: {'connectionButtonAvailable': true,
        'selectedCalendars': _selectedCalendarIds.length});
  }

  Future<bool> authenticate() async {
    if (_connecting) return false;
    _connecting = true;
    _status = GoogleCalendarStatus.connecting;
    final diagnostics = DiagnosticService.instance;
    final correlationId = diagnostics.newCorrelationId('google-calendar-auth');
    diagnostics.publish(module: DiagnosticModule.googleCalendar, level: AppDiagnosticLevel.info,
      state: 'Connexion', summary: 'Authentification Google Calendar démarrée',
      source: 'GoogleCalendarService.authenticate', correlationId: correlationId);
    try {
      final connection = await authenticator.authenticate();
      if (connection == null) {
        _status = GoogleCalendarStatus.disconnected;
        _message = 'Connexion annulée. Agenda reste disponible sans Google Calendar.';
        return false;
      }
      await connect(connection);
      diagnostics.publish(module: DiagnosticModule.googleCalendar, level: AppDiagnosticLevel.success,
        state: 'Connecté', summary: 'Authentification Google Calendar disponible',
        source: 'GoogleCalendarService.authenticate', correlationId: correlationId);
      await refresh();
      return _status == GoogleCalendarStatus.connected;
    } catch (error) {
      _status = GoogleCalendarStatus.authenticationError;
      _message = 'L’accès à Google Calendar a expiré. Reconnecte ton compte pour récupérer tes événements.';
      diagnostics.publish(module: DiagnosticModule.googleCalendar, level: AppDiagnosticLevel.error,
        state: 'Échec', summary: 'Authentification Google Calendar impossible',
        source: 'GoogleCalendarService.authenticate', correlationId: correlationId,
        reason: 'authenticationFailed', details: {'technical': error.runtimeType.toString()});
      return false;
    } finally { _connecting = false; }
  }

  Future<void> connect(GoogleCalendarConnection connection) async {
    await authStore.save(connection); _connection = connection;
    _status = connection.calendarReadGranted ? GoogleCalendarStatus.connected : GoogleCalendarStatus.authenticationError;
  }

  Future<void> disconnect() async {
    await authenticator.disconnect();
    await authStore.clear(); _connection = null; _cache = const []; _calendars = const []; _selectedCalendarIds = const {}; _lastRefreshAt = null;
    _status = GoogleCalendarStatus.disconnected;
  }

  Future<void> selectCalendars(Set<String> ids) async {
    _selectedCalendarIds = Set.unmodifiable(ids);
    await authStore.saveSelectedCalendarIds(_selectedCalendarIds);
  }

  Future<void> refresh({DateTime? from, DateTime? to}) async {
    if (_syncing) return;
    _syncing = true;
    final stopwatch = Stopwatch()..start();
    final diagnostics = DiagnosticService.instance;
    final correlationId = diagnostics.newCorrelationId('google-calendar-refresh');
    diagnostics.publish(module: DiagnosticModule.googleCalendar, level: AppDiagnosticLevel.info,
      state: 'Démarré', summary: 'Actualisation calendrier demandée',
      source: 'GoogleCalendarService.refresh', correlationId: correlationId);
    final connection = _connection ?? await authStore.read();
    if (connection == null) { diagnostics.publish(module: DiagnosticModule.googleCalendar,
      level: AppDiagnosticLevel.warning, state: 'Non connecté', summary: 'Actualisation ignorée',
      source: 'GoogleCalendarService.refresh', correlationId: correlationId,
      reason: 'notConnectedOptionalContext', duration: stopwatch.elapsed); _status = GoogleCalendarStatus.disconnected; _message = 'Connecte Google Calendar pour adapter les propositions à tes événements.'; _syncing = false; return; }
    if (!connection.calendarReadGranted) { diagnostics.publish(module: DiagnosticModule.googleCalendar,
      level: AppDiagnosticLevel.error, state: 'Permission refusée', summary: 'Actualisation interrompue',
      source: 'GoogleCalendarService.refresh', correlationId: correlationId,
      reason: 'authenticationRevoked', duration: stopwatch.elapsed); _status = GoogleCalendarStatus.authenticationError; _message = 'L’accès à Google Calendar a expiré. Reconnecte ton compte pour récupérer tes événements.'; _syncing = false; return; }
    _connection = connection;
    _status = GoogleCalendarStatus.syncing;
    try {
      await _loadCalendars(connection);
      if (_selectedCalendarIds.isEmpty) { _status = GoogleCalendarStatus.connected; _message = 'Aucun calendrier actif sélectionné.'; return; }
      _cache = await _loadEvents(connection, from ?? _clock().subtract(const Duration(days: 1)), to ?? _clock().add(const Duration(days: 30)));
      _lastRefreshAt = _clock(); _status = GoogleCalendarStatus.connected; _message = null;
      diagnostics.publish(module: DiagnosticModule.googleCalendar, level: AppDiagnosticLevel.success,
        state: 'Actualisé', summary: '${_cache.length} événement(s) reçu(s)',
        source: 'GoogleCalendarService.refresh', correlationId: correlationId,
        duration: stopwatch.elapsed, details: {'selectedCalendars': _selectedCalendarIds.length,
          'events': _cache.length});
    } catch (error) {
      diagnostics.publish(module: DiagnosticModule.googleCalendar, level: AppDiagnosticLevel.error,
        state: 'Échec', summary: 'Réponse calendrier inexploitable',
        source: 'GoogleCalendarService.refresh', correlationId: correlationId,
        duration: stopwatch.elapsed, reason: _status == GoogleCalendarStatus.authenticationError
          ? 'authenticationRevoked' : error is FormatException ? 'mappingDecodeFailure' : 'apiUnavailable',
        details: {'technical': error.runtimeType.toString()});
      if (_status == GoogleCalendarStatus.authenticationError) {
        _message = 'L’accès à Google Calendar a expiré. Reconnecte ton compte pour récupérer tes événements.';
      } else if (error is FormatException) {
        _status = GoogleCalendarStatus.mappingError;
        _message = 'Certains événements Google Calendar sont illisibles. Agenda reste disponible sans eux.';
      } else {
        _status = GoogleCalendarStatus.apiError;
        _message = 'Google Calendar est temporairement inaccessible. Agenda reste disponible sans tes événements.';
      }
    } finally { _syncing = false; }
  }

  Future<void> _loadCalendars(GoogleCalendarConnection connection) async {
    final uri = Uri.https('www.googleapis.com', '/calendar/v3/users/me/calendarList');
    final response = await _client.get(uri, headers: _headers(connection));
    if (response.statusCode == 401 || response.statusCode == 403) { _status = GoogleCalendarStatus.authenticationError; throw StateError('permission'); }
    if (response.statusCode >= 400) throw StateError('calendar');
    final items = (jsonDecode(response.body) as Map<String, Object?>)['items'] as List? ?? const [];
    _calendars = items.map((item) { final map = (item as Map).cast<String, Object?>(); return GoogleCalendarInfo(id: map['id'] as String? ?? '', summary: map['summary'] as String? ?? 'Calendrier', primary: map['primary'] as bool? ?? false); }).toList();
    if (_selectedCalendarIds.isEmpty) {
      _selectedCalendarIds = _calendars.where((c) => c.primary).map((c) => c.id).toSet();
      await authStore.saveSelectedCalendarIds(_selectedCalendarIds);
    }
  }

  Future<List<CalendarEvent>> _loadEvents(GoogleCalendarConnection connection, DateTime from, DateTime to) async {
    final events = <CalendarEvent>[];
    for (final calendarId in _selectedCalendarIds) {
      final uri = Uri.https('www.googleapis.com', '/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events', {
        'singleEvents': 'true', 'orderBy': 'startTime', 'timeMin': from.toUtc().toIso8601String(), 'timeMax': to.toUtc().toIso8601String(),
      });
      final response = await _client.get(uri, headers: _headers(connection));
      if (response.statusCode >= 400) throw StateError('events');
      final items = (jsonDecode(response.body) as Map<String, Object?>)['items'] as List? ?? const [];
      events.addAll(items.map((item) => _fromGoogle((item as Map).cast<String, Object?>(), calendarId)));
    }
    events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return List.unmodifiable(events);
  }

  CalendarEvent _fromGoogle(Map<String, Object?> json, String calendarId) {
    DateTime parse(Map<String, Object?> value) => DateTime.parse((value['dateTime'] ?? value['date']) as String);
    final startMap = (json['start'] as Map).cast<String, Object?>();
    final endMap = (json['end'] as Map).cast<String, Object?>();
    final allDay = startMap['dateTime'] == null;
    return _mapper.applyInferredConstraints(CalendarEvent(
      id: '${calendarId}:${json['id']}', title: json['summary'] as String? ?? 'Sans titre',
      startsAt: parse(startMap), endsAt: parse(endMap), isAllDay: allDay,
      location: json['location'] as String?, description: json['description'] as String?,
      type: CalendarEventType.other, formality: EventFormality.casual,
      metadata: {'calendarId': calendarId},
    ));
  }

  Map<String, String> _headers(GoogleCalendarConnection connection) => {'Authorization': 'Bearer ${connection.accessToken}', 'Accept': 'application/json'};

  @override Future<List<CalendarEvent>> getTodayEvents({DateTime? day}) async { final d = day ?? _clock(); final start = DateTime(d.year, d.month, d.day); final end = start.add(const Duration(days: 1)); return _cache.where((e) => e.startsAt.isBefore(end) && e.endsAt.isAfter(start)).toList(); }
  @override Future<List<CalendarEvent>> getUpcomingEvents({DateTime? from}) async { final start = from ?? _clock(); return _cache.where((e) => !e.endsAt.isBefore(start)).toList(); }
  @override Future<CalendarEvent?> getNextImportantEvent({DateTime? from}) async { final events = await getUpcomingEvents(from: from); return events.isEmpty ? null : events.first; }

  void dispose() => _client.close();
}
