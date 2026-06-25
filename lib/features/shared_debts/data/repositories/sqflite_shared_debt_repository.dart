import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../../../core/db/database_service.dart';
import '../models/shared_debt.dart';
import '../models/shared_debt_payment.dart';
import 'shared_debt_repository.dart';

class SqfliteSharedDebtRepository implements SharedDebtRepository {
  final DatabaseService _dbService;
  final _debtChange    = StreamController<void>.broadcast();
  final _paymentChange = StreamController<void>.broadcast();

  SqfliteSharedDebtRepository(this._dbService);

  Database get _db => _dbService.db;

  // ── Debts ────────────────────────────────────────────────────────────────────

  @override
  Stream<List<SharedDebt>> watchActive() async* {
    yield await _getActive();
    await for (final _ in _debtChange.stream) {
      yield await _getActive();
    }
  }

  Future<List<SharedDebt>> _getActive() async {
    final rows = await _db.query(
      'shared_debts',
      where: 'is_active = 1',
      orderBy: 'label ASC',
    );
    return rows.map(SharedDebt.fromMap).toList();
  }

  @override
  Future<List<SharedDebt>> getAll() async {
    final rows = await _db.query('shared_debts', orderBy: 'label ASC');
    return rows.map(SharedDebt.fromMap).toList();
  }

  @override
  Future<void> saveDebt(SharedDebt debt) async {
    await _db.insert(
      'shared_debts',
      debt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _debtChange.add(null);
  }

  @override
  Future<void> deactivateDebt(int id) async {
    await _db.update(
      'shared_debts',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _debtChange.add(null);
  }

  @override
  Future<void> deleteDebt(int id) async {
    await _db.delete('shared_debts', where: 'id = ?', whereArgs: [id]);
    _debtChange.add(null);
    _paymentChange.add(null);
  }

  // ── Payments ─────────────────────────────────────────────────────────────────

  @override
  Stream<List<SharedDebtPayment>> watchPayments(int year, int month) async* {
    yield await _getPayments(year, month);
    await for (final _ in _paymentChange.stream) {
      yield await _getPayments(year, month);
    }
  }

  Future<List<SharedDebtPayment>> _getPayments(int year, int month) async {
    final rows = await _db.query(
      'shared_debt_payments',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );
    return rows.map(SharedDebtPayment.fromMap).toList();
  }

  @override
  Future<void> upsertPayment(SharedDebtPayment payment) async {
    await _db.insert(
      'shared_debt_payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _paymentChange.add(null);
  }

  @override
  Future<void> deletePayment(int debtId, int year, int month) async {
    await _db.delete(
      'shared_debt_payments',
      where: 'debt_id = ? AND year = ? AND month = ?',
      whereArgs: [debtId, year, month],
    );
    _paymentChange.add(null);
  }
}
