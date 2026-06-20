import 'package:flutter/material.dart';
import '../../features/expenses/data/models/expense_category.dart';

class CategoryBadge extends StatelessWidget {
  final ExpenseCategory category;
  final double size;

  const CategoryBadge({super.key, required this.category, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        category.icon,
        size: size * 0.55,
        color: category.color,
      ),
    );
  }
}
