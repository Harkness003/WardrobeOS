import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/garment.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'wardrobeos.db'),
      version: 2,
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
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addColumn(db, 'garments', 'style', 'TEXT');
          await _addColumn(db, 'garments', 'occasion', 'TEXT');
          await _addColumn(db, 'garments', 'condition', 'TEXT');
          await _addColumn(db, 'garments', 'purchase_price', 'REAL');
          await _addColumn(db, 'garments', 'purchase_date', 'TEXT');
          await _addColumn(db, 'garments', 'wear_count', 'INTEGER NOT NULL DEFAULT 0');
          await _addColumn(db, 'garments', 'last_worn', 'TEXT');
          await _addColumn(db, 'garments', 'size', 'TEXT');
          await _addColumn(db, 'garments', 'fit', 'TEXT');
          await _addColumn(db, 'garments', 'composition', 'TEXT');
          await _createIndexes(db);
        }
      },
    );
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
  }

  Future<List<Garment>> getGarments({
    String search = '',
    String category = 'Tout',
    bool favoritesOnly = false,
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

  Future<void> deleteGarment(String id) async {
    final db = await database;
    await db.delete('garments', where: 'id = ?', whereArgs: [id]);
  }
}
