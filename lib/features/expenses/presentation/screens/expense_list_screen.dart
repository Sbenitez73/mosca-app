import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/models/expense.dart';
import '../../data/models/transaction_type.dart';
import '../providers/expenses_provider.dart';
import '../widgets/expense_card.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(allExpensesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () async {
              ref.read(searchActiveProvider.notifier).state = true;
              final expenses = expensesAsync.valueOrNull ?? [];
              await showSearch(
                context: context,
                delegate: _ExpenseSearchDelegate(expenses: expenses, ref: ref),
              );
              ref.read(searchActiveProvider.notifier).state = false;
            },
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) {
          if (expenses.isEmpty) {
            return const Center(child: Text('Sin gastos registrados'));
          }

          final grouped = <String, List<Expense>>{};
          for (final e in expenses) {
            final key = DateFormatter.fullDate(e.date);
            (grouped[key] ??= []).add(e);
          }

          final days = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: days.length,
            itemBuilder: (context, di) {
              final day = days[di];
              final dayExpenses = grouped[day]!;
              final dayTotal = dayExpenses.fold(0.0, (sum, e) => sum + e.amount);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _capitalize(day),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(dayTotal),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: dayExpenses.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final expense = entry.value;
                        return Dismissible(
                          key: ValueKey(expense.id ?? expense.gmailMessageId),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(context, ref, expense),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                          child: Column(
                            children: [
                              ExpenseCard(
                                expense: expense,
                                onTap: () => context.push('/expenses/edit', extra: expense),
                              ),
                              if (idx < dayExpenses.length - 1)
                                const Divider(height: 1, indent: 68),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref, Expense expense) async {
    if (expense.id == null) return false;
    final label = switch (expense.type) {
      TransactionType.income   => 'ingreso',
      TransactionType.transfer => 'movimiento',
      TransactionType.expense  => 'gasto',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Eliminar $label'),
        content: Text('¿Seguro que quieres eliminar este $label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(expenseRepositoryProvider).delete(expense.id!);
      return true;
    }
    return false;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ─── Search delegate ──────────────────────────────────────────────────────────

class _ExpenseSearchDelegate extends SearchDelegate<void> {
  final List<Expense> expenses;
  final WidgetRef ref;

  _ExpenseSearchDelegate({required this.expenses, required this.ref});

  @override
  String get searchFieldLabel => 'Buscar gastos...';

  List<Expense> _filter(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    return expenses.where((e) {
      return e.description.toLowerCase().contains(q) ||
          (e.merchantName?.toLowerCase().contains(q) ?? false) ||
          e.category.label.toLowerCase().contains(q) ||
          e.amount.toInt().toString().contains(q);
    }).toList();
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildSuggestions(BuildContext context) => _buildResults(context);

  @override
  Widget buildResults(BuildContext context) => _buildResults(context);

  Widget _buildResults(BuildContext context) {
    final results = _filter(query);
    final theme = Theme.of(context);

    if (query.trim().isEmpty) {
      return Center(
        child: Text(
          'Escribe para buscar',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados para "$query"',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: results.length,
      separatorBuilder: (context2, i2) => const Divider(height: 1, indent: 68),
      itemBuilder: (context, i) {
        final expense = results[i];
        return ExpenseCard(
          expense: expense,
          onTap: () {
            close(context, null);
            context.push('/expenses/edit', extra: expense);
          },
        );
      },
    );
  }
}
