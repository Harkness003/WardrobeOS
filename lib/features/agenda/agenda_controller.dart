import 'package:flutter/foundation.dart';
import '../../models/outfit.dart';
import '../calendar/google_calendar_service.dart';
import 'agenda_models.dart';
import 'agenda_service.dart';
import '../../core/diagnostics/diagnostic_service.dart';

class AgendaController extends ChangeNotifier {
  final AgendaService service;
  DateTime weekStart;
  AgendaPreferences preferences;
  List<PlannedOutfit> plans = const [];
  bool loading = false;
  bool calendarBusy = false;
  Object? error;
  final Map<DateTime, AgendaDayState> dayStates = {};
  final Map<DateTime, String> dayErrors = {};
  final Map<DateTime, String> dayBusinessReasons = {};
  bool calendarAvailable = true;
  GoogleCalendarService? googleCalendarService;
  bool _calendarInitialized = false;
  bool _preferencesLoaded = false;

  AgendaController({required this.service, this.googleCalendarService, this.preferences = const AgendaPreferences(), DateTime? initialDay})
    : weekStart = _monday(initialDay ?? DateTime.now());

  Future<void> load() async {
    final stopwatch = Stopwatch()..start();
    final diagnostics = DiagnosticService.instance;
    final correlationId = diagnostics.newCorrelationId('agenda-week');
    diagnostics.publish(module: DiagnosticModule.agenda, level: AppDiagnosticLevel.info,
      state: 'Démarré', summary: 'Semaine Agenda demandée', source: 'AgendaController.load',
      correlationId: correlationId, details: {'weekStart': weekStart.toIso8601String().substring(0, 10)});
    loading = true; error = null; notifyListeners();
    try {
      if (!_preferencesLoaded) {
        preferences = await service.loadPreferences();
        _preferencesLoaded = true;
      }
      if (!_calendarInitialized && googleCalendarService != null) {
        await googleCalendarService!.loadConnection();
        _calendarInitialized = true;
      }
      plans = await service.loadPeriod(weekStart, weekStart.add(const Duration(days: 7)));
      _syncStates();
      final missing = _days.where((day) => forDay(day) == null).toList();
      if (missing.isNotEmpty) {
        for (final day in missing) { dayStates[_key(day)] = AgendaDayState.generating; }
        notifyListeners();
        await service.proposePeriod(weekStart, 7, preferences, existing: plans);
        _applyReport();
        plans = await service.loadPeriod(weekStart, weekStart.add(const Duration(days: 7)));
        _syncStates();
      }
      final technicalFailures = service.lastReport.failures
        .where((failure) => failure.result == AgendaDayResult.technicalFailure).length;
      diagnostics.publish(module: DiagnosticModule.agenda,
        level: technicalFailures > 0 ? AppDiagnosticLevel.error
          : calendarAvailable ? AppDiagnosticLevel.success : AppDiagnosticLevel.warning,
        state: 'Rendu', summary: '${plans.length} journée(s) planifiée(s)', source: 'AgendaController.load',
        correlationId: correlationId, duration: stopwatch.elapsed,
        reason: technicalFailures > 0 ? 'generationFailures'
          : calendarAvailable ? null : 'calendarUnavailableFallbackWithoutEvents',
        warning: calendarAvailable ? null : 'Calendrier indisponible : génération de repli sans événements.',
        details: {'calendarAvailable': calendarAvailable, 'plans': plans.length,
          'dayFailures': technicalFailures,
          'dayBusinessUnavailable': service.lastReport.failures
            .where((failure) => failure.result == AgendaDayResult.businessUnavailable).length}, pipeline: [
          const DiagnosticStep('loadStoredWeek'),
          DiagnosticStep('calendar', level: calendarAvailable ? AppDiagnosticLevel.success : AppDiagnosticLevel.warning),
          const DiagnosticStep('wardrobeContext'), const DiagnosticStep('weather'),
          DiagnosticStep('generationByDay', level: dayErrors.isEmpty ? AppDiagnosticLevel.success : AppDiagnosticLevel.warning),
          const DiagnosticStep('render')]);
    }
    catch (value) {
      diagnostics.publish(module: DiagnosticModule.agenda, level: AppDiagnosticLevel.error,
        state: 'Échec', summary: 'Chargement Agenda interrompu', source: 'AgendaController.load',
        correlationId: correlationId, duration: stopwatch.elapsed, reason: 'agendaWeekLoadFailure',
        details: {'technical': value.runtimeType.toString()});
      error = value;
    }
    finally { loading = false; notifyListeners(); }
  }

