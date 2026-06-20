import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum ExpenseCategory {
  food,
  transport,
  entertainment,
  shopping,
  health,
  housing,
  education,
  other;

  String get label {
    switch (this) {
      case ExpenseCategory.food:
        return 'Comida';
      case ExpenseCategory.transport:
        return 'Transporte';
      case ExpenseCategory.entertainment:
        return 'Entretenimiento';
      case ExpenseCategory.shopping:
        return 'Compras';
      case ExpenseCategory.health:
        return 'Salud';
      case ExpenseCategory.housing:
        return 'Vivienda';
      case ExpenseCategory.education:
        return 'Educación';
      case ExpenseCategory.other:
        return 'Otro';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.transport:
        return Icons.directions_car_rounded;
      case ExpenseCategory.entertainment:
        return Icons.movie_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.health:
        return Icons.medical_services_rounded;
      case ExpenseCategory.housing:
        return Icons.home_rounded;
      case ExpenseCategory.education:
        return Icons.school_rounded;
      case ExpenseCategory.other:
        return Icons.category_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.food:
        return AppColors.catFood;
      case ExpenseCategory.transport:
        return AppColors.catTransport;
      case ExpenseCategory.entertainment:
        return AppColors.catEntertainment;
      case ExpenseCategory.shopping:
        return AppColors.catShopping;
      case ExpenseCategory.health:
        return AppColors.catHealth;
      case ExpenseCategory.housing:
        return AppColors.catHousing;
      case ExpenseCategory.education:
        return AppColors.catEducation;
      case ExpenseCategory.other:
        return AppColors.catOther;
    }
  }
}
