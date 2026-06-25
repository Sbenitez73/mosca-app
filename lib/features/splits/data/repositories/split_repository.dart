import '../models/expense_split.dart';

abstract class SplitRepository {
  Stream<List<ExpenseSplit>> watchByExpense(int expenseId);
  Future<List<ExpenseSplit>> getByExpense(int expenseId);
  Future<int?> save(ExpenseSplit split);
  Future<void> delete(int id);
  Future<void> markSettled(int id);
}