  Future<void> changeWeek(int offset) async { weekStart = weekStart.add(Duration(days: offset * 7)); await load(); }
  void setStrategy(PlanningStrategy strategy) { preferences = preferences.copyWith(strategy: strategy); _persistPreferences(); notifyListeners(); }
  void setFullReuse(bool value) { preferences = preferences.copyWith(allowCompleteOutfitReuse: value); _persistPreferences(); notifyListeners(); }
  void setMaximumConsecutiveDays(int value) { preferences = preferences.copyWith(maximumConsecutiveDays: value.clamp(1, 7)); _persistPreferences(); notifyListeners(); }
  void toggleWorkDay(int day) {
    final days = {...preferences.workDays};
    days.contains(day) ? days.remove(day) : days.add(day);
    preferences = preferences.copyWith(workDays: days); _persistPreferences(); notifyListeners();
  }
  void setVarietyLevel(AgendaVarietyLevel value) { preferences = preferences.copyWith(varietyLevel: value); _persistPreferences(); notifyListeners(); }
  void _persistPreferences() { service.savePreferences(preferences); }
  PlannedOutfit? forDay(DateTime day) => plans.where((item) => _sameDay(item.date, day)).firstOrNull;
  AgendaDayState stateFor(DateTime day) => dayStates[_key(day)] ?? AgendaDayState.noOutfit;

  Future<void> proposeWeek() async {
    loading = true; error = null; notifyListeners();
    try { await service.proposePeriod(weekStart, 7, preferences, existing: plans); _applyReport(); plans = await service.loadPeriod(weekStart, weekStart.add(const Duration(days: 7))); _syncStates(); }
    catch (value) { error = value; }
    finally { loading = false; notifyListeners(); }
  }

  Future<void> plan(DateTime date, Outfit outfit) async { await service.plan(date: date, outfit: outfit, strategy: preferences.strategy); await load(); }
  Future<void> replace(PlannedOutfit value, Outfit outfit, {OutfitReuseKind kind = OutfitReuseKind.none}) async { await service.replace(value, outfit, reuseKind: kind); await load(); }
  Future<void> another(DateTime date, PlannedOutfit? current) async {
    dayStates[_key(date)] = AgendaDayState.generating; notifyListeners();
    try {
      // The same stable plan id is overwritten only after generation succeeds.
      await service.proposeDay(date, preferences,
        previous: plans.where((item) => item.date.isBefore(date)).toList());
      await load();
    } catch (value) {
      error = value; dayStates[_key(date)] = AgendaDayState.error; notifyListeners();
    }
  }
  Future<void> confirm(PlannedOutfit value) async { await service.confirm(value); await load(); }
  Future<void> markWorn(PlannedOutfit value) async { await service.markWorn(value); await load(); }
  Future<void> remove(PlannedOutfit value) async { await service.remove(value); await load(); }

  Future<void> refreshCalendar() async {
    final google = googleCalendarService;
    if (google == null || calendarBusy) { return; }
    calendarBusy = true; notifyListeners();
    try { await google.refresh(from: weekStart, to: weekStart.add(const Duration(days: 7))); }
    finally { calendarBusy = false; calendarAvailable = google.isCalendarAvailable; notifyListeners(); }
  }

  Future<void> connectCalendar() async {
    final google = googleCalendarService;
    if (google == null || calendarBusy) { return; }
    calendarBusy = true; notifyListeners();
    try { await google.authenticate(); }
    finally { calendarBusy = false; calendarAvailable = google.isCalendarAvailable; notifyListeners(); }
  }

  Future<void> disconnectCalendar() async {
    final google = googleCalendarService;
    if (google == null) { return; }
    if (calendarBusy) { return; }
    calendarBusy = true; notifyListeners();
    try { await google.disconnect(); }
    finally { calendarBusy = false; }
    calendarAvailable = false;
    notifyListeners();
  }

  Iterable<DateTime> get _days => Iterable.generate(7, (index) => weekStart.add(Duration(days: index)));
  void _syncStates() {
    for (final day in _days) {
      final plan = forDay(day);
      dayStates[_key(day)] = dayErrors.containsKey(_key(day)) ? AgendaDayState.error
          : plan == null ? AgendaDayState.noOutfit
          : plan.origin == PlanningOrigin.automatic ? AgendaDayState.generated : AgendaDayState.planned;
    }
  }
  void _applyReport() {
    calendarAvailable = service.lastReport.calendarAvailable;
    dayErrors.clear();
    dayBusinessReasons.clear();
    for (final failure in service.lastReport.failures) {
      if (failure.result == AgendaDayResult.technicalFailure) {
        dayErrors[_key(failure.date)] = failure.reason;
        dayStates[_key(failure.date)] = AgendaDayState.error;
      } else {
        dayBusinessReasons[_key(failure.date)] = failure.reason;
        dayStates[_key(failure.date)] = AgendaDayState.noOutfit;
      }
    }
  }
  static DateTime _key(DateTime value) => DateTime(value.year, value.month, value.day);

  static DateTime _monday(DateTime value) { final day = DateTime(value.year, value.month, value.day); return day.subtract(Duration(days: day.weekday - 1)); }
  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
enum AgendaDayState { generating, noOutfit, generated, planned, error }
extension<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
