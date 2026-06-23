import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/expenses/presentation/providers/expenses_provider.dart';
import '../../data/models/budget.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/sqflite_budget_repository.dart';

export '../../data/models/budget.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return SqfliteBudgetRepository(ref.watch(databaseServiceProvider));
});

final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchAll();
});

typedef BudgetStatus = ({Budget budget, double spent});

final budgetStatusProvider = Provider<List<BudgetStatus>>((ref) {
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];
  final spending = ref.watch(monthlyTotalByCategoryProvider);
  return budgets
      .map((b) => (budget: b, spent: spending[b.category.key] ?? 0.0))
      .toList();
});
