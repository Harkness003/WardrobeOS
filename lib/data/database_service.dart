import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/garment.dart';
import '../models/outfit.dart';
import '../models/outfit_item.dart';
import '../models/wear_history.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'wardrobeos.db'),
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE garments(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            brand TEXT,
            color TEXT,
            material TEXT,
            season TEXT,
            style TEXT,
            occasion TEXT,
            condition TEXT,
            purchase_price REAL,
            purchase_date TEXT,
            wear_count INTEGER NOT NULL DEFAULT 0,
            last_worn TEXT,
            size TEXT,
            fit TEXT,
            composition TEXT,
            notes TEXT,
            image_path TEXT,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await _createWearHistoryTable(db);
        await _createOutfitTables(db);
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addColumn(db, 'garments', 'style', 'TEXT');
          await _addColumn(db, 'garments', 'occasion', 'TEXT');
          await _addColumn(db, 'garments', 'condition', 'TEXT');
          await _addColumn(db, 'garments', 'purchase_price', 'REAL');
          await _addColumn(db, 'garments', 'purchase_date', 'TEXT');
          await _addColumn(
            db,
            'garments',
            'wear_count',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _addColumn(db, 'garments', 'last_worn', 'TEXT');
          await _addColumn(db, 'garments', 'size', 'TEXT');
          await _addColumn(db, 'garments', 'fit', 'TEXT');
          await _addColumn(db, 'garments', 'composition', 'TEXT');
        }
        if (oldVersion < 3) {
          await _createWearHistoryTable(db);
        }
        if (oldVersion < 4) await _createOutfitTables(db);
        await _createIndexes(db);
      },
    );
  }

  Future<void> _createWearHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wear_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        garment_id TEXT NOT NULL,
        worn_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (garment_id) REFERENCES garments(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createOutfitTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outfits(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        season TEXT,
        favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        times_worn INTEGER NOT NULL DEFAULT 0,
        last_worn TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outfit_items(
        outfit_id TEXT NOT NULL,
        garment_id TEXT NOT NULL,
        PRIMARY KEY (outfit_id, garment_id),
        FOREIGN KEY (outfit_id) REFERENCES outfits(id) ON DELETE CASCADE,
        FOREIGN KEY (garment_id) REFERENCES garments(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _addColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_garments_category ON garments(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_garments_name ON garments(name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_garments_last_worn ON garments(last_worn)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wear_history_garment ON wear_history(garment_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wear_history_worn_at ON wear_history(worn_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outfit_items_garment ON outfit_items(garment_id)',
    );
  }

  Future<List<Garment>> getGarments({
    String search = '',
    String category = 'Tout',
    bool favoritesOnly = false,
    String season = '',
    String brand = '',
    String color = '',
    String material = '',
    String style = '',
    String occasion = '',
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (search.trim().isNotEmpty) {
      where.add(
        '(name LIKE ? OR brand LIKE ? OR color LIKE ? OR style LIKE ? OR occasion LIKE ?)',
      );
      final q = '%${search.trim()}%';
      args.addAll([q, q, q, q, q]);
    }
    if (category != 'Tout') {
      where.add('category = ?');
      args.add(category);
    }
    if (favoritesOnly) where.add('is_favorite = 1');
    if (season.trim().isNotEmpty) {
      where.add('season = ?');
      args.add(season.trim());
    }
    for (final filter in <(String, String)>[
      ('brand', brand),
      ('color', color),
      ('material', material),
      ('style', style),
      ('occasion', occasion),
    ]) {
      if (filter.$2.trim().isNotEmpty) {
        where.add('${filter.$1} LIKE ?');
        args.add('%${filter.$2.trim()}%');
      }
    }
    final rows = await db.query(
      'garments',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'is_favorite DESC, updated_at DESC',
    );
    return rows.map(Garment.fromMap).toList();
  }

  Future<void> insertGarment(Garment garment) async {
    final db = await database;
    await db.insert(
      'garments',
      garment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateGarment(Garment garment) async {
    final db = await database;
    await db.update(
      'garments',
      garment.toMap(),
      where: 'id = ?',
      whereArgs: [garment.id],
    );
  }

  Future<List<WearHistory>> getWearHistory(
    String garmentId, {
    int? limit,
  }) async {
    final db = await database;
    final rows = await db.query(
      'wear_history',
      where: 'garment_id = ?',
      whereArgs: [garmentId],
      orderBy: 'worn_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(WearHistory.fromMap).toList();
  }

  Future<WearHistory?> getFirstWear(String garmentId) async {
    final db = await database;
    final rows = await db.query(
      'wear_history',
      where: 'garment_id = ?',
      whereArgs: [garmentId],
      orderBy: 'worn_at ASC, id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WearHistory.fromMap(rows.first);
  }

  Future<WearHistory> recordWear(String garmentId, {DateTime? wornAt}) async {
    final db = await database;
    final date = wornAt ?? DateTime.now();
    final createdAt = DateTime.now();
    if (date.isAfter(createdAt)) {
      throw ArgumentError.value(wornAt, 'wornAt', 'Cannot record future wear.');
    }

    return db.transaction((txn) async {
      final id = await txn.insert('wear_history', {
        'garment_id': garmentId,
        'worn_at': date.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      });

      await _syncGarmentWearData(txn, garmentId);

      return WearHistory(
        id: id,
        garmentId: garmentId,
        wornAt: date,
        createdAt: createdAt,
      );
    });
  }

  Future<bool> removeLastWear(String garmentId) async {
    final db = await database;

    return db.transaction((txn) async {
      final rows = await txn.query(
        'wear_history',
        columns: ['id'],
        where: 'garment_id = ?',
        whereArgs: [garmentId],
        orderBy: 'worn_at DESC, id DESC',
        limit: 1,
      );

      if (rows.isEmpty) return false;

      final id = rows.first['id'] as int;
      return _deleteWearInTransaction(txn, garmentId: garmentId, wearId: id);
    });
  }

  Future<bool> deleteWear(String garmentId, int wearId) async {
    final db = await database;

    return db.transaction((txn) {
      return _deleteWearInTransaction(
        txn,
        garmentId: garmentId,
        wearId: wearId,
      );
    });
  }

  Future<bool> _deleteWearInTransaction(
    Transaction txn, {
    required String garmentId,
    required int wearId,
  }) async {
    final deleted = await txn.delete(
      'wear_history',
      where: 'id = ? AND garment_id = ?',
      whereArgs: [wearId, garmentId],
    );
    if (deleted == 0) return false;

    await _syncGarmentWearData(txn, garmentId);
    return true;
  }

  Future<void> _syncGarmentWearData(
    DatabaseExecutor db,
    String garmentId,
  ) async {
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM wear_history WHERE garment_id = ?',
      [garmentId],
    );
    final lastRows = await db.query(
      'wear_history',
      columns: ['worn_at'],
      where: 'garment_id = ?',
      whereArgs: [garmentId],
      orderBy: 'worn_at DESC, id DESC',
      limit: 1,
    );

    final count = (countRows.first['total'] as int?) ?? 0;
    final lastWorn =
        lastRows.isEmpty ? null : lastRows.first['worn_at'] as String;

    await db.update(
      'garments',
      {
        'wear_count': count,
        'last_worn': lastWorn,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [garmentId],
    );
  }

  Future<void> deleteGarment(String id) async {
    final db = await database;
    await db.delete('garments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> createOutfit(Outfit outfit) async {
    final db = await database;
    await db.insert('outfits', outfit.toMap());
  }

  Future<void> updateOutfit(Outfit outfit) async {
    final db = await database;
    await db.update(
      'outfits',
      outfit.toMap(),
      where: 'id = ?',
      whereArgs: [outfit.id],
    );
  }

  Future<void> deleteOutfit(String id) async {
    final db = await database;
    await db.delete('outfits', where: 'id = ?', whereArgs: [id]);
  }

  Future<Outfit?> getOutfitById(String id) async {
    final db = await database;
    final rows = await db.query(
      'outfits',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Outfit.fromMap(rows.first);
  }

  Future<List<Outfit>> getAllOutfits() async {
    final db = await database;
    final rows = await db.query(
      'outfits',
      orderBy: 'favorite DESC, updated_at DESC',
    );
    return rows.map(Outfit.fromMap).toList();
  }

  /// Records one wear for an outfit and every garment that still belongs to it.
  ///
  /// Garment history, denormalized garment counters, and outfit counters are
  /// committed atomically. Returns `false` when the outfit has no existing
  /// garments (including when all referenced garments were deleted).
  Future<bool> recordOutfitWear(String outfitId, {DateTime? wornAt}) async {
    final db = await database;
    final date = wornAt ?? DateTime.now();
    final createdAt = DateTime.now();
    if (date.isAfter(createdAt)) {
      throw ArgumentError.value(wornAt, 'wornAt', 'Cannot record future wear.');
    }

    return db.transaction((txn) async {
      // The join deliberately excludes stale outfit_items references so a
      // missing garment never prevents the remaining outfit from being worn.
      final garmentRows = await txn.rawQuery(
        '''
        SELECT garments.id FROM outfit_items
        INNER JOIN garments ON garments.id = outfit_items.garment_id
        WHERE outfit_items.outfit_id = ?
      ''',
        [outfitId],
      );
      if (garmentRows.isEmpty) return false;

      final timestamp = date.toIso8601String();
      final createdTimestamp = createdAt.toIso8601String();
      for (final row in garmentRows) {
        final garmentId = row['id'] as String;
        await txn.insert('wear_history', {
          'garment_id': garmentId,
          'worn_at': timestamp,
          'created_at': createdTimestamp,
        });
        await _syncGarmentWearData(txn, garmentId);
      }

      final updated = await txn.rawUpdate(
        '''
          UPDATE outfits
          SET times_worn = times_worn + 1,
              last_worn = ?,
              updated_at = ?
          WHERE id = ?
        ''',
        [timestamp, createdTimestamp, outfitId],
      );
      if (updated != 1) {
        throw StateError('Outfit not found: $outfitId');
      }
      return true;
    });
  }

  Future<List<Garment>> getGarmentsInOutfit(String outfitId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT garments.* FROM garments
      INNER JOIN outfit_items ON outfit_items.garment_id = garments.id
      WHERE outfit_items.outfit_id = ?
      ORDER BY garments.name COLLATE NOCASE
    ''',
      [outfitId],
    );
    return rows.map(Garment.fromMap).toList();
  }

  Future<List<Outfit>> getOutfitsContainingGarment(String garmentId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT outfits.* FROM outfits
      INNER JOIN outfit_items ON outfit_items.outfit_id = outfits.id
      WHERE outfit_items.garment_id = ?
      ORDER BY outfits.favorite DESC, outfits.name COLLATE NOCASE
    ''',
      [garmentId],
    );
    return rows.map(Outfit.fromMap).toList();
  }

  Future<void> addGarmentToOutfit(String outfitId, String garmentId) async {
    final db = await database;
    await db.insert(
      'outfit_items',
      OutfitItem(outfitId: outfitId, garmentId: garmentId).toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeGarmentFromOutfit(
    String outfitId,
    String garmentId,
  ) async {
    final db = await database;
    await db.delete(
      'outfit_items',
      where: 'outfit_id = ? AND garment_id = ?',
      whereArgs: [outfitId, garmentId],
    );
  }

  /// Returns a consistent, JSON-ready view of every persisted wardrobe table.
  Future<Map<String, List<Map<String, Object?>>>> exportBackupData() async {
    final db = await database;
    return db.transaction(
      (txn) async => {
        'garments': await txn.query('garments'),
        'outfits': await txn.query('outfits'),
        'outfitItems': await txn.query('outfit_items'),
        // Wishlist V1 is currently UI-only and therefore has no persisted rows.
        'wishlist': <Map<String, Object?>>[],
        'wearHistory': await txn.query('wear_history'),
      },
    );
  }

  /// Atomically replaces all persisted wardrobe data with a validated backup.
  Future<void> restoreBackupData(
    Map<String, List<Map<String, Object?>>> data,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('outfit_items');
      await txn.delete('wear_history');
      await txn.delete('outfits');
      await txn.delete('garments');

      for (final row in data['garments']!) {
        await txn.insert('garments', row);
      }
      for (final row in data['outfits']!) {
        await txn.insert('outfits', row);
      }
      for (final row in data['outfitItems']!) {
        await txn.insert('outfit_items', row);
      }
      for (final row in data['wearHistory']!) {
        await txn.insert('wear_history', row);
      }
    });
  }
}
