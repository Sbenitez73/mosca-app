import '../models/saving_goal.dart';

abstract class SavingGoalRepository {
  Stream<List<SavingGoal>> watchAll();
  Future<void> save(SavingGoal goal);
  Future<void> delete(int id);
  Future<void> addContribution(int id, double amount);
}
