import 'package:flutter/material.dart';

abstract class AppColors {
  // Brand
  static const primary = Color(0xFF0A7E4A);
  static const primaryLight = Color(0xFF1DB954);
  static const secondary = Color(0xFFF5A623);
  static const secondaryDark = Color(0xFFD4861A);

  // Backgrounds
  static const backgroundLight = Color(0xFFF4F9F6);
  static const backgroundDark = Color(0xFF0A1A0F);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF122318);
  static const cardDark = Color(0xFF1A3024);

  // Text
  static const textPrimary = Color(0xFF0D1F17);
  static const textSecondary = Color(0xFF4D6B5A);
  static const textDisabled = Color(0xFF9DB8AA);
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const textDarkPrimary = Color(0xFFE8F5EE);
  static const textDarkSecondary = Color(0xFF8FBFA0);

  // Semantic
  static const error = Color(0xFFE53935);
  static const success = Color(0xFF43A047);
  static const warning = Color(0xFFFFA000);

  // Transaction
  static const income = Color(0xFF4CAF50);
  static const expense = Color(0xFFE53935);

  static Color budgetBarColor(double pct) {
    if (pct > 1.0) return const Color(0xFFE53935);
    if (pct > 0.8) return const Color(0xFFFF9800);
    return const Color(0xFF4CAF50);
  }

  // Category colors
  static const catFood = Color(0xFFFF6B35);
  static const catTransport = Color(0xFF2196F3);
  static const catEntertainment = Color(0xFF9C27B0);
  static const catShopping = Color(0xFFE91E63);
  static const catHealth = Color(0xFFF44336);
  static const catHousing = Color(0xFF00897B);
  static const catEducation = Color(0xFF3F51B5);
  static const catOther = Color(0xFF78909C);

  // Divider / Border
  static const divider = Color(0xFFE0EDE6);
  static const dividerDark = Color(0xFF1E3829);
}
