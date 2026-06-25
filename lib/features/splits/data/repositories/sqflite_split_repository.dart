import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../../../core/db/database_service.dart';
import '../models/expense_split.dart';
import 'split_repository.dart';

class SqfliteSplitRepository implements SplitRepository {
  final DatabaseService _dbService;
  final _change = StreamController<void>.broadcast();

  SqfliteSplitRepository(this._dbService);

  Database get _db => _dbService.db;

  @override
  Stream<List<ExpenseSplit>> watchByExpense(int expenseId) async* {
    yield await getByExpense(expenseId);
    await for (final _ in _change.stream) {
      yield await getByExpense(expenseId);
    }
  }

  @override
  Future<List<ExpenseSplit>> getByExpense(int expenseId) async {
    final rows = await _db.query(
      'expense_splits',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
      orderBy: 'id ASC',
    );
    return rows.map(ExpenseSplit.fromMap).toList();
  }

  @override
  Future<int?> save(ExpenseSplit split) async {
    int? insertedId;
    if (split.id == null) {
      insertedId = await _db.insert('expense_splits', split.toMap());
    } else {
      await _db.update(
        'expense_splits',
        split.toMap(),
        where: 'id = ?',
        whereArgs: [split.id],
      );
    }
    _change.add(null);
    return insertedId;
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete('expense_splits', where: 'id = ?', whereArgs: [id]);
    _change.add(null);
  }

  @override
  Future<void> markSettled(int id) async {
    await _db.update(
      'expense_splits',
      {'settled': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    _change.add(null);
  }
}
