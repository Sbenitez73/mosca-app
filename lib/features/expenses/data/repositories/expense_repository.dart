import '../models/expense.dart';

abstract class ExpenseRepository {
  Stream<List<Expense>> watchAll();
  Stream<List<Expense>> watchMonth(int year, int month);
  Future<void> save(Expense expense);
  Future<void> delete(int id);
  Future<Expense?> findByGmailMessageId(String messageId);
  Future<List<Expense>> getForStats(int year);
}
