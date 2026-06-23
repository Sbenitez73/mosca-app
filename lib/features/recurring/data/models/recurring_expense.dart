import '../../../expenses/data/models/expense_category.dart';
import '../../../expenses/data/models/transaction_type.dart';

class RecurringExpense {
  final int? id;
  final double amount;
  final String currency;
  final ExpenseCategory category;
  final String description;
  final String? notes;
  final int dayOfMonth; // 1–28
  final TransactionType type;
  final DateTime? lastGeneratedAt;

  const RecurringExpense({
    this.id,
    required this.amount,
    this.currency = 'COP',
    required this.category,
    required this.description,
    this.notes,
    required this.dayOfMonth,
    this.type = TransactionType.expense,
    this.lastGeneratedAt,
  });

  RecurringExpense copyWith({
    int? id,
    double? amount,
    String? currency,
    ExpenseCategory? category,
    String? description,
    String? notes,
    int? dayOfMonth,
    TransactionType? type,
    DateTime? lastGeneratedAt,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      type: type ?? this.type,
      lastGeneratedAt: lastGeneratedAt ?? this.lastGeneratedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'amount': amount,
        'currency': currency,
        'category': category.key,
        'description': description,
        'notes': notes,
        'day_of_month': dayOfMonth,
        'type': type.name,
        'last_generated_at': lastGeneratedAt?.millisecondsSinceEpoch,
      };

  factory RecurringExpense.fromMap(Map<String, dynamic> map) => RecurringExpense(
        id: map['id'] as int?,
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'COP',
        category: ExpenseCategory.fromKey(map['category'] as String? ?? 'other'),
        description: map['description'] as String? ?? '',
        notes: map['notes'] as String?,
        dayOfMonth: map['day_of_month'] as int? ?? 1,
        type: TransactionType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => TransactionType.expense,
        ),
        lastGeneratedAt: map['last_generated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_generated_at'] as int)
            : null,
      );
}
