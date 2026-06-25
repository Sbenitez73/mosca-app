import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/db/database_service.dart';
import '../models/expense_category.dart';
import 'category_repository.dart';

class SqfliteCategoryRepository implements CategoryRepository {
  final DatabaseService _dbService;
  final _changeController = StreamController<void>.broadcast();

  SqfliteCategoryRepository(this._dbService);

  Database get _db => _dbService.db;

  @override
  Stream<List<ExpenseCategory>> watchAll() async* {
    yield await getAll();
    await for (final _ in _changeController.stream) {
      yield await getAll();
    }
  }

  @override
  Future<List<ExpenseCategory>> getAll() async {
    final rows = await _db.query('categories', orderBy: 'label ASC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> save(ExpenseCategory cat) async {
    await _db.insert(
      'categories',
      {
        'key': cat.key,
        'label': cat.label,
        'color_value': cat.color.toARGB32(),
        'is_income': cat.isIncome ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    ExpenseCategory.registerCustom([cat]);
    _changeController.add(null);
  }

  @override
  Future<void> delete(String key) async {
    await _db.delete('categories', where: 'key = ?', whereArgs: [key]);
    ExpenseCategory.unregister(key);
    _changeController.add(null);
  }

  ExpenseCategory _fromRow(Map<String, dynamic> row) => ExpenseCategory.custom(
        key: row['key'] as String,
        label: row['label'] as String,
        color: Color(row['color_value'] as int),
        isIncome: (row['is_income'] as int? ?? 0) == 1,
      );
}
