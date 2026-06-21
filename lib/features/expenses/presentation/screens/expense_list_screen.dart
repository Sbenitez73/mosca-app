import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/date_formatter.dart';
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
        title: const Text('Todos los gastos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
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

          // Group by day
          final grouped = <String, List<_Indexed>>{};
          for (int i = 0; i < expenses.length; i++) {
            final key = DateFormatter.fullDate(expenses[i].date);
            (grouped[key] ??= []).add(_Indexed(i, expenses[i]));
          }

          final days = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: days.length,
            itemBuilder: (context, di) {
              final day = days[di];
              final dayExpenses = grouped[day]!;
              final dayTotal = dayExpenses.fold(
                0.0,
                (sum, e) => sum + e.expense.amount,
              );

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
                          '\$${dayTotal.toStringAsFixed(0).replaceAllMapped(
                                RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                                (m) => '${m[1]},',
                              )}',
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
                        final item = entry.value;
                        return Dismissible(
                          key: ValueKey(item.expense.id ?? item.expense.gmailMessageId),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(context, ref, item.expense.id),
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
                                expense: item.expense,
                                onTap: () => context.push('/expenses/edit', extra: item.expense),
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

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref, int? id) async {
    if (id == null) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: const Text('¿Seguro que quieres eliminar este gasto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(expenseRepositoryProvider).delete(id);
      return true;
    }
    return false;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _Indexed {
  final int index;
  final dynamic expense;
  _Indexed(this.index, this.expense);
}
