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
      version: 1,
      onCreate: _onCreate,
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
        date INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        bank_name TEXT,
        card_last_four TEXT,
        merchant_name TEXT,
        gmail_message_id TEXT UNIQUE
      )
    ''');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_expenses_category ON expenses(category)');
  }
}
