import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../data/models/shared_debt.dart';
import '../../data/models/shared_debt_payment.dart';
import '../../data/repositories/shared_debt_repository.dart';
import '../../data/repositories/sqflite_shared_debt_repository.dart';

final sharedDebtRepositoryProvider = Provider<SharedDebtRepository>((ref) {
  return SqfliteSharedDebtRepository(ref.watch(databaseServiceProvider));
});

final activeSharedDebtsProvider = StreamProvider<List<SharedDebt>>((ref) {
  return ref.watch(sharedDebtRepositoryProvider).watchActive();
});

final sharedDebtPaymentsProvider = StreamProvider.autoDispose
    .family<List<SharedDebtPayment>, (int, int)>((ref, ym) {
  return ref.watch(sharedDebtRepositoryProvider).watchPayments(ym.$1, ym.$2);
});
