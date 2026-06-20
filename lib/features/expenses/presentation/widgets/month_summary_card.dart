import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../providers/expenses_provider.dart';

class MonthSummaryCard extends ConsumerWidget {
  const MonthSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(monthlyTotalProvider);
    final expensesAsync = ref.watch(currentMonthExpensesProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    final count = expensesAsync.maybeWhen(data: (e) => e.length, orElse: () => 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0F5E38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
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
            const SizedBox(height: 12),
            Text(
              CurrencyFormatter.format(total),
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'gastados este mes',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
            const SizedBox(height: 20),
            _CategoryBreakdown(),
          ],
        ),
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
        // Progress bar — top category fills it
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: sorted.take(5).map((e) {
                final fraction = e.value / total;
                return Flexible(
                  flex: (fraction * 100).round(),
                  child: Container(color: _colorFor(e.key)),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: top3.map((e) {
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
                          color: _colorFor(e.key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _labelFor(e.key),
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

  Color _colorFor(String categoryName) {
    switch (categoryName) {
      case 'food': return AppColors.catFood;
      case 'transport': return AppColors.catTransport;
      case 'entertainment': return AppColors.catEntertainment;
      case 'shopping': return AppColors.catShopping;
      case 'health': return AppColors.catHealth;
      case 'housing': return AppColors.catHousing;
      case 'education': return AppColors.catEducation;
      default: return AppColors.catOther;
    }
  }

  String _labelFor(String categoryName) {
    switch (categoryName) {
      case 'food': return 'Comida';
      case 'transport': return 'Transporte';
      case 'entertainment': return 'Entret.';
      case 'shopping': return 'Compras';
      case 'health': return 'Salud';
      case 'housing': return 'Vivienda';
      case 'education': return 'Educac.';
      default: return 'Otro';
    }
  }
}
