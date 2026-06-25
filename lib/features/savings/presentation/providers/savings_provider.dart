import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/expenses/presentation/providers/expenses_provider.dart';
import '../../data/models/saving_goal.dart';
import '../../data/repositories/saving_goal_repository.dart';
import '../../data/repositories/sqflite_saving_goal_repository.dart';

export '../../data/models/saving_goal.dart';

final savingGoalRepositoryProvider = Provider<SavingGoalRepository>((ref) {
  return SqfliteSavingGoalRepository(ref.watch(databaseServiceProvider));
});

final savingGoalsProvider = StreamProvider<List<SavingGoal>>((ref) {
  return ref.watch(savingGoalRepositoryProvider).watchAll();
});
