import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/models/expense.dart';
import '../../data/models/transaction_type.dart';
import '../providers/expenses_provider.dart';
import '../widgets/expense_card.dart';
import '../../../splits/presentation/providers/splits_provider.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  final Set<int> _selectedIds = {};

  bool get _selecting => _selectedIds.isNotEmpty;

  void _toggleSelect(Expense expense) {
    if (expense.id == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(expense.id!)) {
        _selectedIds.remove(expense.id!);
      } else {
        _selectedIds.add(expense.id!);
      }
    });
    ref.read(expenseSelectModeProvider.notifier).state = _selectedIds.isNotEmpty;
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
    ref.read(expenseSelectModeProvider.notifier).state = false;
  }

  void _goMultiSplit(List<Expense> all) {
    final selected =
        all.where((e) => e.id != null && _selectedIds.contains(e.id)).toList();
    if (selected.isEmpty) return;
    _clearSelection();
    context.push('/multi-split', extra: selected);
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(allExpensesProvider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _selecting
              ? Text('${_selectedIds.length} seleccionados')
              : const Text('Historial'),
          leading: _selecting
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clearSelection,
                )
              : null,
          actions: [
            if (!_selecting)
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () async {
                  ref.read(searchActiveProvider.notifier).state = true;
                  final expenses = expensesAsync.valueOrNull ?? [];
                  await showSearch(
                    context: context,
                    delegate:
                        _ExpenseSearchDelegate(expenses: expenses, ref: ref),
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
            final splitIds =
                ref.watch(splitExpenseIdsProvider).valueOrNull ?? {};

            final grouped = <String, List<Expense>>{};
            for (final e in expenses) {
              final key = DateFormatter.fullDate(e.date);
              (grouped[key] ??= []).add(e);
            }

            final days = grouped.keys.toList();

            return Stack(
              children: [
                ListView.builder(
                  padding: EdgeInsets.only(
                      bottom: _selecting ? 100 : 100),
                  itemCount: days.length,
                  itemBuilder: (context, di) {
                    final day = days[di];
                    final dayExpenses = grouped[day]!;
                    final dayTotal =
                        dayExpenses.fold(0.0, (s, e) => s + e.amount);

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
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(dayTotal),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.55),
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
                              final isSelected = expense.id != null &&
                                  _selectedIds.contains(expense.id!);

                              return Dismissible(
                                key: ValueKey(
                                    expense.id ?? expense.gmailMessageId),
                                // Disable swipe-to-delete while in multi-select mode
                                direction: _selecting
                                    ? DismissDirection.none
                                    : DismissDirection.endToStart,
                                onDismissed: (_) =>
                                    _deleteWithUndo(context, ref, expense),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.delete_rounded,
                                          color: Colors.white, size: 22),
                                      SizedBox(height: 4),
                                      Text('Eliminar',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    ExpenseCard(
                                      expense: expense,
                                      selectionMode: _selecting,
                                      selected: isSelected,
                                      hasSplits: expense.id != null &&
                                          splitIds.contains(expense.id),
                                      onTap: () {
                                        if (_selecting) {
                                          _toggleSelect(expense);
                                        } else {
                                          context.push('/expenses/edit',
                                              extra: expense);
                                        }
                                      },
                                      onLongPress: () =>
                                          _toggleSelect(expense),
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
                ),

                // ── Multi-select bottom action bar ──────────────────────────
                if (_selecting)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.fromLTRB(
                          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
                      child: FilledButton.icon(
                        onPressed: () => _goMultiSplit(expenses),
                        icon: const Icon(Icons.call_split_rounded),
                        label: Text(
                            'Dividir juntos (${_selectedIds.length})'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _deleteWithUndo(BuildContext context, WidgetRef ref, Expense expense) {
    if (expense.id == null) return;
    HapticFeedback.mediumImpact();
    ref.read(expenseRepositoryProvider).delete(expense.id!);

    final label = switch (expense.type) {
      TransactionType.income => 'Ingreso',
      TransactionType.transfer => 'Movimiento',
      TransactionType.expense => 'Gasto',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label eliminado'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => ref
                .read(expenseRepositoryProvider)
                .save(expense.copyWith(id: null)),
          ),
        ),
      );
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
      separatorBuilder: (context2, i2) =>
          const Divider(height: 1, indent: 68),
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
