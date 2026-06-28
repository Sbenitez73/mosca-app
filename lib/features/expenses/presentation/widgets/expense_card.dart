import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/category_badge.dart';
import '../../data/models/expense.dart';
import '../../data/models/expense_source.dart';
import '../../data/models/transaction_type.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool selectionMode;
  final bool selected;
  final bool hasSplits;

  const ExpenseCard({
    super.key,
    required this.expense,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.selectionMode = false,
    this.selected = false,
    this.hasSplits = false,
  });

  static const _transferColor = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTransfer = expense.type == TransactionType.transfer;
    final isIncome = expense.type == TransactionType.income;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                if (isTransfer)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _transferColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded,
                        color: _transferColor, size: 22),
                  )
                else
                  CategoryBadge(category: expense.category),
                if (selectionMode)
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.surface.withValues(alpha: 0.7),
                        border: Border.all(
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          expense.displayName.isEmpty
                              ? expense.category.label
                              : expense.displayName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (expense.source == ExpenseSource.gmail)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.mark_email_read_rounded,
                              size: 14, color: colorScheme.secondary),
                        ),
                      if (hasSplits)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.call_split_rounded,
                              size: 14,
                              color: colorScheme.primary.withValues(alpha: 0.7)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTransfer ? _transferSubtitle : _subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(expense.amount,
                      currency: expense.currency),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isTransfer
                        ? _transferColor
                        : isIncome
                            ? const Color(0xFF4CAF50)
                            : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatter.relative(expense.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    final parts = <String>[];
    if (expense.bankName != null) parts.add(expense.bankName!);
    if (expense.cardLastFour != null) parts.add('••••${expense.cardLastFour}');
    if (parts.isEmpty) parts.add(expense.category.label);
    return parts.join(' · ');
  }

  String get _transferSubtitle {
    final parts = <String>['Movimiento'];
    if (expense.bankName != null) parts.add(expense.bankName!);
    return parts.join(' · ');
  }
}
