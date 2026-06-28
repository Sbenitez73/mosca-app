import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/expenses/presentation/providers/expenses_provider.dart';
import '../../data/models/expense_split.dart';
import '../../data/models/payment_method.dart';
import '../../data/models/split_contact.dart';
import '../../data/repositories/split_repository.dart';
import '../../data/repositories/sqflite_split_repository.dart';

final splitRepositoryProvider = Provider<SplitRepository>((ref) {
  return SqfliteSplitRepository(ref.watch(databaseServiceProvider));
});

final splitsForExpenseProvider = StreamProvider.autoDispose
    .family<List<ExpenseSplit>, int>((ref, expenseId) {
  return ref.watch(splitRepositoryProvider).watchByExpense(expenseId);
});

final splitExpenseIdsProvider = StreamProvider<Set<int>>((ref) {
  return ref.watch(splitRepositoryProvider).watchSplitExpenseIds();
});

// ── Payment methods ──────────────────────────────────────────────────────────

final paymentMethodsProvider =
    AsyncNotifierProvider<PaymentMethodsNotifier, List<PaymentMethod>>(
  PaymentMethodsNotifier.new,
);

class PaymentMethodsNotifier extends AsyncNotifier<List<PaymentMethod>> {
  static const _key = 'payment_methods';

  @override
  Future<List<PaymentMethod>> build() async {
    final raw = await ref.read(databaseServiceProvider).getSetting(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PaymentMethod.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<PaymentMethod> methods) async {
    final json = jsonEncode(methods.map((m) => m.toMap()).toList());
    await ref.read(databaseServiceProvider).setSetting(_key, json);
    state = AsyncData(methods);
  }
}

// ── Split favorites ───────────────────────────────────────────────────────────

final splitFavoritesProvider =
    AsyncNotifierProvider<SplitFavoritesNotifier, List<SplitContact>>(
  SplitFavoritesNotifier.new,
);

class SplitFavoritesNotifier extends AsyncNotifier<List<SplitContact>> {
  static const _key = 'split_favorites';

  @override
  Future<List<SplitContact>> build() async {
    final raw = await ref.read(databaseServiceProvider).getSetting(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SplitContact.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggle(SplitContact contact) async {
    final current = state.valueOrNull ?? [];
    final exists = current.any(
        (c) => c.name == contact.name && c.phone == contact.phone);
    final updated =
        exists ? current.where((c) => c != contact).toList() : [...current, contact];
    await _persist(updated);
  }

  Future<void> _persist(List<SplitContact> list) async {
    final json = jsonEncode(list.map((c) => c.toMap()).toList());
    await ref.read(databaseServiceProvider).setSetting(_key, json);
    state = AsyncData(list);
  }

  bool isFavorite(SplitContact contact) =>
      state.valueOrNull?.any(
          (c) => c.name == contact.name && c.phone == contact.phone) ??
      false;
}
