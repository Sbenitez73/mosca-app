import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/network/dio_client.dart';
import '../../../expenses/data/models/expense.dart';
import '../../../expenses/data/models/expense_category.dart';
import '../../../expenses/data/models/expense_source.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../data/gmail_client.dart';
import '../../data/gmail_parser.dart';

// ─── Infrastructure providers ─────────────────────────────────────────────────

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
  );
});

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(ref.watch(googleSignInProvider));
});

final gmailClientProvider = Provider<GmailClient>((ref) {
  return GmailClient(ref.watch(dioClientProvider).dio);
});

// ─── Auth state ───────────────────────────────────────────────────────────────

class GmailAuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.watch(gmailClientProvider).isSignedIn;
  }

  Future<void> signIn() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(gmailClientProvider).signIn();
      return ref.read(gmailClientProvider).isSignedIn;
    });
  }

  Future<void> signOut() async {
    await ref.read(gmailClientProvider).signOut();
    state = const AsyncData(false);
  }
}

final gmailAuthProvider = AsyncNotifierProvider<GmailAuthNotifier, bool>(
  GmailAuthNotifier.new,
);

// ─── Sync state ───────────────────────────────────────────────────────────────

class GmailSyncState {
  final bool isSyncing;
  final int newExpenses;
  final int skipped;
  final String? error;
  final DateTime? lastSync;

  const GmailSyncState({
    this.isSyncing = false,
    this.newExpenses = 0,
    this.skipped = 0,
    this.error,
    this.lastSync,
  });

  GmailSyncState copyWith({
    bool? isSyncing,
    int? newExpenses,
    int? skipped,
    String? error,
    DateTime? lastSync,
  }) =>
      GmailSyncState(
        isSyncing: isSyncing ?? this.isSyncing,
        newExpenses: newExpenses ?? this.newExpenses,
        skipped: skipped ?? this.skipped,
        error: error,
        lastSync: lastSync ?? this.lastSync,
      );
}

class GmailSyncNotifier extends Notifier<GmailSyncState> {
  @override
  GmailSyncState build() => const GmailSyncState();

  Future<void> sync() async {
    state = state.copyWith(isSyncing: true, error: null);

    try {
      final client = ref.read(gmailClientProvider);
      final repo = ref.read(expenseRepositoryProvider);

      final ids = await client.fetchTransactionMessageIds();
      int added = 0;
      int duplicates = 0;
      int parserRejected = 0;

      for (final id in ids) {
        final existing = await repo.findByGmailMessageId(id);
        if (existing != null) {
          duplicates++;
          continue;
        }

        final emailData = await client.fetchMessage(id);
        final parsed = GmailParser.parse(emailData, id);
        if (parsed == null) {
          parserRejected++;
          continue;
        }

        final expense = Expense(
          amount: parsed.amount,
          currency: parsed.currency,
          category: _guessCategory(parsed.merchant),
          description: parsed.merchant ?? parsed.bankName ?? 'Transacción',
          merchantName: parsed.merchant,
          bankName: parsed.bankName,
          cardLastFour: parsed.cardLastFour,
          date: parsed.date,
          source: ExpenseSource.gmail,
          gmailMessageId: parsed.gmailMessageId,
        );

        await repo.save(expense);
        added++;
      }

      state = state.copyWith(
        isSyncing: false,
        newExpenses: added,
        skipped: duplicates + parserRejected,
        lastSync: DateTime.now(),
      );
    } on DioException catch (e) {
      state = state.copyWith(isSyncing: false, error: 'Error de red: ${e.message}');
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }

  // Simple keyword-based category heuristic
  ExpenseCategory _guessCategory(String? merchant) {
    if (merchant == null) return ExpenseCategory.other;
    final lower = merchant.toLowerCase();

    if (_contains(lower, ['rappi', 'ifood', 'restaurante', 'pizza', 'burger', 'café', 'sushi', 'pollo'])) {
      return ExpenseCategory.food;
    }
    if (_contains(lower, ['uber', 'didi', 'taxi', 'gasolina', 'parking', 'peaje', 'terpel', 'biomax'])) {
      return ExpenseCategory.transport;
    }
    if (_contains(lower, ['netflix', 'spotify', 'cinema', 'cine', 'steam', 'playstation', 'xbox'])) {
      return ExpenseCategory.entertainment;
    }
    if (_contains(lower, ['éxito', 'jumbo', 'carulla', 'supermercado', 'amazon', 'mercadolibre', 'zara', 'h&m'])) {
      return ExpenseCategory.shopping;
    }
    if (_contains(lower, ['farmacia', 'drogueria', 'clinica', 'hospital', 'médico', 'doctor'])) {
      return ExpenseCategory.health;
    }
    if (_contains(lower, ['arriendo', 'alquiler', 'gas', 'electricidad', 'agua', 'internet', 'telefono'])) {
      return ExpenseCategory.housing;
    }
    if (_contains(lower, ['universidad', 'colegio', 'coursera', 'udemy', 'platzi'])) {
      return ExpenseCategory.education;
    }
    return ExpenseCategory.other;
  }

  bool _contains(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}

final gmailSyncProvider = NotifierProvider<GmailSyncNotifier, GmailSyncState>(
  GmailSyncNotifier.new,
);
