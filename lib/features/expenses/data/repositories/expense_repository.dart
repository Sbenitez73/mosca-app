import '../models/expense.dart';
import '../models/transaction_type.dart';

abstract class ExpenseRepository {
  Stream<List<Expense>> watchAll();
  Stream<List<Expense>> watchMonth(int year, int month, {TransactionType? type});
  Future<void> save(Expense expense);
  Future<void> delete(int id);
  Future<Expense?> findByGmailMessageId(String messageId);
  Future<List<Expense>> getForStats(int year, {TransactionType? type});
}
