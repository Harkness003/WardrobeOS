import '../../../data/database_service.dart';
import 'package:sqflite/sqflite.dart';
import 'memory_repository.dart';
import 'personal_goal.dart';
import 'style_profile.dart';
import 'user_memory.dart';

class DatabaseMemoryRepository implements MemoryRepository {
  final DatabaseService databaseService;

  const DatabaseMemoryRepository(this.databaseService);

  @override
  Future<List<UserMemory>> getMemories({UserMemoryKind? kind}) async {
    final db = await databaseService.database;
    final rows = await db.query(
      'user_memories',
      where: kind == null ? 'status = ?' : 'status = ? AND kind = ?',
      whereArgs: [UserMemoryStatus.active.name, if (kind != null) kind.name],
      orderBy: 'updated_at DESC',
    );
    return rows.map(UserMemory.fromMap).toList(growable: false);
  }

  @override
  Future<void> saveMemory(
    UserMemory memory, {
    bool recordRevision = true,
  }) async {
    final db = await databaseService.database;
    await db.transaction((txn) async {
      if (recordRevision) {
        final previous = await txn.query(
          'user_memories',
          where: 'id = ?',
          whereArgs: [memory.id],
          limit: 1,
        );
        if (previous.isNotEmpty) {
          final old = UserMemory.fromMap(previous.first);
          await txn.insert(
            'user_memory_revisions',
            UserMemoryRevision(
              memoryId: old.id,
              statement: old.statement,
              confidence: old.confidence,
              recordedAt: memory.updatedAt,
            ).toMap(),
          );
        }
      }
      await txn.insert(
        'user_memories',
        memory.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> deleteMemory(String id) async {
    final db = await databaseService.database;
    await db.delete('user_memories', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<UserMemoryRevision>> getMemoryHistory(String memoryId) async {
    final db = await databaseService.database;
    final rows = await db.query(
      'user_memory_revisions',
      where: 'memory_id = ?',
      whereArgs: [memoryId],
      orderBy: 'recorded_at DESC, id DESC',
    );
    return rows.map(UserMemoryRevision.fromMap).toList(growable: false);
  }

  @override
  Future<List<PersonalGoal>> getGoals() async {
    final db = await databaseService.database;
    final rows = await db.query('personal_goals', orderBy: 'priority DESC, updated_at DESC');
    return rows.map(PersonalGoal.fromMap).toList(growable: false);
  }

  @override
  Future<void> saveGoal(PersonalGoal goal) async {
    final db = await databaseService.database;
    await db.insert(
      'personal_goals',
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteGoal(String id) async {
    final db = await databaseService.database;
    await db.delete('personal_goals', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<StyleProfile?> getStyleProfile() async {
    final db = await databaseService.database;
    final rows = await db.query('style_profiles', limit: 1);
    return rows.isEmpty ? null : StyleProfile.fromMap(rows.first);
  }

  @override
  Future<void> saveStyleProfile(StyleProfile profile) async {
    final db = await databaseService.database;
    await db.insert(
      'style_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteStyleProfile() async {
    final db = await databaseService.database;
    await db.delete('style_profiles');
  }
}
