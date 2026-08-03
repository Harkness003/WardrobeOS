import 'package:uuid/uuid.dart';

import 'memory_repository.dart';
import 'personal_goal.dart';
import 'personalization_snapshot.dart';
import 'style_profile.dart';
import 'user_memory.dart';

typedef MemoryClock = DateTime Function();
typedef MemoryIdFactory = String Function();

class MemoryService {
  final MemoryRepository repository;
  final MemoryClock _clock;
  final MemoryIdFactory _idFactory;

  MemoryService({
    required this.repository,
    MemoryClock? clock,
    MemoryIdFactory? idFactory,
  }) : _clock = clock ?? DateTime.now,
       _idFactory = idFactory ?? const Uuid().v4;

  Future<PersonalizationSnapshot> loadSnapshot() async {
    final results = await Future.wait<Object?>([
      repository.getMemories(kind: UserMemoryKind.declarative),
      repository.getMemories(kind: UserMemoryKind.behavioral),
      repository.getGoals(),
      repository.getStyleProfile(),
    ]);
    return PersonalizationSnapshot(
      declarativeMemories: results[0] as List<UserMemory>,
      behavioralObservations: results[1] as List<UserMemory>,
      goals: (results[2] as List<PersonalGoal>)
          .where((goal) => goal.status == PersonalGoalStatus.active)
          .toList(growable: false),
      styleProfile: results[3] as StyleProfile?,
    );
  }

  Future<UserMemory> remember({
    required String topic,
    required String statement,
    double confidence = 1,
  }) async {
    final now = _clock();
    final memory = UserMemory(
      id: _idFactory(),
      kind: UserMemoryKind.declarative,
      topic: topic.trim(),
      statement: statement.trim(),
      confidence: confidence.clamp(0, 1).toDouble(),
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveMemory(memory);
    return memory;
  }

  Future<void> updateMemory(UserMemory memory) => repository.saveMemory(
    memory.copyWith(updatedAt: _clock()),
  );

  Future<void> forget(String id) => repository.deleteMemory(id);

  Future<void> saveGoal(PersonalGoal goal) => repository.saveGoal(goal);

  Future<void> deleteGoal(String id) => repository.deleteGoal(id);

  Future<void> saveStyleProfile(StyleProfile profile) =>
      repository.saveStyleProfile(profile);

  Future<void> deleteStyleProfile() => repository.deleteStyleProfile();
}

/// Updates an observation gradually. It never promotes inferred behavior to a
/// declarative fact and contradictory evidence naturally lowers confidence.
class BehavioralObservationService {
  final MemoryRepository repository;
  final MemoryClock _clock;
  final MemoryIdFactory _idFactory;

  BehavioralObservationService({
    required this.repository,
    MemoryClock? clock,
    MemoryIdFactory? idFactory,
  }) : _clock = clock ?? DateTime.now,
       _idFactory = idFactory ?? const Uuid().v4;

  Future<UserMemory> observe({
    required String topic,
    required String statement,
    required bool supportsObservation,
    double evidenceWeight = .15,
  }) async {
    final observations = await repository.getMemories(
      kind: UserMemoryKind.behavioral,
    );
    UserMemory? existing;
    for (final observation in observations) {
      if (observation.topic == topic) {
        existing = observation;
        break;
      }
    }
    final now = _clock();
    final weight = evidenceWeight.clamp(0, 1).toDouble();
    final confidence = existing == null
        ? (supportsObservation ? weight : 0.0)
        : (existing.confidence + (supportsObservation ? weight : -weight))
            .clamp(0, 1)
            .toDouble();
    final updated = UserMemory(
      id: existing?.id ?? _idFactory(),
      kind: UserMemoryKind.behavioral,
      topic: topic,
      statement: statement,
      confidence: confidence,
      evidenceCount: (existing?.evidenceCount ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await repository.saveMemory(updated);
    return updated;
  }
}
