import 'personal_goal.dart';
import 'style_profile.dart';
import 'user_memory.dart';

abstract interface class MemoryRepository {
  Future<List<UserMemory>> getMemories({UserMemoryKind? kind});
  Future<void> saveMemory(UserMemory memory, {bool recordRevision = true});
  Future<void> deleteMemory(String id);
  Future<List<UserMemoryRevision>> getMemoryHistory(String memoryId);
  Future<List<PersonalGoal>> getGoals();
  Future<void> saveGoal(PersonalGoal goal);
  Future<void> deleteGoal(String id);
  Future<StyleProfile?> getStyleProfile();
  Future<void> saveStyleProfile(StyleProfile profile);
  Future<void> deleteStyleProfile();
}
