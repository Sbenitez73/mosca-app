import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/expenses/presentation/providers/expenses_provider.dart';
import '../../data/models/recurring_expense.dart';
import '../../data/repositories/recurring_repository.dart';
import '../../data/repositories/sqflite_recurring_repository.dart';

export '../../data/models/recurring_expense.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return SqfliteRecurringRepository(ref.watch(databaseServiceProvider));
});

final recurringExpensesProvider = StreamProvider<List<RecurringExpense>>((ref) {
  return ref.watch(recurringRepositoryProvider).watchAll();
});
