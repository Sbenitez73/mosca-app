import 'package:flutter/material.dart';
import '../../features/expenses/data/models/expense_category.dart';

class CategorySelectorField extends StatelessWidget {
  final ExpenseCategory? category;
  final bool showChevron;

  const CategorySelectorField({
    super.key,
    this.category,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return category != null
        ? _CategoryDisplay(category: category!, showChevron: showChevron)
        : _CategoryPlaceholder();
  }
}

class _CategoryDisplay extends StatelessWidget {
  final ExpenseCategory category;
  final bool showChevron;

  const _CategoryDisplay({required this.category, this.showChevron = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: category.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(category.icon, size: 22, color: category.color),
          const SizedBox(width: 12),
          Text(
            category.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: category.color,
            ),
          ),
          if (showChevron) ...[
            const Spacer(),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: category.color.withValues(alpha: 0.6),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.grid_view_rounded,
              size: 22, color: cs.onSurface.withValues(alpha: 0.35)),
          const SizedBox(width: 12),
          Text(
            'Seleccionar categoría',
            style: TextStyle(fontSize: 15, color: cs.onSurface.withValues(alpha: 0.4)),
          ),
          const Spacer(),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: cs.onSurface.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}
