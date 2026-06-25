import 'expense_category.dart';
import 'expense_source.dart';
import 'transaction_type.dart';

class Expense {
  final int? id;
  final double amount;
  final String currency;
  final ExpenseCategory category;
  final String description;
  final String? notes;
  final DateTime date;
  final ExpenseSource source;
  final TransactionType type;
  final String? bankName;
  final String? cardLastFour;
  final String? merchantName;
  final String? gmailMessageId;
  final String? receiptPhotoPath;

  const Expense({
    this.id,
    required this.amount,
    this.currency = 'COP',
    required this.category,
    required this.description,
    this.notes,
    required this.date,
    this.source = ExpenseSource.manual,
    this.type = TransactionType.expense,
    this.bankName,
    this.cardLastFour,
    this.merchantName,
    this.gmailMessageId,
    this.receiptPhotoPath,
  });

  bool get isIncome => type == TransactionType.income;

  Expense copyWith({
    int? id,
    double? amount,
    String? currency,
    ExpenseCategory? category,
    String? description,
    String? notes,
    DateTime? date,
    ExpenseSource? source,
    TransactionType? type,
    String? bankName,
    String? cardLastFour,
    String? merchantName,
    String? gmailMessageId,
    String? receiptPhotoPath,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      source: source ?? this.source,
      type: type ?? this.type,
      bankName: bankName ?? this.bankName,
      cardLastFour: cardLastFour ?? this.cardLastFour,
      merchantName: merchantName ?? this.merchantName,
      gmailMessageId: gmailMessageId ?? this.gmailMessageId,
      receiptPhotoPath: receiptPhotoPath ?? this.receiptPhotoPath,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'amount': amount,
        'currency': currency,
        'category': category.name,
        'description': description,
        'notes': notes,
        'date': date.millisecondsSinceEpoch,
        'source': source.name,
        'type': type.name,
        'bank_name': bankName,
        'card_last_four': cardLastFour,
        'merchant_name': merchantName,
        'gmail_message_id': gmailMessageId,
        'receipt_photo_path': receiptPhotoPath,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as int?,
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'COP',
        category: ExpenseCategory.fromKey(map['category'] as String? ?? 'other'),
        description: map['description'] as String? ?? '',
        notes: map['notes'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        source: ExpenseSource.values.firstWhere(
          (s) => s.name == map['source'],
          orElse: () => ExpenseSource.manual,
        ),
        type: TransactionType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => TransactionType.expense,
        ),
        bankName: map['bank_name'] as String?,
        cardLastFour: map['card_last_four'] as String?,
        merchantName: map['merchant_name'] as String?,
        gmailMessageId: map['gmail_message_id'] as String?,
        receiptPhotoPath: map['receipt_photo_path'] as String?,
      );

  String get displayName =>
      merchantName?.isNotEmpty == true ? merchantName! : description;

  @override
  bool operator ==(Object other) =>
      other is Expense && other.id == id && other.gmailMessageId == gmailMessageId;

  @override
  int get hashCode => Object.hash(id, gmailMessageId);
}
