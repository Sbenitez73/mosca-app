import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../expenses/data/models/transaction_type.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../../shared_debts/presentation/providers/shared_debts_provider.dart';

class ProjectionItem {
  final String label;
  final double amount;
  final bool isIncome;
  final bool isActual;

  const ProjectionItem({
    required this.label,
    required this.amount,
    required this.isIncome,
    required this.isActual,
  });
}

class MonthProjection {
  final DateTime month;
  final double actualIncome;
  final double actualExpense;
  final double projectedIncome;
  final double projectedExpense;
  final List<ProjectionItem> items;

  const MonthProjection({
    required this.month,
    required this.actualIncome,
    required this.actualExpense,
    required this.projectedIncome,
    required this.projectedExpense,
    required this.items,
  });

  double get totalIncome => actualIncome + projectedIncome;
  double get totalExpense => actualExpense + projectedExpense;
  double get balance => totalIncome - totalExpense;
}

final cashFlowProjectionProvider =
    FutureProvider<List<MonthProjection>>((ref) async {
  final expenseRepo   = ref.watch(expenseRepositoryProvider);
  final recurringList = await ref.watch(recurringExpensesProvider.future);
  final sharedDebts   = await ref.watch(activeSharedDebtsProvider.future);

  final now = DateTime.now();
  final projections = <MonthProjection>[];

  for (var i = 0; i < 3; i++) {
    final month = DateTime(now.year, now.month + i);
    final isCurrentMonth = i == 0;
    final items = <ProjectionItem>[];

    double actualIncome  = 0;
    double actualExpense = 0;

    if (isCurrentMonth) {
      final realExpenses = await expenseRepo.watchMonth(
        now.year, now.month,
        type: TransactionType.expense,
      ).first;
      final realIncomes = await expenseRepo.watchMonth(
        now.year, now.month,
        type: TransactionType.income,
      ).first;

      actualExpense = realExpenses.fold(0.0, (s, e) => s + e.amount);
      actualIncome  = realIncomes.fold(0.0, (s, e) => s + e.amount);

      items.add(ProjectionItem(
        label: 'Ingresos reales',
        amount: actualIncome,
        isIncome: true,
        isActual: true,
      ));
      items.add(ProjectionItem(
        label: 'Gastos reales',
        amount: actualExpense,
        isIncome: false,
        isActual: true,
      ));
    }

    double projectedIncome  = 0;
    double projectedExpense = 0;

    for (final r in recurringList) {
      final pending = isCurrentMonth ? r.dayOfMonth > now.day : true;
      if (!pending) continue;

      if (r.type == TransactionType.income) {
        projectedIncome += r.amount;
        items.add(ProjectionItem(
          label: r.description,
          amount: r.amount,
          isIncome: true,
          isActual: false,
        ));
      } else {
        projectedExpense += r.amount;
        items.add(ProjectionItem(
          label: r.description,
          amount: r.amount,
          isIncome: false,
          isActual: false,
        ));
      }
    }

    for (final d in sharedDebts) {
      projectedExpense += d.amount;
      items.add(ProjectionItem(
        label: '${d.label} (${d.ownerName})',
        amount: d.amount,
        isIncome: false,
        isActual: false,
      ));
    }

    projections.add(MonthProjection(
      month: month,
      actualIncome: actualIncome,
      actualExpense: actualExpense,
      projectedIncome: projectedIncome,
      projectedExpense: projectedExpense,
      items: items,
    ));
  }

  return projections;
});
