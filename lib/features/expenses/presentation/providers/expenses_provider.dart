import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/db/database_service.dart';
import '../../data/models/expense.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/sqflite_expense_repository.dart';

// Overridden in main() after DatabaseService is initialized
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('databaseServiceProvider must be overridden');
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return SqfliteExpenseRepository(ref.watch(databaseServiceProvider));
});

final currentMonthExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final now = DateTime.now();
  return ref.watch(expenseRepositoryProvider).watchMonth(now.year, now.month);
});

final allExpensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchAll();
});

final monthlyTotalProvider = Provider<double>((ref) {
  return ref.watch(currentMonthExpensesProvider).maybeWhen(
        data: (expenses) => expenses.fold(0.0, (sum, e) => sum + e.amount),
        orElse: () => 0.0,
      );
});

final monthlyTotalByCategoryProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(currentMonthExpensesProvider).maybeWhen(
        data: (expenses) {
          final totals = <String, double>{};
          for (final e in expenses) {
            totals[e.category.name] = (totals[e.category.name] ?? 0) + e.amount;
          }
          return totals;
        },
        orElse: () => {},
      );
});

final yearlyExpensesProvider = FutureProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).getForStats(DateTime.now().year);
});
