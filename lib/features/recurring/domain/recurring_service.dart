import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../expenses/data/models/expense.dart';
import '../../expenses/data/models/expense_source.dart';
import '../../expenses/presentation/providers/expenses_provider.dart';
import '../presentation/providers/recurring_provider.dart';

class RecurringService {
  static const _tolerance = 0.10; // ±10%

  /// Generates due recurring expenses. Returns how many were created.
  /// Skips generation if a matching expense already exists this month
  /// (e.g. imported from Gmail) — same category, type, amount within ±10%.
  static Future<int> processRecurring(WidgetRef ref) async {
    final now = DateTime.now();
    final recurringRepo = ref.read(recurringRepositoryProvider);
    final expenseRepo = ref.read(expenseRepositoryProvider);

    final templates = await recurringRepo.getAll();
    int generated = 0;

    for (final t in templates) {
      // Cap day to last day of current month (avoids Feb-31 issues)
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      final targetDay = t.dayOfMonth.clamp(1, lastDay);
      final targetDate = DateTime(now.year, now.month, targetDay);

      if (targetDate.isAfter(now)) continue;

      final last = t.lastGeneratedAt;
      final alreadyProcessed = last != null &&
          (last.year > now.year ||
              (last.year == now.year && last.month >= now.month));

      if (alreadyProcessed) continue;

      // Opción A: skip if a matching expense already exists this month
      final minAmount = t.amount * (1 - _tolerance);
      final maxAmount = t.amount * (1 + _tolerance);
      final alreadyExists = await expenseRepo.existsInMonth(
        now.year,
        now.month,
        categoryKey: t.category.key,
        type: t.type,
        minAmount: minAmount,
        maxAmount: maxAmount,
      );

      // Whether we created it or found it via Gmail, mark month as processed
      if (t.id != null) {
        await recurringRepo.updateLastGenerated(t.id!, now);
      }

      if (alreadyExists) continue;

      await expenseRepo.save(Expense(
        amount: t.amount,
        currency: t.currency,
        category: t.category,
        description: t.description,
        notes: t.notes,
        date: targetDate,
        source: ExpenseSource.manual,
        type: t.type,
      ));

      generated++;
    }

    return generated;
  }
}
