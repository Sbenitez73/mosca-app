import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../providers/projection_provider.dart';

class ProjectionScreen extends ConsumerWidget {
  const ProjectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectionAsync = ref.watch(cashFlowProjectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Proyección')),
      body: projectionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (projections) {
          final cumulativeBalance =
              projections.fold<double>(0, (s, p) => s + p.balance);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              ...projections.map((p) => _MonthCard(projection: p)),
              const SizedBox(height: 8),
              _CumulativeCard(balance: cumulativeBalance),
            ],
          );
        },
      ),
    );
  }
}

// ─── Month card ───────────────────────────────────────────────────────────────

class _MonthCard extends StatefulWidget {
  final MonthProjection projection;
  const _MonthCard({required this.projection});

  @override
  State<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends State<_MonthCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const incomeColor  = AppColors.income;
    const expenseColor = AppColors.expense;
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final p     = widget.projection;
    final now   = DateTime.now();
    final isCurrentMonth =
        p.month.year == now.year && p.month.month == now.month;

    final balanceColor = p.balance >= 0 ? incomeColor : expenseColor;
    final daysInMonth  = DateUtils.getDaysInMonth(p.month.year, p.month.month);
    final dayProgress  = isCurrentMonth ? now.day / daysInMonth : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormatter.monthName(p.month),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${p.balance >= 0 ? '+' : ''}${CurrencyFormatter.format(p.balance)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: balanceColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Ingresos / Gastos row ────────────────────────────────────
              Row(
                children: [
                  _MetricChip(
                    label: 'Ingresos',
                    value: p.totalIncome,
                    color: incomeColor,
                    hasActual: isCurrentMonth && p.actualIncome > 0,
                    actualValue: p.actualIncome,
                  ),
                  const SizedBox(width: 12),
                  _MetricChip(
                    label: 'Gastos',
                    value: p.totalExpense,
                    color: expenseColor,
                    hasActual: isCurrentMonth && p.actualExpense > 0,
                    actualValue: p.actualExpense,
                  ),
                ],
              ),

              // ── Month progress bar ───────────────────────────────────────
              if (dayProgress != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: dayProgress,
                          backgroundColor:
                              cs.onSurface.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(
                              cs.onSurface.withValues(alpha: 0.3)),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Día ${now.day} / $daysInMonth',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ],

              // ── Expandable items ─────────────────────────────────────────
              if (_expanded && p.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...p.items.map((item) => _ItemRow(item: item)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool hasActual;
  final double actualValue;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
    required this.hasActual,
    required this.actualValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              CurrencyFormatter.format(value),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (hasActual)
              Text(
                '${CurrencyFormatter.format(actualValue)} reales',
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ProjectionItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final color = item.isIncome ? AppColors.income : AppColors.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: item.isActual
                  ? cs.onSurface.withValues(alpha: 0.08)
                  : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.isActual ? 'Real' : 'Proyectado',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: item.isActual
                    ? cs.onSurface.withValues(alpha: 0.45)
                    : color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${item.isIncome ? '+' : '-'}${CurrencyFormatter.format(item.amount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Cumulative card ──────────────────────────────────────────────────────────

class _CumulativeCard extends StatelessWidget {
  final double balance;
  const _CumulativeCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = balance >= 0 ? AppColors.income : AppColors.expense;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance acumulado 3 meses',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${balance >= 0 ? '+' : ''}${CurrencyFormatter.format(balance)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              balance >= 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: color,
              size: 36,
            ),
          ],
        ),
      ),
    );
  }
}
