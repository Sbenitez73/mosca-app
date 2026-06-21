import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  late final Database _db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'mosca.db');

    _db = await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Database get db => _db;

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'COP',
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        notes TEXT,
        date INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        bank_name TEXT,
        card_last_four TEXT,
        merchant_name TEXT,
        gmail_message_id TEXT UNIQUE,
        type TEXT NOT NULL DEFAULT 'expense'
      )
    ''');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_expenses_category ON expenses(category)');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        key TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        color_value INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onOpen(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(expenses)');
    final hasType = cols.any((c) => c['name'] == 'type');
    if (!hasType) {
      await db.execute(
        "ALTER TABLE expenses ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'",
      );
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE expenses ADD COLUMN notes TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          key TEXT PRIMARY KEY,
          label TEXT NOT NULL,
          color_value INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE expenses ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'",
      );
    }
  }

  Future<String?> getSetting(String key) async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
