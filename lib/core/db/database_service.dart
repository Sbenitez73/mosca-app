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
      version: 10,
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
        type TEXT NOT NULL DEFAULT 'expense',
        receipt_photo_path TEXT
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
        color_value INTEGER NOT NULL,
        is_income INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_key TEXT NOT NULL UNIQUE,
        amount_limit REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE recurring_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'COP',
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        notes TEXT,
        day_of_month INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'expense',
        last_generated_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE saving_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'COP',
        preset_index INTEGER NOT NULL DEFAULT 7
      )
    ''');
    await _createSharedDebtTables(db);
    await _createSplitTables(db);
  }

  Future<void> _createSplitTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_splits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        amount REAL NOT NULL,
        settled INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(expense_id) REFERENCES expenses(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createSharedDebtTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shared_debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'COP',
        due_day_of_month INTEGER NOT NULL DEFAULT 1,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shared_debt_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id INTEGER NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        paid_by_owner INTEGER NOT NULL DEFAULT 0,
        paid_at INTEGER NOT NULL,
        UNIQUE(debt_id, year, month),
        FOREIGN KEY(debt_id) REFERENCES shared_debts(id) ON DELETE CASCADE
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
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_key TEXT NOT NULL UNIQUE,
          amount_limit REAL NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          currency TEXT NOT NULL DEFAULT 'COP',
          category TEXT NOT NULL,
          description TEXT NOT NULL,
          notes TEXT,
          day_of_month INTEGER NOT NULL,
          type TEXT NOT NULL DEFAULT 'expense',
          last_generated_at INTEGER
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS saving_goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          target_amount REAL NOT NULL,
          saved_amount REAL NOT NULL DEFAULT 0,
          currency TEXT NOT NULL DEFAULT 'COP',
          preset_index INTEGER NOT NULL DEFAULT 7
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute(
        'ALTER TABLE categories ADD COLUMN is_income INTEGER NOT NULL DEFAULT 0',
      );
      await _createSharedDebtTables(db);
    }
    if (oldVersion < 10) {
      await db.execute(
        'ALTER TABLE expenses ADD COLUMN receipt_photo_path TEXT',
      );
      await _createSplitTables(db);
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
