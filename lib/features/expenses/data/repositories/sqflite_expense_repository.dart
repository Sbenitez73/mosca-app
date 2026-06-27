import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../../../core/db/database_service.dart';
import '../models/expense.dart';
import '../models/transaction_type.dart';
import 'expense_repository.dart';

class SqfliteExpenseRepository implements ExpenseRepository {
  final DatabaseService _dbService;
  final _changeController = StreamController<void>.broadcast();

  SqfliteExpenseRepository(this._dbService);

  Database get _db => _dbService.db;

  void _notifyChange() => _changeController.add(null);

  @override
  Stream<List<Expense>> watchAll() => _watchQuery(
        () => _db.query('expenses', orderBy: 'date DESC'),
      );

  @override
  Stream<List<Expense>> watchMonth(int year, int month, {TransactionType? type}) {
    final start = DateTime(year, month).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1).millisecondsSinceEpoch - 1;
    return _watchQuery(
      () => _db.query(
        'expenses',
        where: type != null
            ? 'date BETWEEN ? AND ? AND type = ?'
            : 'date BETWEEN ? AND ?',
        whereArgs: type != null ? [start, end, type.name] : [start, end],
        orderBy: 'date DESC',
      ),
    );
  }

  @override
  Stream<List<Expense>> watchPeriod(DateTime start, DateTime end,
      {TransactionType? type}) {
    final s = start.millisecondsSinceEpoch;
    final e = end.millisecondsSinceEpoch;
    return _watchQuery(
      () => _db.query(
        'expenses',
        where: type != null
            ? 'date BETWEEN ? AND ? AND type = ?'
            : 'date BETWEEN ? AND ?',
        whereArgs: type != null ? [s, e, type.name] : [s, e],
        orderBy: 'date DESC',
      ),
    );
  }

  @override
  Future<void> save(Expense expense) async {
    if (expense.id == null) {
      await _db.insert(
        'expenses',
        expense.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await _db.update(
        'expenses',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );
    }
    _notifyChange();
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    _notifyChange();
  }

  @override
  Future<Expense?> findByGmailMessageId(String messageId) async {
    final rows = await _db.query(
      'expenses',
      where: 'gmail_message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return rows.isEmpty ? null : Expense.fromMap(rows.first);
  }

  @override
  Future<bool> existsInMonth(
    int year,
    int month, {
    required String categoryKey,
    required TransactionType type,
    required double minAmount,
    required double maxAmount,
  }) async {
    final start = DateTime(year, month).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1).millisecondsSinceEpoch - 1;
    final rows = await _db.query(
      'expenses',
      columns: ['COUNT(*) as cnt'],
      where: 'date BETWEEN ? AND ? AND category = ? AND type = ? AND amount BETWEEN ? AND ?',
      whereArgs: [start, end, categoryKey, type.name, minAmount, maxAmount],
    );
    final count = rows.first['cnt'] as int? ?? 0;
    return count > 0;
  }

  @override
  Future<List<Expense>> getForStats(int year, {TransactionType? type}) async {
    final start = DateTime(year).millisecondsSinceEpoch;
    final end = DateTime(year + 1).millisecondsSinceEpoch - 1;
    final rows = await _db.query(
      'expenses',
      where: type != null
          ? 'date BETWEEN ? AND ? AND type = ?'
          : 'date BETWEEN ? AND ?',
      whereArgs: type != null ? [start, end, type.name] : [start, end],
      orderBy: 'date DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Stream<List<Expense>> _watchQuery(
    Future<List<Map<String, dynamic>>> Function() query,
  ) async* {
    yield await _mapRows(query);
    await for (final _ in _changeController.stream) {
      yield await _mapRows(query);
    }
  }

  Future<List<Expense>> _mapRows(
    Future<List<Map<String, dynamic>>> Function() query,
  ) async {
    final rows = await query();
    return rows.map(Expense.fromMap).toList();
  }
}
