import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../../../core/db/database_service.dart';
import '../models/saving_goal.dart';
import 'saving_goal_repository.dart';

class SqfliteSavingGoalRepository implements SavingGoalRepository {
  final DatabaseService _db;
  final _controller = StreamController<List<SavingGoal>>.broadcast();

  SqfliteSavingGoalRepository(this._db) {
    _notify();
  }

  Future<void> _notify() async {
    final rows = await _db.db.query('saving_goals', orderBy: 'id ASC');
    _controller.add(rows.map(SavingGoal.fromMap).toList());
  }

  @override
  Stream<List<SavingGoal>> watchAll() => _controller.stream;

  @override
  Future<void> save(SavingGoal goal) async {
    await _db.db.insert(
      'saving_goals',
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify();
  }

  @override
  Future<void> delete(int id) async {
    await _db.db.delete('saving_goals', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  @override
  Future<void> addContribution(int id, double amount) async {
    await _db.db.rawUpdate(
      'UPDATE saving_goals SET saved_amount = MIN(saved_amount + ?, target_amount) WHERE id = ?',
      [amount, id],
    );
    _notify();
  }
}
