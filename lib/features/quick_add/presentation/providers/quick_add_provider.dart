import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../expenses/data/models/expense.dart';
import '../../../expenses/data/models/expense_category.dart';
import '../../../expenses/data/models/expense_source.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';

class QuickAddState {
  final String amountBuffer;
  final ExpenseCategory? category;
  final String title;
  final String notes;
  final bool isSaving;
  final String? error;

  const QuickAddState({
    this.amountBuffer = '',
    this.category,
    this.title = '',
    this.notes = '',
    this.isSaving = false,
    this.error,
  });

  double? get parsedAmount {
    if (amountBuffer.isEmpty) return null;
    return double.tryParse(amountBuffer.replaceAll(',', ''));
  }

  bool get isValid => parsedAmount != null && parsedAmount! > 0 && category != null;

  QuickAddState copyWith({
    String? amountBuffer,
    ExpenseCategory? category,
    String? title,
    String? notes,
    bool? isSaving,
    String? error,
  }) {
    return QuickAddState(
      amountBuffer: amountBuffer ?? this.amountBuffer,
      category: category ?? this.category,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }

  QuickAddState clearCategory() => QuickAddState(
        amountBuffer: amountBuffer,
        title: title,
        notes: notes,
        isSaving: isSaving,
      );

  QuickAddState reset() => const QuickAddState();
}

class QuickAddNotifier extends Notifier<QuickAddState> {
  @override
  QuickAddState build() => const QuickAddState();

  void appendDigit(String digit) {
    final current = state.amountBuffer;
    if (current.length >= 10) return;
    // Prevent multiple leading zeros
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

  Future<bool> save({String currency = 'COP'}) async {
    if (!state.isValid) return false;

    state = state.copyWith(isSaving: true);
    try {
      final title = state.title.trim();
      final expense = Expense(
        amount: state.parsedAmount!,
        currency: currency,
        category: state.category!,
        description: title.isEmpty ? state.category!.label : title,
        notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
        date: DateTime.now(),
        source: ExpenseSource.manual,
      );

      await ref.read(expenseRepositoryProvider).save(expense);
      state = const QuickAddState();
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  void reset() => state = const QuickAddState();
}

final quickAddProvider = NotifierProvider<QuickAddNotifier, QuickAddState>(
  QuickAddNotifier.new,
);
