import 'expense_category.dart';
import 'expense_source.dart';

class Expense {
  final int? id;
  final double amount;
  final String currency;
  final ExpenseCategory category;
  final String description;
  final DateTime date;
  final ExpenseSource source;
  final String? bankName;
  final String? cardLastFour;
  final String? merchantName;
  final String? gmailMessageId;

  const Expense({
    this.id,
    required this.amount,
    this.currency = 'COP',
    required this.category,
    required this.description,
    required this.date,
    this.source = ExpenseSource.manual,
    this.bankName,
    this.cardLastFour,
    this.merchantName,
    this.gmailMessageId,
  });

  Expense copyWith({
    int? id,
    double? amount,
    String? currency,
    ExpenseCategory? category,
    String? description,
    DateTime? date,
    ExpenseSource? source,
    String? bankName,
    String? cardLastFour,
    String? merchantName,
    String? gmailMessageId,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      source: source ?? this.source,
      bankName: bankName ?? this.bankName,
      cardLastFour: cardLastFour ?? this.cardLastFour,
      merchantName: merchantName ?? this.merchantName,
      gmailMessageId: gmailMessageId ?? this.gmailMessageId,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'amount': amount,
        'currency': currency,
        'category': category.name,
        'description': description,
        'date': date.millisecondsSinceEpoch,
        'source': source.name,
        'bank_name': bankName,
        'card_last_four': cardLastFour,
        'merchant_name': merchantName,
        'gmail_message_id': gmailMessageId,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as int?,
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'COP',
        category: ExpenseCategory.values.firstWhere(
          (c) => c.name == map['category'],
          orElse: () => ExpenseCategory.other,
        ),
        description: map['description'] as String? ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        source: ExpenseSource.values.firstWhere(
          (s) => s.name == map['source'],
          orElse: () => ExpenseSource.manual,
        ),
        bankName: map['bank_name'] as String?,
        cardLastFour: map['card_last_four'] as String?,
        merchantName: map['merchant_name'] as String?,
        gmailMessageId: map['gmail_message_id'] as String?,
      );

  String get displayName =>
      merchantName?.isNotEmpty == true ? merchantName! : description;

  @override
  bool operator ==(Object other) =>
      other is Expense && other.id == id && other.gmailMessageId == gmailMessageId;

  @override
  int get hashCode => Object.hash(id, gmailMessageId);
}
