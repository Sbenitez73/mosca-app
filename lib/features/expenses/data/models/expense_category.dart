import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ExpenseCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final bool isCustom;

  final bool isIncome;

  const ExpenseCategory._({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    this.isCustom = false,
    this.isIncome = false,
  });

  // ─── Built-ins ───────────────────────────────────────────────────────────────

  static const food = ExpenseCategory._(
    key: 'food', label: 'Comida',
    icon: Icons.restaurant_rounded, color: AppColors.catFood,
  );
  static const transport = ExpenseCategory._(
    key: 'transport', label: 'Transporte',
    icon: Icons.directions_car_rounded, color: AppColors.catTransport,
  );
  static const entertainment = ExpenseCategory._(
    key: 'entertainment', label: 'Entretenimiento',
    icon: Icons.movie_rounded, color: AppColors.catEntertainment,
  );
  static const shopping = ExpenseCategory._(
    key: 'shopping', label: 'Compras',
    icon: Icons.shopping_bag_rounded, color: AppColors.catShopping,
  );
  static const health = ExpenseCategory._(
    key: 'health', label: 'Salud',
    icon: Icons.medical_services_rounded, color: AppColors.catHealth,
  );
  static const housing = ExpenseCategory._(
    key: 'housing', label: 'Vivienda',
    icon: Icons.home_rounded, color: AppColors.catHousing,
  );
  static const education = ExpenseCategory._(
    key: 'education', label: 'Educación',
    icon: Icons.school_rounded, color: AppColors.catEducation,
  );
  static const other = ExpenseCategory._(
    key: 'other', label: 'Otro',
    icon: Icons.category_rounded, color: AppColors.catOther,
  );

  // ─── Income built-ins ────────────────────────────────────────────────────────

  static const salary = ExpenseCategory._(
    key: 'income_salary', label: 'Salario',
    icon: Icons.work_rounded, color: Color(0xFF4CAF50), isIncome: true,
  );
  static const freelance = ExpenseCategory._(
    key: 'income_freelance', label: 'Freelance',
    icon: Icons.laptop_rounded, color: Color(0xFF2196F3), isIncome: true,
  );
  static const investment = ExpenseCategory._(
    key: 'income_investment', label: 'Inversión',
    icon: Icons.trending_up_rounded, color: Color(0xFF9C27B0), isIncome: true,
  );
  static const gift = ExpenseCategory._(
    key: 'income_gift', label: 'Regalo',
    icon: Icons.card_giftcard_rounded, color: Color(0xFFFF9800), isIncome: true,
  );
  static const incomeOther = ExpenseCategory._(
    key: 'income_other', label: 'Otro',
    icon: Icons.attach_money_rounded, color: Color(0xFF78909C), isIncome: true,
  );

  static const incomeBuiltins = <ExpenseCategory>[
    salary, freelance, investment, gift, incomeOther,
  ];

  static const builtins = <ExpenseCategory>[
    food, transport, entertainment, shopping, health, housing, education, other,
    salary, freelance, investment, gift, incomeOther,
  ];

  // ─── Registry ────────────────────────────────────────────────────────────────

  static final _registry = <String, ExpenseCategory>{
    for (final c in builtins) c.key: c,
  };

  static void registerCustom(List<ExpenseCategory> customs) {
    for (final c in customs) {
      _registry[c.key] = c;
    }
  }

  static void unregister(String key) => _registry.remove(key);

  static ExpenseCategory fromKey(String key) => _registry[key] ?? other;

  static List<ExpenseCategory> get all => [
        ...builtins,
        ..._registry.values.where((c) => c.isCustom),
      ];

  static List<ExpenseCategory> get expenseCategories => [
        ...builtins.where((c) => !c.isIncome),
        ..._registry.values.where((c) => c.isCustom && !c.isIncome),
      ];

  static List<ExpenseCategory> get incomeCategories => [
        ...incomeBuiltins,
        ..._registry.values.where((c) => c.isCustom && c.isIncome),
      ];

  // ─── Custom factory ──────────────────────────────────────────────────────────

  factory ExpenseCategory.custom({
    required String key,
    required String label,
    required Color color,
    bool isIncome = false,
    IconData? icon,
  }) =>
      ExpenseCategory._(
        key: key,
        label: label,
        icon: icon ?? (isIncome ? Icons.attach_money_rounded : Icons.label_rounded),
        color: color,
        isCustom: true,
        isIncome: isIncome,
      );

  // ─── Compat ──────────────────────────────────────────────────────────────────

  // Preserves the enum `.name` API used in toMap / stats
  String get name => key;

  @override
  bool operator ==(Object other) =>
      other is ExpenseCategory && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
