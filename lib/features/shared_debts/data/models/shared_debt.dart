class SharedDebt {
  final int? id;
  final String label;
  final String ownerName;
  final double amount;
  final String currency;
  final int dueDayOfMonth;
  final bool isActive;

  const SharedDebt({
    this.id,
    required this.label,
    required this.ownerName,
    required this.amount,
    this.currency = 'COP',
    required this.dueDayOfMonth,
    this.isActive = true,
  });

  SharedDebt copyWith({
    int? id,
    String? label,
    String? ownerName,
    double? amount,
    String? currency,
    int? dueDayOfMonth,
    bool? isActive,
  }) =>
      SharedDebt(
        id: id ?? this.id,
        label: label ?? this.label,
        ownerName: ownerName ?? this.ownerName,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        dueDayOfMonth: dueDayOfMonth ?? this.dueDayOfMonth,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'label': label,
        'owner_name': ownerName,
        'amount': amount,
        'currency': currency,
        'due_day_of_month': dueDayOfMonth,
        'is_active': isActive ? 1 : 0,
      };

  factory SharedDebt.fromMap(Map<String, dynamic> map) => SharedDebt(
        id: map['id'] as int?,
        label: map['label'] as String,
        ownerName: map['owner_name'] as String,
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'COP',
        dueDayOfMonth: map['due_day_of_month'] as int? ?? 1,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );
}
