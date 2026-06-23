import '../models/budget.dart';

abstract class BudgetRepository {
  Stream<List<Budget>> watchAll();
  Future<void> save(Budget budget);
  Future<void> delete(int id);
}
