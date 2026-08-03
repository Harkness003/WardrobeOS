import 'personal_goal.dart';
import 'style_profile.dart';
import 'user_memory.dart';

class PersonalizationSnapshot {
  final List<UserMemory> declarativeMemories;
  final List<UserMemory> behavioralObservations;
  final List<PersonalGoal> goals;
  final StyleProfile? styleProfile;

  const PersonalizationSnapshot({
    this.declarativeMemories = const [],
    this.behavioralObservations = const [],
    this.goals = const [],
    this.styleProfile,
  });

  bool get isEmpty => declarativeMemories.isEmpty &&
      behavioralObservations.isEmpty && goals.isEmpty && styleProfile == null;
}
