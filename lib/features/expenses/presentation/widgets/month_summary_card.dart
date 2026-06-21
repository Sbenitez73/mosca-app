import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/models/expense_category.dart';
import '../providers/expenses_provider.dart';

class MonthSummaryCard extends ConsumerWidget {
  const MonthSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(monthlyTotalProvider);
    final income = ref.watch(monthlyIncomeProvider);
    final balance = ref.watch(monthlyBalanceProvider);
    final expensesAsync = ref.watch(currentMonthExpensesProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    final count = expensesAsync.maybeWhen(data: (e) => e.length, orElse: () => 0);
    final balancePositive = balance >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A7E4A), Color(0xFF0F5E38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A7E4A).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormatter.monthYear(now).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count gastos',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Income / Expense row ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatColumn(
                    label: 'Gastos',
                    amount: expenses,
                    icon: Icons.arrow_downward_rounded,
                    iconColor: const Color(0xFFFF6B6B),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                Expanded(
                  child: _StatColumn(
                    label: 'Ingresos',
                    amount: income,
                    icon: Icons.arrow_upward_rounded,
                    iconColor: const Color(0xFF69F0AE),
                    alignRight: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white24),
            const SizedBox(height: 14),

            // ── Balance ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Balance',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                Row(
                  children: [
                    Icon(
                      balancePositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 16,
                      color: balancePositive
                          ? const Color(0xFF69F0AE)
                          : const Color(0xFFFF6B6B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${balancePositive ? '+' : ''}${CurrencyFormatter.format(balance)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: balancePositive
                            ? const Color(0xFF69F0AE)
                            : const Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            _CategoryBreakdown(),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color iconColor;
  final bool alignRight;

  const _StatColumn({
    required this.label,
    required this.amount,
    required this.icon,
    required this.iconColor,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final padding = alignRight
        ? const EdgeInsets.only(left: 16)
        : const EdgeInsets.only(right: 16);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!alignRight) ...[
                Icon(icon, size: 12, color: iconColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.white60),
              ),
              if (alignRight) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 12, color: iconColor),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            CurrencyFormatter.format(amount),
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(monthlyTotalByCategoryProvider);
    final total = ref.watch(monthlyTotalProvider);
    if (totals.isEmpty || total == 0) return const SizedBox.shrink();

    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: sorted.take(5).map((e) {
                final fraction = e.value / total;
                return Flexible(
                  flex: (fraction * 100).round(),
                  child: Container(
                    color: ExpenseCategory.fromKey(e.key).color,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: top3.map((e) {
            final cat = ExpenseCategory.fromKey(e.key);
            final fraction = (e.value / total * 100).round();
            return Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cat.label,
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Text(
                    '$fraction%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
