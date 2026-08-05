import 'dart:convert';

import '../assistant/settings/api_key_storage.dart';

class GoogleCalendarConnection {
  final String accountEmail;
  final String accessToken;
  final DateTime connectedAt;
  final bool calendarReadGranted;

  const GoogleCalendarConnection({
    required this.accountEmail,
    required this.accessToken,
    required this.connectedAt,
    this.calendarReadGranted = true,
  });

  Map<String, Object?> toJson() => {
    'accountEmail': accountEmail,
    'accessToken': accessToken,
    'connectedAt': connectedAt.toIso8601String(),
    'calendarReadGranted': calendarReadGranted,
  };

  factory GoogleCalendarConnection.fromJson(Map<String, Object?> json) => GoogleCalendarConnection(
    accountEmail: json['accountEmail'] as String? ?? '',
    accessToken: json['accessToken'] as String? ?? '',
    connectedAt: DateTime.tryParse(json['connectedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    calendarReadGranted: json['calendarReadGranted'] as bool? ?? false,
  );
}

class GoogleCalendarAuthStore {
  static const _key = 'google_calendar_connection';
  static const _selectedCalendarsKey = 'google_calendar_selected_calendars';
  final SecureKeyValueStorage _storage;

  const GoogleCalendarAuthStore({SecureKeyValueStorage? storage})
    : _storage = storage ?? const FlutterSecureKeyValueStorage();

  Future<GoogleCalendarConnection?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) return null;
    return GoogleCalendarConnection.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  Future<void> save(GoogleCalendarConnection connection) =>
      _storage.write(key: _key, value: jsonEncode(connection.toJson()));

  Future<void> saveSelectedCalendarIds(Set<String> ids) =>
      _storage.write(key: _selectedCalendarsKey, value: jsonEncode(ids.toList()..sort()));

  Future<Set<String>> readSelectedCalendarIds() async {
    final raw = await _storage.read(key: _selectedCalendarsKey);
    if (raw == null || raw.trim().isEmpty) return const {};
    return (jsonDecode(raw) as List).whereType<String>().toSet();
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _selectedCalendarsKey);
  }
}
