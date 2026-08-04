import 'package:flutter/foundation.dart';
import '../../models/outfit.dart';
import 'agenda_models.dart';
import 'agenda_service.dart';

class AgendaController extends ChangeNotifier {
  final AgendaService service;
  DateTime weekStart;
  AgendaPreferences preferences;
  List<PlannedOutfit> plans = const [];
  bool loading = false;
  Object? error;
  final Map<DateTime, AgendaDayState> dayStates = {};

  AgendaController({required this.service, AgendaPreferences preferences = const AgendaPreferences(), DateTime? initialDay})
    : preferences = preferences, weekStart = _monday(initialDay ?? DateTime.now());

  Future<void> load() async {
    loading = true; error = null; notifyListeners();
    try {
      plans = await service.loadPeriod(weekStart, weekStart.add(const Duration(days: 7)));
      _syncStates();
      final missing = _days.where((day) => forDay(day) == null).toList();
      if (missing.isNotEmpty) {
        for (final day in missing) dayStates[_key(day)] = AgendaDayState.generating;
        notifyListeners();
        await service.proposePeriod(weekStart, 7, preferences, existing: plans);
        plans = await service.loadPeriod(weekStart, weekStart.add(const Duration(days: 7)));
        _syncStates();
      }
    }
    catch (value) { error = value; }
    finally { loading = false; notifyListeners(); }
  }

  Future<void> changeWeek(int offset) async { weekStart = weekStart.add(Duration(days: offset * 7)); await load(); }
  void setStrategy(PlanningStrategy strategy) { preferences = preferences.copyWith(strategy: strategy); notifyListeners(); }
  PlannedOutfit? forDay(DateTime day) => plans.where((item) => _sameDay(item.date, day)).firstOrNull;
  AgendaDayState stateFor(DateTime day) => dayStates[_key(day)] ?? AgendaDayState.noOutfit;

  Future<void> proposeWeek() async {
    loading = true; error = null; notifyListeners();
    try { await service.proposePeriod(weekStart, 7, preferences, existing: plans); plans = await service.loadPeriod(weekStart, weekStart.add(const Duration(days: 7))); _syncStates(); }
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

  Iterable<DateTime> get _days => Iterable.generate(7, (index) => weekStart.add(Duration(days: index)));
  void _syncStates() {
    for (final day in _days) {
      final plan = forDay(day);
      dayStates[_key(day)] = plan == null ? AgendaDayState.noOutfit
          : plan.origin == PlanningOrigin.automatic ? AgendaDayState.generated : AgendaDayState.planned;
    }
  }
  static DateTime _key(DateTime value) => DateTime(value.year, value.month, value.day);

  static DateTime _monday(DateTime value) { final day = DateTime(value.year, value.month, value.day); return day.subtract(Duration(days: day.weekday - 1)); }
  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
enum AgendaDayState { generating, noOutfit, generated, planned, error }
extension<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
