import '../../features/calendar/calendar_event.dart';
import '../../models/outfit.dart';
import '../../weather/models/weather_data.dart';

enum PlanningStrategy { minimal, economical, rotation, variety, elegance, comfort, weather, professional, custom }
enum PlannedOutfitStatus { proposed, confirmed, worn, ignored, cancelled }
enum PlanningOrigin { manual, automatic, assistant }
enum OutfitReuseKind { complete, partial, variant, none }
enum AgendaVarietyLevel { low, balanced, high }
enum AgendaRuleType { maximumCategoryDays, maximumFullOutfitDays, refreshCategory, alternateCategory }
enum AgendaRuleEvaluationStatus { satisfied, unsatisfied, conflicting, notApplicable }

/// One evaluation of one enabled custom rule for one generated day.
/// Parameters and garment identifiers are deliberately excluded so diagnostics
/// can aggregate these values without exposing wardrobe data.
class AgendaRuleEvaluation {
  final AgendaRuleType ruleType;
  final AgendaRuleEvaluationStatus status;
  final String reason;
  final DateTime date;
  const AgendaRuleEvaluation({required this.ruleType, required this.status,
    required this.reason, required this.date});
}

class AgendaRuleConflict {
  final Set<AgendaRuleType> ruleTypes;
  final String reason;
  const AgendaRuleConflict({required this.ruleTypes,
    this.reason = 'conflictingAgendaRules'});
}

class AgendaDayFailure {
  final int dayIndex;
  final DateTime date;
  final AgendaDayPhase phase;
  final AgendaDayResult result;
  final String reason;
  final String? technicalType;
  final String? databaseTable;
  final String? databaseConstraint;
  final String? foreignKeyTarget;
  final bool? outfitExists;
  final int? selectedGarments;
  final int? existingGarments;
  final int? missingGarments;
  const AgendaDayFailure({required this.dayIndex, required this.date,
    required this.phase, required this.result, required this.reason,
    this.technicalType, this.databaseTable, this.databaseConstraint,
    this.foreignKeyTarget, this.outfitExists, this.selectedGarments,
    this.existingGarments, this.missingGarments});
}

enum AgendaDayPhase {
  agendaContext,
  outfitGeneration,
  proposalSelection,
  plannedOutfitConstruction,
  persistOutfit,
  persistOutfitItems,
  persistPlannedOutfit,
}

enum AgendaDayResult { businessUnavailable, technicalFailure }

class AgendaGenerationReport {
  final List<PlannedOutfit> generated;
  final List<AgendaDayFailure> failures;
  final bool calendarAvailable;
  final int fullReuse;
  final int partialReuse;
  final int newOutfits;
  final int uniqueGarments;
  final int customRulesActive;
  final int rulesSatisfied;
  final int rulesUnsatisfied;
  final int rulesNotApplicable;
  final bool ruleConflict;
  final int conflictCount;
  final List<AgendaRuleEvaluation> ruleEvaluations;
  const AgendaGenerationReport({this.generated = const [], this.failures = const [], this.calendarAvailable = true,
    this.fullReuse = 0, this.partialReuse = 0, this.newOutfits = 0,
    this.uniqueGarments = 0, this.customRulesActive = 0,
    this.rulesSatisfied = 0, this.rulesUnsatisfied = 0,
    this.rulesNotApplicable = 0, this.ruleConflict = false,
    this.conflictCount = 0, this.ruleEvaluations = const []});
}

extension PlanningStrategyLabel on PlanningStrategy {
  String get label => switch (this) {
    PlanningStrategy.minimal => 'Minimal', PlanningStrategy.economical => 'Économique',
    PlanningStrategy.rotation => 'Rotation', PlanningStrategy.variety => 'Variété',
    PlanningStrategy.elegance => 'Élégance', PlanningStrategy.comfort => 'Confort',
    PlanningStrategy.weather => 'Météo', PlanningStrategy.professional => 'Professionnel',
    PlanningStrategy.custom => 'Personnalisé',
  };
}

class AgendaRule {
  final AgendaRuleType type;
  final Map<String, Object?> parameters;
  final bool enabled;
  const AgendaRule({required this.type, this.parameters = const {}, this.enabled = true});

