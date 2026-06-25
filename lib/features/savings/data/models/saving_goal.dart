import 'package:flutter/material.dart';

class SavingGoalPreset {
  final IconData icon;
  final Color color;
  final String label;
  const SavingGoalPreset(this.icon, this.color, this.label);
}

class SavingGoal {
  final int? id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final String currency;
  final int presetIndex;

  const SavingGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    this.currency = 'COP',
    this.presetIndex = 7,
  });

  double get progress =>
      targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  double get remaining =>
      (targetAmount - savedAmount).clamp(0.0, double.infinity);
  bool get isCompleted => savedAmount >= targetAmount;

  SavingGoalPreset get preset =>
      presets[presetIndex.clamp(0, presets.length - 1)];
  IconData get icon => preset.icon;
  Color get color => preset.color;

  static const presets = [
    SavingGoalPreset(Icons.home_rounded, Color(0xFF1976D2), 'Casa'),
    SavingGoalPreset(Icons.directions_car_rounded, Color(0xFF388E3C), 'Auto'),
    SavingGoalPreset(Icons.flight_rounded, Color(0xFF7B1FA2), 'Viaje'),
    SavingGoalPreset(Icons.school_rounded, Color(0xFF0288D1), 'Educación'),
    SavingGoalPreset(Icons.phone_iphone_rounded, Color(0xFF455A64), 'Tecnología'),
    SavingGoalPreset(Icons.health_and_safety_rounded, Color(0xFFD32F2F), 'Emergencia'),
    SavingGoalPreset(Icons.card_giftcard_rounded, Color(0xFFE91E63), 'Regalo'),
    SavingGoalPreset(Icons.savings_rounded, Color(0xFF00897B), 'Ahorro'),
  ];

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'currency': currency,
        'preset_index': presetIndex,
      };

  factory SavingGoal.fromMap(Map<String, dynamic> map) => SavingGoal(
        id: map['id'] as int?,
        name: map['name'] as String,
        targetAmount: (map['target_amount'] as num).toDouble(),
        savedAmount: (map['saved_amount'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'COP',
        presetIndex: map['preset_index'] as int? ?? 7,
      );

  SavingGoal copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? savedAmount,
    String? currency,
    int? presetIndex,
  }) =>
      SavingGoal(
        id: id ?? this.id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        savedAmount: savedAmount ?? this.savedAmount,
        currency: currency ?? this.currency,
        presetIndex: presetIndex ?? this.presetIndex,
      );
}
