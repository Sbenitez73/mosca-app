import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../../../core/db/database_service.dart';
import '../models/recurring_expense.dart';
import 'recurring_repository.dart';

class SqfliteRecurringRepository implements RecurringRepository {
  final DatabaseService _db;
  final _controller = StreamController<List<RecurringExpense>>.broadcast();

  SqfliteRecurringRepository(this._db);

  @override
  Stream<List<RecurringExpense>> watchAll() async* {
    yield await getAll();
    yield* _controller.stream;
  }

  @override
  Future<List<RecurringExpense>> getAll() async {
    final rows = await _db.db.query('recurring_expenses', orderBy: 'description ASC');
    return rows.map(RecurringExpense.fromMap).toList();
  }

  void _notify() => getAll().then(_controller.add);

  @override
  Future<void> save(RecurringExpense expense) async {
    if (expense.id == null) {
      await _db.db.insert(
        'recurring_expenses',
        expense.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await _db.db.update(
        'recurring_expenses',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );
    }
    _notify();
  }

  @override
  Future<void> delete(int id) async {
    await _db.db.delete('recurring_expenses', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  @override
  Future<void> updateLastGenerated(int id, DateTime date) async {
    await _db.db.update(
      'recurring_expenses',
      {'last_generated_at': date.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify();
  }
}
