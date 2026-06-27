import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/db/database_service.dart';
import '../../../../core/providers/pay_period_provider.dart';
import '../../../../core/utils/period_utils.dart';
import '../../data/models/expense.dart';
import '../../data/models/expense_category.dart';
import '../../data/models/transaction_type.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/sqflite_category_repository.dart';
import '../../data/repositories/sqflite_expense_repository.dart';

final searchActiveProvider = StateProvider<bool>((ref) => false);
final statsCategorySheetOpenProvider = StateProvider<bool>((ref) => false);

// Overridden in main() after DatabaseService is initialized
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('databaseServiceProvider must be overridden');
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return SqfliteExpenseRepository(ref.watch(databaseServiceProvider));
});

// ─── Expenses (current period) ────────────────────────────────────────────────

final currentMonthExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final cutDay = ref.watch(payPeriodDayProvider).valueOrNull ?? 1;
  final label = ref.watch(currentPeriodLabelProvider);
  final r = PeriodUtils.range(label.year, label.month, cutDay);
  return ref.watch(expenseRepositoryProvider).watchPeriod(
        r.start, r.end,
        type: TransactionType.expense,
      );
});

// ─── Incomes (current period) ─────────────────────────────────────────────────

final currentMonthIncomesProvider = StreamProvider<List<Expense>>((ref) {
  final cutDay = ref.watch(payPeriodDayProvider).valueOrNull ?? 1;
  final label = ref.watch(currentPeriodLabelProvider);
  final r = PeriodUtils.range(label.year, label.month, cutDay);
  return ref.watch(expenseRepositoryProvider).watchPeriod(
        r.start, r.end,
        type: TransactionType.income,
      );
});

// ─── All transactions (both types, all history) ───────────────────────────────

final allExpensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchAll();
});

// ─── Totals ───────────────────────────────────────────────────────────────────

final monthlyTotalProvider = Provider<double>((ref) {
  return ref.watch(currentMonthExpensesProvider).maybeWhen(
        data: (expenses) => expenses.fold(0.0, (sum, e) => sum + e.amount),
        orElse: () => 0.0,
      );
});

final monthlyIncomeProvider = Provider<double>((ref) {
  return ref.watch(currentMonthIncomesProvider).maybeWhen(
        data: (incomes) => incomes.fold(0.0, (sum, e) => sum + e.amount),
        orElse: () => 0.0,
      );
});

final monthlyBalanceProvider = Provider<double>((ref) {
  return ref.watch(monthlyIncomeProvider) - ref.watch(monthlyTotalProvider);
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

// ─── Yearly (for stats) ───────────────────────────────────────────────────────

final yearlyExpensesProvider = FutureProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).getForStats(
        DateTime.now().year,
        type: TransactionType.expense,
      );
});

final yearlyIncomesProvider = FutureProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).getForStats(
        DateTime.now().year,
        type: TransactionType.income,
      );
});

// ─── Stats: month-navigable family providers ──────────────────────────────────

final monthExpensesProvider = StreamProvider.autoDispose
    .family<List<Expense>, (int, int)>((ref, ym) {
  final cutDay = ref.watch(payPeriodDayProvider).valueOrNull ?? 1;
  final r = PeriodUtils.range(ym.$1, ym.$2, cutDay);
  return ref
      .watch(expenseRepositoryProvider)
      .watchPeriod(r.start, r.end, type: TransactionType.expense);
});

final monthIncomesProvider = StreamProvider.autoDispose
    .family<List<Expense>, (int, int)>((ref, ym) {
  final cutDay = ref.watch(payPeriodDayProvider).valueOrNull ?? 1;
  final r = PeriodUtils.range(ym.$1, ym.$2, cutDay);
  return ref
      .watch(expenseRepositoryProvider)
      .watchPeriod(r.start, r.end, type: TransactionType.income);
});

typedef _YearlyStats = ({List<Expense> expenses, List<Expense> incomes});

final yearlyStatsProvider = FutureProvider.autoDispose
    .family<_YearlyStats, int>((ref, year) async {
  final repo = ref.watch(expenseRepositoryProvider);
  final expenses = await repo.getForStats(year, type: TransactionType.expense);
  final incomes  = await repo.getForStats(year, type: TransactionType.income);
  return (expenses: expenses, incomes: incomes);
});

// ─── Categories ───────────────────────────────────────────────────────────────

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return SqfliteCategoryRepository(ref.watch(databaseServiceProvider));
});

final customCategoriesProvider = StreamProvider<List<ExpenseCategory>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});

final allCategoriesProvider = Provider<List<ExpenseCategory>>((ref) {
  final customs = ref.watch(customCategoriesProvider).valueOrNull ?? [];
  return [
    ...ExpenseCategory.builtins.where((c) => !c.isIncome),
    ...customs.where((c) => !c.isIncome),
  ];
});

final allIncomeCategoriesProvider = Provider<List<ExpenseCategory>>((ref) {
  final customs = ref.watch(customCategoriesProvider).valueOrNull ?? [];
  return [
    ...ExpenseCategory.incomeBuiltins,
    ...customs.where((c) => c.isIncome),
  ];
});
