import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../expenses/data/models/expense.dart';
import '../../../expenses/data/models/expense_category.dart';
import '../../../expenses/data/models/expense_source.dart';
import '../../../expenses/data/models/transaction_type.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';

class QuickAddState {
  final TransactionType type;
  final String amountBuffer;
  final ExpenseCategory? category;
  final String title;
  final String notes;
  final DateTime date;
  final bool isSaving;
  final String? error;

  QuickAddState({
    this.type = TransactionType.expense,
    this.amountBuffer = '',
    this.category,
    this.title = '',
    this.notes = '',
    DateTime? date,
    this.isSaving = false,
    this.error,
  }) : date = date ?? DateTime.now();

  double? get parsedAmount {
    if (amountBuffer.isEmpty) return null;
    return double.tryParse(amountBuffer.replaceAll(',', ''));
  }

  // Transfers don't need a category — we auto-assign one on save
  bool get isValid => parsedAmount != null && parsedAmount! > 0 &&
      (category != null || type == TransactionType.transfer);

  QuickAddState copyWith({
    TransactionType? type,
    String? amountBuffer,
    ExpenseCategory? category,
    String? title,
    String? notes,
    DateTime? date,
    bool? isSaving,
    String? error,
  }) => QuickAddState(
        type: type ?? this.type,
        amountBuffer: amountBuffer ?? this.amountBuffer,
        category: category ?? this.category,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        date: date ?? this.date,
        isSaving: isSaving ?? this.isSaving,
        error: error,
      );

  QuickAddState clearCategory() => QuickAddState(
        type: type,
        amountBuffer: amountBuffer,
        title: title,
        notes: notes,
        date: date,
        isSaving: isSaving,
      );

  QuickAddState reset() => QuickAddState();
}

class QuickAddNotifier extends Notifier<QuickAddState> {
  @override
  QuickAddState build() => QuickAddState();

  void setType(TransactionType type) {
    state = QuickAddState(
      type: type,
      amountBuffer: state.amountBuffer,
      date: state.date,
    );
  }

  void appendDigit(String digit) {
    final current = state.amountBuffer;
    if (current.length >= 10) return;
    if (current == '0' && digit == '0') return;
    state = state.copyWith(amountBuffer: current + digit);
  }

  void appendDecimal() {
    if (state.amountBuffer.contains('.')) return;
    final buf = state.amountBuffer.isEmpty ? '0.' : '${state.amountBuffer}.';
    state = state.copyWith(amountBuffer: buf);
  }

  void backspace() {
    final current = state.amountBuffer;
    if (current.isEmpty) return;
    state = state.copyWith(amountBuffer: current.substring(0, current.length - 1));
  }

  void setCategory(ExpenseCategory category) {
    state = state.category == category
        ? state.clearCategory()
        : state.copyWith(category: category);
  }

  void setTitle(String v) => state = state.copyWith(title: v);
  void setNotes(String v) => state = state.copyWith(notes: v);
  void setDate(DateTime d) => state = state.copyWith(date: d);

  Future<bool> save({String currency = 'COP'}) async {
    if (!state.isValid) return false;

    state = state.copyWith(isSaving: true);
    try {
      final title = state.title.trim();
      final category = state.category ?? ExpenseCategory.other;
      final expense = Expense(
        amount: state.parsedAmount!,
        currency: currency,
        category: category,
        description: title.isEmpty ? category.label : title,
        notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
        date: state.date,
        source: ExpenseSource.manual,
        type: state.type,
      );

      await ref.read(expenseRepositoryProvider).save(expense);
      state = QuickAddState();
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  void reset() => state = QuickAddState();
}

final quickAddProvider = NotifierProvider<QuickAddNotifier, QuickAddState>(
  QuickAddNotifier.new,
);
