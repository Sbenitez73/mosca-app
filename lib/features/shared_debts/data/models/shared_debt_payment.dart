class SharedDebtPayment {
  final int? id;
  final int debtId;
  final int year;
  final int month;
  final bool paidByOwner;
  final DateTime paidAt;

  const SharedDebtPayment({
    this.id,
    required this.debtId,
    required this.year,
    required this.month,
    required this.paidByOwner,
    required this.paidAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'debt_id': debtId,
        'year': year,
        'month': month,
        'paid_by_owner': paidByOwner ? 1 : 0,
        'paid_at': paidAt.millisecondsSinceEpoch,
      };

  factory SharedDebtPayment.fromMap(Map<String, dynamic> map) =>
      SharedDebtPayment(
        id: map['id'] as int?,
        debtId: map['debt_id'] as int,
        year: map['year'] as int,
        month: map['month'] as int,
        paidByOwner: (map['paid_by_owner'] as int? ?? 0) == 1,
        paidAt: DateTime.fromMillisecondsSinceEpoch(map['paid_at'] as int),
      );
}
