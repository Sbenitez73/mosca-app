import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../expenses/data/models/expense.dart';
import '../../../expenses/data/models/expense_category.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../expenses/presentation/widgets/expense_card.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _prev() => setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _next() => setState(() => _month = DateTime(_month.year, _month.month + 1));

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ym = (_month.year, _month.month);
    final prevDate = DateTime(_month.year, _month.month - 1);
    final prevYm = (prevDate.year, prevDate.month);

    final expensesAsync = ref.watch(monthExpensesProvider(ym));
    final incomesAsync  = ref.watch(monthIncomesProvider(ym));
    final yearlyAsync   = ref.watch(yearlyStatsProvider(_month.year));
    final prevExpensesAsync = ref.watch(monthExpensesProvider(prevYm));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: _prev,
            ),
            Text(
              DateFormatter.monthName(_month),
              style: theme.textTheme.titleLarge,
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                color: _isCurrentMonth
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                    : null,
              ),
              onPressed: _isCurrentMonth ? null : _next,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // ── Monthly summary ─────────────────────────────────────────────
          _MonthlySummary(
            expensesAsync: expensesAsync,
            incomesAsync: incomesAsync,
          ),
          const SizedBox(height: 24),

          // ── Yearly chart ────────────────────────────────────────────────
          Text('Ingresos vs Gastos', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          yearlyAsync.when(
            loading: () => const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (stats) => _ComparisonChart(
              year: _month.year,
              highlightMonth: _month.month,
              byMonthExpense: _aggregate(stats.expenses),
              byMonthIncome: _aggregate(stats.incomes),
            ),
          ),
          const SizedBox(height: 28),

          // ── Category breakdown ──────────────────────────────────────────
          Text('Por categoría', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (expenses) {
              final totals = <String, double>{};
              for (final e in expenses) {
                totals[e.category.name] =
                    (totals[e.category.name] ?? 0) + e.amount;
              }
              final total = totals.values.fold(0.0, (a, b) => a + b);
              if (totals.isEmpty || total == 0) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Sin gastos este mes',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  _PieSection(totals: totals, total: total),
                  const SizedBox(height: 20),
                  _CategoryList(totals: totals, total: total, expenses: expenses),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // ── Month-over-month comparison ─────────────────────────────────
          _MonthComparison(
            prevMonthName: DateFormatter.monthName(prevDate),
            currentAsync: expensesAsync,
            prevAsync: prevExpensesAsync,
          ),
        ],
      ),
    );
  }

  List<double> _aggregate(List<dynamic> items) {
    final result = List.generate(12, (_) => 0.0);
    for (final e in items) {
      result[(e.date as DateTime).month - 1] += (e.amount as double);
    }
    return result;
  }
}

// ─── Monthly summary row ─────────────────────────────────────────────────────

class _MonthlySummary extends StatelessWidget {
  final AsyncValue<List<dynamic>> expensesAsync;
  final AsyncValue<List<dynamic>> incomesAsync;

  const _MonthlySummary({required this.expensesAsync, required this.incomesAsync});

  @override
  Widget build(BuildContext context) {
    final expenses = expensesAsync.maybeWhen(
      data: (list) => list.fold<double>(0, (s, e) => s + (e.amount as double)),
      orElse: () => 0.0,
    );
    final incomes = incomesAsync.maybeWhen(
      data: (list) => list.fold<double>(0, (s, e) => s + (e.amount as double)),
      orElse: () => 0.0,
    );
    final balance = incomes - expenses;
    final isLoading = expensesAsync.isLoading || incomesAsync.isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  _MetricCell(
                    label: 'Gastos',
                    value: expenses,
                    color: const Color(0xFFE53935),
                  ),
                  _Divider(),
                  _MetricCell(
                    label: 'Ingresos',
                    value: incomes,
                    color: const Color(0xFF4CAF50),
                  ),
                  _Divider(),
                  _MetricCell(
                    label: 'Balance',
                    value: balance,
                    color: balance >= 0
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE53935),
                    showSign: true,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: Theme.of(context).dividerColor);
}

class _MetricCell extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool showSign;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.color,
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefix = showSign && value > 0 ? '+' : '';
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$prefix${CurrencyFormatter.format(value)}',
              style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comparison chart ─────────────────────────────────────────────────────────

class _ComparisonChart extends StatelessWidget {
  final int year;
  final int highlightMonth;
  final List<double> byMonthExpense;
  final List<double> byMonthIncome;

  const _ComparisonChart({
    required this.year,
    required this.highlightMonth,
    required this.byMonthExpense,
    required this.byMonthIncome,
  });

  static const _months = ['E','F','M','A','M','J','J','A','S','O','N','D'];
  static const _incomeColor  = Color(0xFF4CAF50);
  static const _expenseColor = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final allValues = [...byMonthExpense, ...byMonthIncome];
    final maxY = allValues.isEmpty ? 1.0
        : allValues.reduce((a, b) => a > b ? a : b) * 1.25;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) => Text(
                          _months[v.toInt()],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: v.toInt() == highlightMonth - 1
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                  barGroups: List.generate(12, (i) {
                    final highlight = i == highlightMonth - 1;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: byMonthExpense[i],
                          color: _expenseColor.withValues(alpha: highlight ? 1 : 0.35),
                          width: 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: byMonthIncome[i],
                          color: _incomeColor.withValues(alpha: highlight ? 1 : 0.35),
                          width: 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(color: _expenseColor, label: 'Gastos'),
                const SizedBox(width: 20),
                _Legend(color: _incomeColor, label: 'Ingresos'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7))),
        ],
      );
}