  Map<String, Object?> toJson() => {'type': type.name, 'parameters': parameters, 'enabled': enabled};
  factory AgendaRule.fromJson(Map<String, Object?> json) => AgendaRule(
    type: AgendaRuleType.values.where((value) => value.name == json['type']).firstOrNull
      ?? AgendaRuleType.maximumCategoryDays,
    parameters: (json['parameters'] as Map?)?.cast<String, Object?>() ?? const {},
    enabled: json['enabled'] as bool? ?? true,
  );
}

class AgendaPreferences {
  final PlanningStrategy strategy;
  final List<AgendaRule> customRules;
  final bool allowCompleteOutfitReuse;
  final int maximumConsecutiveDays;
  final Set<OutfitCategory> reusableCategories;
  final Set<OutfitCategory> dailyRefreshCategories;
  final Set<int> workDays;
  final AgendaVarietyLevel varietyLevel;

  const AgendaPreferences({
    this.strategy = PlanningStrategy.rotation,
    this.customRules = const [],
    this.allowCompleteOutfitReuse = true,
    this.maximumConsecutiveDays = 2,
    this.reusableCategories = const {OutfitCategory.bottom, OutfitCategory.shoes, OutfitCategory.jacket, OutfitCategory.coat},
    this.dailyRefreshCategories = const {OutfitCategory.top},
    this.workDays = const {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday},
    this.varietyLevel = AgendaVarietyLevel.balanced,
  });

  AgendaPreferences copyWith({PlanningStrategy? strategy, List<AgendaRule>? customRules,
    bool? allowCompleteOutfitReuse, int? maximumConsecutiveDays,
    Set<OutfitCategory>? reusableCategories, Set<OutfitCategory>? dailyRefreshCategories,
    Set<int>? workDays, AgendaVarietyLevel? varietyLevel}) => AgendaPreferences(
    strategy: strategy ?? this.strategy, customRules: customRules ?? this.customRules,
    allowCompleteOutfitReuse: allowCompleteOutfitReuse ?? this.allowCompleteOutfitReuse,
    maximumConsecutiveDays: maximumConsecutiveDays ?? this.maximumConsecutiveDays,
    reusableCategories: reusableCategories ?? this.reusableCategories,
    dailyRefreshCategories: dailyRefreshCategories ?? this.dailyRefreshCategories,
    workDays: workDays ?? this.workDays, varietyLevel: varietyLevel ?? this.varietyLevel,
  );

  Map<String, Object?> toJson() => {
    'strategy': strategy.name,
    'customRules': customRules.map((rule) => rule.toJson()).toList(),
    'allowCompleteOutfitReuse': allowCompleteOutfitReuse,
    'maximumConsecutiveDays': maximumConsecutiveDays,
    'reusableCategories': reusableCategories.map((value) => value.name).toList(),
    'dailyRefreshCategories': dailyRefreshCategories.map((value) => value.name).toList(),
    'workDays': workDays.toList(), 'varietyLevel': varietyLevel.name,
  };

  factory AgendaPreferences.fromJson(Map<String, Object?> json) {
    T named<T extends Enum>(List<T> values, Object? raw, T fallback) =>
      values.where((value) => value.name == raw).firstOrNull ?? fallback;
    Set<OutfitCategory> categories(Object? raw, Set<OutfitCategory> fallback) {
      if (raw is! List) return fallback;
      return raw.map((item) => named(OutfitCategory.values, item, OutfitCategory.otherLayer)).toSet();
    }
    const defaults = AgendaPreferences();
    final rawWorkDays = json['workDays'];
    final workDays = rawWorkDays is Iterable
      ? rawWorkDays.whereType<num>().map((value) => value.toInt()).toSet()
      : defaults.workDays;
    return AgendaPreferences(
      strategy: named(PlanningStrategy.values, json['strategy'], defaults.strategy),
      customRules: (json['customRules'] as List? ?? const []).whereType<Map>()
        .map((value) => AgendaRule.fromJson(value.cast<String, Object?>())).toList(),
      allowCompleteOutfitReuse: json['allowCompleteOutfitReuse'] as bool? ?? defaults.allowCompleteOutfitReuse,
      maximumConsecutiveDays: (json['maximumConsecutiveDays'] as num?)?.toInt() ?? defaults.maximumConsecutiveDays,
      reusableCategories: categories(json['reusableCategories'], defaults.reusableCategories),
      dailyRefreshCategories: categories(json['dailyRefreshCategories'], defaults.dailyRefreshCategories),
      workDays: workDays,
      varietyLevel: named(AgendaVarietyLevel.values, json['varietyLevel'], defaults.varietyLevel),
    );
  }
}

