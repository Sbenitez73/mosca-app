import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../expenses/data/models/expense_category.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(yearlyExpensesProvider);
    final monthlyTotals = ref.watch(monthlyTotalByCategoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormatter.monthYear(DateTime.now())),
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) {
          if (expenses.isEmpty) {
            return const Center(child: Text('Sin datos todavía'));
          }

          // Monthly totals per month (1–12)
          final byMonth = List.generate(12, (_) => 0.0);
          for (final e in expenses) {
            byMonth[e.date.month - 1] += e.amount;
          }

          final total = monthlyTotals.values.fold(0.0, (a, b) => a + b);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              const SizedBox(height: 16),
              _SectionHeader('Gasto mensual'),
              const SizedBox(height: 12),
              _MonthlyBarChart(byMonth: byMonth),
              const SizedBox(height: 28),
              _SectionHeader('Por categoría — este mes'),
              const SizedBox(height: 12),
              if (monthlyTotals.isNotEmpty && total > 0) ...[
                _PieSection(totals: monthlyTotals, total: total),
                const SizedBox(height: 20),
                _CategoryList(totals: monthlyTotals, total: total),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Sin gastos este mes',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List<double> byMonth;
  const _MonthlyBarChart({required this.byMonth});

  static const _months = ['E','F','M','A','M','J','J','A','S','O','N','D'];

  @override
  Widget build(BuildContext context) {
    final max = byMonth.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: max * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) => Text(
                      _months[value.toInt()],
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
              barGroups: List.generate(
                12,
                (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: byMonth[i],
                      color: i == DateTime.now().month - 1
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.3),
                      width: 18,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PieSection extends StatelessWidget {
  final Map<String, double> totals;
  final double total;

  const _PieSection({required this.totals, required this.total});

  @override
  Widget build(BuildContext context) {
    final sections = totals.entries.map((e) {
      final cat = ExpenseCategory.values.firstWhere((c) => c.name == e.key);
      return PieChartSectionData(
        value: e.value,
        color: cat.color,
        radius: 60,
        title: '',
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 48,
              sectionsSpace: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final Map<String, double> totals;
  final double total;

  const _CategoryList({required this.totals, required this.total});

  @override
  Widget build(BuildContext context) {
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final theme = Theme.of(context);

    return Column(
      children: sorted.map((e) {
        final cat = ExpenseCategory.values.firstWhere((c) => c.name == e.key);
        final pct = e.value / total;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(cat.label, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(e.value),
                    style: theme.textTheme.labelLarge,
                  ),
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
            ],
          ),
        );
      }).toList(),
    );
  }
}
