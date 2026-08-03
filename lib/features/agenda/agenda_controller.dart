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

  AgendaController({required this.service, AgendaPreferences preferences = const AgendaPreferences(), DateTime? initialDay})
    : preferences = preferences, weekStart = _monday(initialDay ?? DateTime.now());

  Future<void> load() async {
    loading = true; error = null; notifyListeners();
    try { plans = await service.loadPeriod(weekStart, weekStart.add(const Duration(days: 7))); }
    catch (value) { error = value; }
    finally { loading = false; notifyListeners(); }
  }

  Future<void> changeWeek(int offset) async { weekStart = weekStart.add(Duration(days: offset * 7)); await load(); }
  void setStrategy(PlanningStrategy strategy) { preferences = preferences.copyWith(strategy: strategy); notifyListeners(); }
  PlannedOutfit? forDay(DateTime day) => plans.where((item) => _sameDay(item.date, day)).firstOrNull;

  Future<void> proposeWeek() async {
    loading = true; error = null; notifyListeners();
    try { await service.proposePeriod(weekStart, 7, preferences); plans = await service.loadPeriod(weekStart, weekStart.add(const Duration(days: 7))); }
    catch (value) { error = value; }
    finally { loading = false; notifyListeners(); }
  }

  Future<void> plan(DateTime date, Outfit outfit) async { await service.plan(date: date, outfit: outfit, strategy: preferences.strategy); await load(); }
  Future<void> replace(PlannedOutfit value, Outfit outfit, {OutfitReuseKind kind = OutfitReuseKind.none}) async { await service.replace(value, outfit, reuseKind: kind); await load(); }
  Future<void> another(DateTime date, PlannedOutfit? current) async {
    if (current != null) await service.remove(current);
    await service.proposeDay(date, preferences, previous: plans.where((item) => item.date.isBefore(date)).toList()); await load();
  }
  Future<void> confirm(PlannedOutfit value) async { await service.confirm(value); await load(); }
  Future<void> markWorn(PlannedOutfit value) async { await service.markWorn(value); await load(); }
  Future<void> remove(PlannedOutfit value) async { await service.remove(value); await load(); }

  static DateTime _monday(DateTime value) { final day = DateTime(value.year, value.month, value.day); return day.subtract(Duration(days: day.weekday - 1)); }
  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
extension<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
