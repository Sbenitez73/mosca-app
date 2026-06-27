import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../features/budgets/presentation/providers/budgets_provider.dart';
import '../../../../features/projection/presentation/providers/projection_provider.dart';
import '../../../../features/recurring/domain/recurring_service.dart';
import '../../../../features/shared_debts/presentation/providers/shared_debts_provider.dart';
import '../providers/expenses_provider.dart';
import '../widgets/expense_card.dart';
import '../widgets/month_summary_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _notifiedTier = <String, int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _processRecurring();
      NotificationService.requestPermissions();
    });
  }

  void _checkBudgetAlerts(List<BudgetStatus> statuses) {
    for (final s in statuses) {
      if (s.budget.limit <= 0) continue;
      final pct = s.spent / s.budget.limit;
      final key = s.budget.category.key;
      final tier = pct >= 1.0 ? 100 : pct >= 0.8 ? 80 : 0;
      final last = _notifiedTier[key] ?? 0;
      if (tier > 0 && tier > last) {
        _notifiedTier[key] = tier;
        NotificationService.showBudgetAlert(
          categoryKey: key,
          categoryLabel: s.budget.category.label,
          isOver: tier >= 100,
          percentUsed: tier,
        );
      }
    }
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
    ref.listen(budgetStatusProvider, (prev, next) => _checkBudgetAlerts(next));
    ref.listen(activeSharedDebtsProvider, (prev, next) {
      if (next.hasValue) NotificationService.rescheduleDebtReminders(next.value!);
    });

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
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  'assets/splash/splash_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
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
            const SliverToBoxAdapter(child: _SharedDebtsSummarySection()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _ProjectionSummarySection()),
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
                  final color = AppColors.budgetBarColor(pct);
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

// ─── Shared debts summary ─────────────────────────────────────────────────────

class _SharedDebtsSummarySection extends ConsumerWidget {
  const _SharedDebtsSummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(activeSharedDebtsProvider);
    final now = DateTime.now();
    final paymentsAsync =
        ref.watch(sharedDebtPaymentsProvider((now.year, now.month)));

    final theme = Theme.of(context);

    final debts = debtsAsync.valueOrNull ?? [];
    final payments = paymentsAsync.valueOrNull ?? [];

    final paymentByDebt = {for (final p in payments) p.debtId: p};

    final pending = debts
        .where((d) => !paymentByDebt.containsKey(d.id))
        .fold<double>(0, (s, d) => s + d.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Deudas compartidas', style: theme.textTheme.titleLarge),
              TextButton(
                onPressed: () => context.push('/shared-debts'),
                child: Text(debts.isEmpty ? 'Agregar' : 'Gestionar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push('/shared-debts'),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: debts.isEmpty
                    ? Row(
                        children: [
                          Icon(
                            Icons.handshake_outlined,
                            size: 28,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.25),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Registrá deudas a tu nombre',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.25),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${debts.length} deuda${debts.length == 1 ? '' : 's'} activa${debts.length == 1 ? '' : 's'}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (pending > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${CurrencyFormatter.format(pending)} pendiente${pending > 0 ? 's' : ''}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFFF9800),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else
                                Text(
                                  'Todo pagado este mes',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF4CAF50),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.25),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Projection summary ───────────────────────────────────────────────────────

class _ProjectionSummarySection extends ConsumerWidget {
  const _ProjectionSummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectionAsync = ref.watch(cashFlowProjectionProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Proyección', style: theme.textTheme.titleLarge),
              TextButton(
                onPressed: () => context.push('/projection'),
                child: const Text('Ver detalle'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push('/projection'),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: projectionAsync.when(
                  loading: () => const Center(
                    child: SizedBox(
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (e, _) => Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Text('No disponible',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                  data: (projections) {
                    if (projections.isEmpty) {
                      return Row(
                        children: [
                          Icon(Icons.show_chart_rounded,
                              size: 28,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.25)),
                          const SizedBox(width: 14),
                          Text('Agregá gastos recurrentes',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              )),
                        ],
                      );
                    }
                    final current  = projections.first;
                    final balance  = current.balance;
                    final balColor = balance >= 0
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE53935);

                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Balance proyectado este mes',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${balance >= 0 ? '+' : ''}${CurrencyFormatter.format(balance)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: balColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          balance >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: balColor,
                          size: 28,
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.25)),
                      ],
                    );
                  },
                ),
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
