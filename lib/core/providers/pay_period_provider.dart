import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/period_utils.dart';
import '../../features/expenses/presentation/providers/expenses_provider.dart';

const _kPayPeriodDay = 'pay_period_day';

/// The cut-off day configured by the user (1 = calendar month, default).
final payPeriodDayProvider =
    AsyncNotifierProvider<PayPeriodDayNotifier, int>(PayPeriodDayNotifier.new);

class PayPeriodDayNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final db = ref.watch(databaseServiceProvider);
    final raw = await db.getSetting(_kPayPeriodDay);
    return int.tryParse(raw ?? '') ?? 1;
  }

  Future<void> setDay(int day) async {
    final db = ref.read(databaseServiceProvider);
    await db.setSetting(_kPayPeriodDay, day.toString());
    state = AsyncData(day);
  }
}

/// The (year, month) label of the current active period.
final currentPeriodLabelProvider = Provider<({int year, int month})>((ref) {
  final cutDay = ref.watch(payPeriodDayProvider).valueOrNull ?? 1;
  return PeriodUtils.currentPeriodLabel(DateTime.now(), cutDay);
});
