import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../expenses/data/models/expense.dart';
import '../../expenses/data/models/expense_source.dart';
import '../../expenses/presentation/providers/expenses_provider.dart';
import '../presentation/providers/recurring_provider.dart';

class RecurringService {
  /// Generates due recurring expenses. Returns how many were created.
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
      final alreadyGenerated = last != null &&
          (last.year > now.year ||
              (last.year == now.year && last.month >= now.month));

      if (alreadyGenerated) continue;

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

      if (t.id != null) {
        await recurringRepo.updateLastGenerated(t.id!, now);
      }
      generated++;
    }

    return generated;
  }
}
