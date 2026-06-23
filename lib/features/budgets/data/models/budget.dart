import '../../../expenses/data/models/expense_category.dart';

class Budget {
  final int? id;
  final ExpenseCategory category;
  final double limit;

  const Budget({this.id, required this.category, required this.limit});

  Map<String, dynamic> toMap() => {
        'category_key': category.key,
        'amount_limit': limit,
      };

  static Budget fromMap(Map<String, dynamic> map) => Budget(
        id: map['id'] as int?,
        category: ExpenseCategory.fromKey(map['category_key'] as String),
        limit: (map['amount_limit'] as num).toDouble(),
      );
}
