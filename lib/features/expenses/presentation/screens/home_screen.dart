import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/budgets/presentation/providers/budgets_provider.dart';
import '../../../../features/recurring/domain/recurring_service.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../providers/expenses_provider.dart';
import '../widgets/expense_card.dart';
import '../widgets/month_summary_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _processRecurring();
    });
  }

  Future<void> _processRecurring() async {
    final count = await RecurringService.processRecurring(ref);
    if (count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Se registraron $count gasto${count == 1 ? '' : 's'} recurrente${count == 1 ? '' : 's'}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _syncWidget() {
    final expenses = ref.read(monthlyTotalProvider);
    final incomes = ref.read(monthlyIncomeProvider);
    final balance = ref.read(monthlyBalanceProvider);
    HomeWidgetService.updateBalance(
      expenses: expenses,
      incomes: incomes,
      balance: balance,
      monthName: DateFormatter.monthName(DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(monthlyTotalProvider, (prev, next) => _syncWidget());
    ref.listen(monthlyIncomeProvider, (prev, next) => _syncWidget());

    final expensesAsync = ref.watch(currentMonthExpensesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pest_control, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Mosca', style: theme.textTheme.headlineSmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sincronizar Gmail',
            onPressed: () => context.go('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(currentMonthExpensesProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const SliverToBoxAdapter(child: MonthSummaryCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            const SliverToBoxAdapter(child: _BudgetSummarySection()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recientes', style: theme.textTheme.titleLarge),
                    TextButton(
                      onPressed: () => context.go('/expenses'),
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            expensesAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error: $e')),
              ),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return SliverToBoxAdapter(child: _EmptyState());
                }
                final recent = expenses.take(10).toList();
                return SliverList.separated(
                  itemCount: recent.length,
                  separatorBuilder: (context2, i2) => const Divider(height: 1, indent: 68),
                  itemBuilder: (context, i) => ExpenseCard(
                    expense: recent[i],
                    onTap: () => context.push('/expenses/edit', extra: recent[i]),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ─── Budget summary ───────────────────────────────────────────────────────────

class _BudgetSummarySection extends ConsumerWidget {
  const _BudgetSummarySection();

  Color _barColor(double pct) {
    if (pct > 1.0) return const Color(0xFFE53935);
    if (pct > 0.8) return const Color(0xFFFF9800);
    return const Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusList = ref.watch(budgetStatusProvider);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Presupuestos', style: theme.textTheme.titleLarge),
              TextButton(
                onPressed: () => context.push('/budgets'),
                child: Text(statusList.isEmpty ? 'Agregar' : 'Gestionar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (statusList.isEmpty)
            GestureDetector(
              onTap: () => context.push('/budgets'),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.savings_outlined,
                          size: 28,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.25)),
                      const SizedBox(width: 14),
                      Text(
                        'Definí límites por categoría',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4)),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.25)),
                    ],
                  ),
                ),
              ),
            )
          else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: statusList.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final cat = s.budget.category;
                  final pct = s.budget.limit > 0
                      ? s.spent / s.budget.limit
                      : 0.0;
                  final color = _barColor(pct);
                  final isOver = pct > 1.0;

                  return Column(
                    children: [
                      if (i > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(cat.icon, size: 18, color: cat.color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cat.label,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (isOver)
                                  Icon(Icons.warning_rounded,
                                      size: 16, color: color)
                                else
                                  Text(
                                    '${CurrencyFormatter.format(s.spent)} / ${CurrencyFormatter.format(s.budget.limit)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.55)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct.clamp(0.0, 1.0),
                                backgroundColor:
                                    color.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation(color),
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin gastos este mes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el botón + para registrar tu primer gasto',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
          ),
        ],
      ),
    );
  }
}
