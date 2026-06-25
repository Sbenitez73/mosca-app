import '../models/shared_debt.dart';
import '../models/shared_debt_payment.dart';

abstract class SharedDebtRepository {
  Stream<List<SharedDebt>> watchActive();
  Future<List<SharedDebt>> getAll();
  Future<void> saveDebt(SharedDebt debt);
  Future<void> deactivateDebt(int id);
  Future<void> deleteDebt(int id);

  Stream<List<SharedDebtPayment>> watchPayments(int year, int month);
  Future<void> upsertPayment(SharedDebtPayment payment);
  Future<void> deletePayment(int debtId, int year, int month);
}