class PlannedOutfit {
  final String id;
  final DateTime date;
  final String outfitId;
  final Outfit? outfit;
  final PlanningOrigin origin;
  final PlanningStrategy strategy;
  final PlannedOutfitStatus status;
  final String justification;
  final WeatherData? weather;
  final CalendarEvent? event;
  final OutfitReuseKind reuseKind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? wearRecordedAt;

  const PlannedOutfit({required this.id, required this.date, required this.outfitId,
    this.outfit, this.origin = PlanningOrigin.manual, this.strategy = PlanningStrategy.rotation,
    this.status = PlannedOutfitStatus.proposed, this.justification = '', this.weather,
    this.event, this.reuseKind = OutfitReuseKind.none, required this.createdAt,
    required this.updatedAt, this.wearRecordedAt});

  PlannedOutfit copyWith({Outfit? outfit, String? outfitId, PlannedOutfitStatus? status,
    String? justification, DateTime? updatedAt, DateTime? wearRecordedAt,
    OutfitReuseKind? reuseKind}) => PlannedOutfit(
      id: id, date: date, outfitId: outfitId ?? this.outfitId, outfit: outfit ?? this.outfit,
      origin: origin, strategy: strategy, status: status ?? this.status,
      justification: justification ?? this.justification, weather: weather, event: event,
      reuseKind: reuseKind ?? this.reuseKind, createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt, wearRecordedAt: wearRecordedAt ?? this.wearRecordedAt);

  Map<String, Object?> toMap() => {'id': id, 'planned_date': _day(date), 'outfit_id': outfitId,
    'origin': origin.name, 'strategy': strategy.name, 'status': status.name,
    'justification': justification, 'weather_summary': weather == null ? null : '${weather!.temperature.round()}° · ${weather!.description}',
    'event_id': event?.id, 'event_title': event?.title, 'reuse_kind': reuseKind.name,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
    'wear_recorded_at': wearRecordedAt?.toIso8601String()};

  factory PlannedOutfit.fromMap(Map<String, Object?> map, {Outfit? outfit}) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) =>
      values.where((value) => value.name == raw).firstOrNull ?? fallback;
    final created = DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    return PlannedOutfit(id: map['id'] as String? ?? '',
      date: DateTime.tryParse(map['planned_date'] as String? ?? '') ?? created,
      outfitId: map['outfit_id'] as String? ?? '', outfit: outfit,
      origin: enumValue(PlanningOrigin.values, map['origin'], PlanningOrigin.manual),
      strategy: enumValue(PlanningStrategy.values, map['strategy'], PlanningStrategy.rotation),
      status: enumValue(PlannedOutfitStatus.values, map['status'], PlannedOutfitStatus.proposed),
      justification: map['justification'] as String? ?? '',
      event: map['event_title'] == null ? null : CalendarEvent(id: map['event_id'] as String? ?? '', title: map['event_title'] as String,
        startsAt: DateTime.tryParse(map['planned_date'] as String? ?? '') ?? created,
        endsAt: (DateTime.tryParse(map['planned_date'] as String? ?? '') ?? created).add(const Duration(hours: 1)),
        type: CalendarEventType.other, formality: EventFormality.casual),
      reuseKind: enumValue(OutfitReuseKind.values, map['reuse_kind'], OutfitReuseKind.none),
      createdAt: created, updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? created,
      wearRecordedAt: DateTime.tryParse(map['wear_recorded_at'] as String? ?? ''));
  }

  static String _day(DateTime value) => DateTime(value.year, value.month, value.day).toIso8601String();
}

extension<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
