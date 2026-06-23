import '../models/recurring_expense.dart';

abstract class RecurringRepository {
  Stream<List<RecurringExpense>> watchAll();
  Future<void> save(RecurringExpense expense);
  Future<void> delete(int id);
  Future<void> updateLastGenerated(int id, DateTime date);
  Future<List<RecurringExpense>> getAll();
}
