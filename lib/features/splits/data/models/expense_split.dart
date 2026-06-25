class ExpenseSplit {
  final int? id;
  final int expenseId;
  final String name;
  final String? phone;
  final double amount;
  final bool settled;

  const ExpenseSplit({
    this.id,
    required this.expenseId,
    required this.name,
    this.phone,
    required this.amount,
    this.settled = false,
  });

  ExpenseSplit copyWith({
    int? id,
    int? expenseId,
    String? name,
    String? phone,
    double? amount,
    bool? settled,
  }) =>
      ExpenseSplit(
        id: id ?? this.id,
        expenseId: expenseId ?? this.expenseId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        amount: amount ?? this.amount,
        settled: settled ?? this.settled,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'expense_id': expenseId,
        'name': name,
        'phone': phone,
        'amount': amount,
        'settled': settled ? 1 : 0,
      };

  factory ExpenseSplit.fromMap(Map<String, dynamic> map) => ExpenseSplit(
        id: map['id'] as int?,
        expenseId: map['expense_id'] as int,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        amount: (map['amount'] as num).toDouble(),
        settled: (map['settled'] as int? ?? 0) == 1,
      );
}