// ─── Pie section ─────────────────────────────────────────────────────────────

class _PieSection extends StatelessWidget {
  final Map<String, double> totals;
  final double total;
  const _PieSection({required this.totals, required this.total});

  @override
  Widget build(BuildContext context) {
    final sections = totals.entries.map((e) {
      final cat = ExpenseCategory.fromKey(e.key);
      return PieChartSectionData(
          value: e.value, color: cat.color, radius: 60, title: '');
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 180,
          child: PieChart(PieChartData(
            sections: sections,
            centerSpaceRadius: 48,
            sectionsSpace: 2,
          )),
        ),
      ),
    );
  }
}

// ─── Category list ────────────────────────────────────────────────────────────

class _CategoryList extends StatelessWidget {
  final Map<String, double> totals;
  final double total;
  final List<dynamic> expenses;
  const _CategoryList({required this.totals, required this.total, required this.expenses});

  void _showCategorySheet(BuildContext context, ExpenseCategory cat) {
    final catExpenses = (expenses as List<Expense>)
        .where((e) => e.category.key == cat.key)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryExpensesSheet(category: cat, expenses: catExpenses),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final theme = Theme.of(context);

    return Column(
      children: sorted.map((e) {
        final cat = ExpenseCategory.fromKey(e.key);
        final pct = e.value / total;
        return InkWell(
          onTap: () => _showCategorySheet(context, cat),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Container(
                    width: 10, height: 10,
                    decoration:
                        BoxDecoration(color: cat.color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(cat.label, style: theme.textTheme.bodyMedium)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(CurrencyFormatter.format(e.value),
                        style: theme.textTheme.labelLarge),
                    SizedBox(
                      width: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: cat.color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(cat.color),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Category expenses sheet ──────────────────────────────────────────────────

class _CategoryExpensesSheet extends StatelessWidget {
  final ExpenseCategory category;
  final List<Expense> expenses;

  const _CategoryExpensesSheet({required this.category, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = expenses.fold(0.0, (s, e) => s + e.amount);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(category.icon, size: 20, color: category.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(category.label,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Text(CurrencyFormatter.format(total),
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: category.color)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Flexible(
            child: expenses.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Sin gastos en esta categoría',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: expenses.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 68),
                    itemBuilder: (context, i) =>
                        ExpenseCard(expense: expenses[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Month-over-month comparison ──────────────────────────────────────────────

class _MonthComparison extends StatelessWidget {
  final String prevMonthName;
  final AsyncValue<List<dynamic>> currentAsync;
  final AsyncValue<List<dynamic>> prevAsync;

  const _MonthComparison({
    required this.prevMonthName,
    required this.currentAsync,
    required this.prevAsync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final current = currentAsync.maybeWhen(
      data: (list) {
        final m = <String, double>{};
        for (final e in list) {
          m[e.category.name] = (m[e.category.name] ?? 0) + (e.amount as double);
        }
        return m;
      },
      orElse: () => <String, double>{},
    );

    final prev = prevAsync.maybeWhen(
      data: (list) {
        final m = <String, double>{};
        for (final e in list) {
          m[e.category.name] = (m[e.category.name] ?? 0) + (e.amount as double);
        }
        return m;
      },
      orElse: () => <String, double>{},
    );

    final isLoading = currentAsync.isLoading || prevAsync.isLoading;

    // Merge keys from both months, sort by current amount desc
    final keys = {...current.keys, ...prev.keys}.toList()
      ..sort((a, b) => (current[b] ?? 0).compareTo(current[a] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vs $prevMonthName', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : prev.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Sin datos del mes anterior',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: keys.asMap().entries.map((entry) {
                          final i = entry.key;
                          final key = entry.value;
                          final cat = ExpenseCategory.fromKey(key);
                          final cur = current[key] ?? 0;
                          final prv = prev[key] ?? 0;
                          final delta = cur - prv;
                          final isMore = delta > 0;
                          final deltaColor = isMore
                              ? const Color(0xFFE53935)
                              : const Color(0xFF4CAF50);
                          final deltaStr = delta == 0
                              ? '='
                              : '${isMore ? '▲' : '▼'} ${CurrencyFormatter.format(delta.abs())}';

                          return Column(
                            children: [
                              if (i > 0)
                                const Divider(height: 1, indent: 16, endIndent: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: cat.color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(cat.icon, size: 17, color: cat.color),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(cat.label,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(fontWeight: FontWeight.w500)),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(cur),
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          deltaStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: delta == 0
                                                ? theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.4)
                                                : deltaColor,
                                          ),
                                        ),
                                      ],
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
    );
  }
}
