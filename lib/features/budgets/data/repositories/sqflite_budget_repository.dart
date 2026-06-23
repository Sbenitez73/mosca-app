import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../../../core/db/database_service.dart';
import '../models/budget.dart';
import 'budget_repository.dart';

class SqfliteBudgetRepository implements BudgetRepository {
  final DatabaseService _db;
  final _controller = StreamController<List<Budget>>.broadcast();

  SqfliteBudgetRepository(this._db);

  @override
  Stream<List<Budget>> watchAll() async* {
    yield await _getAll();
    yield* _controller.stream;
  }

  Future<List<Budget>> _getAll() async {
    final rows = await _db.db.query('budgets', orderBy: 'category_key ASC');
    return rows.map(Budget.fromMap).toList();
  }

  void _notify() => _getAll().then(_controller.add);

  @override
  Future<void> save(Budget budget) async {
    await _db.db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify();
  }

  @override
  Future<void> delete(int id) async {
    await _db.db.delete('budgets', where: 'id = ?', whereArgs: [id]);
    _notify();
  }
}
