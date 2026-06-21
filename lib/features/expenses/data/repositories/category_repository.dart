import '../models/expense_category.dart';

abstract class CategoryRepository {
  Stream<List<ExpenseCategory>> watchAll();
  Future<List<ExpenseCategory>> getAll();
  Future<void> save(ExpenseCategory category);
  Future<void> delete(String key);
}
