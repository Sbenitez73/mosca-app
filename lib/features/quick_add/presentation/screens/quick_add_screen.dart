import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expenses/data/models/expense_category.dart';
import '../providers/quick_add_provider.dart';
import 'live_activity_service.dart';

class QuickAddScreen extends ConsumerStatefulWidget {
  const QuickAddScreen({super.key});

  @override
  ConsumerState<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends ConsumerState<QuickAddScreen> {
  final _descController = TextEditingController();
  @override
  void initState() {
    super.initState();
    ref.read(quickAddProvider.notifier).reset();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickAddProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Nuevo gasto'),
        actions: [
          if (state.isValid)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: state.isSaving ? null : () => _save(context),
                child: state.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Guardar',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Amount display ───────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      style: TextStyle(
                        fontSize: state.amountBuffer.length > 6 ? 44 : 56,
                        fontWeight: FontWeight.w800,
                        color: state.amountBuffer.isEmpty
                            ? colorScheme.onSurface.withValues(alpha: 0.2)
                            : colorScheme.onSurface,
                        letterSpacing: -1,
                      ),
                      child: Text(
                        state.amountBuffer.isEmpty
                            ? '\$0'
                            : CurrencyFormatter.format(
                                state.parsedAmount ?? 0,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (state.category != null)
                      AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 200),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              state.category!.icon,
                              size: 16,
                              color: state.category!.color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              state.category!.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: state.category!.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        'Selecciona una categoría',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Category picker ──────────────────────────────────────────────
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ExpenseCategory.values.map((cat) {
                final selected = state.category == cat;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(quickAddProvider.notifier).setCategory(cat);
                    _updateLiveActivity(ref);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? cat.color.withValues(alpha: 0.15)
                          : colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? cat.color : AppColors.divider,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(cat.icon, size: 18, color: selected ? cat.color : colorScheme.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(width: 6),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? cat.color : colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Optional description ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _descController,
              onChanged: ref.read(quickAddProvider.notifier).setDescription,
              decoration: const InputDecoration(
                hintText: 'Descripción (opcional)',
                prefixIcon: Icon(Icons.edit_note_rounded),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(height: 8),

          // ── Numpad ────────────────────────────────────────────────────────
          Container(
            color: colorScheme.surface,
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 4,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: _Numpad(
              onDigit: (d) {
                HapticFeedback.lightImpact();
                ref.read(quickAddProvider.notifier).appendDigit(d);
                _updateLiveActivity(ref);
              },
              onDecimal: () => ref.read(quickAddProvider.notifier).appendDecimal(),
              onBackspace: () {
                HapticFeedback.lightImpact();
                ref.read(quickAddProvider.notifier).backspace();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final success = await ref.read(quickAddProvider.notifier).save();
    if (success && mounted) {
      await LiveActivityService.end();
      context.pop();
    }
  }

  void _updateLiveActivity(WidgetRef ref) {
    if (!Platform.isIOS) return;
    final state = ref.read(quickAddProvider);
    LiveActivityService.update(
      amount: state.parsedAmount ?? 0,
      category: state.category?.label ?? '–',
      categoryEmoji: _categoryEmoji(state.category),
    );
  }

  String _categoryEmoji(ExpenseCategory? cat) {
    switch (cat) {
      case ExpenseCategory.food: return '🍔';
      case ExpenseCategory.transport: return '🚗';
      case ExpenseCategory.entertainment: return '🎬';
      case ExpenseCategory.shopping: return '🛍️';
      case ExpenseCategory.health: return '💊';
      case ExpenseCategory.housing: return '🏠';
      case ExpenseCategory.education: return '📚';
      default: return '💸';
    }
  }
}

// ─── Numpad ──────────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;

  const _Numpad({
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(context, ['1', '2', '3']),
        _buildRow(context, ['4', '5', '6']),
        _buildRow(context, ['7', '8', '9']),
        _buildSpecialRow(context),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<String> keys) {
    return Row(
      children: keys.map((k) => Expanded(child: _NumKey(label: k, onTap: () => onDigit(k)))).toList(),
    );
  }

  Widget _buildSpecialRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _NumKey(label: ',', onTap: onDecimal, dimmed: true)),
        Expanded(child: _NumKey(label: '0', onTap: () => onDigit('0'))),
        Expanded(
          child: _NumKey(
            label: '⌫',
            onTap: onBackspace,
            dimmed: true,
            isIcon: true,
          ),
        ),
      ],
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool dimmed;
  final bool isIcon;

  const _NumKey({
    required this.label,
    required this.onTap,
    this.dimmed = false,
    this.isIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: dimmed
              ? theme.colorScheme.onSurface.withValues(alpha: 0.04)
              : theme.colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: isIcon
              ? Icon(Icons.backspace_rounded,
                  size: 22, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: dimmed
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                        : theme.colorScheme.onSurface,
                  ),
                ),
        ),
      ),
    );
  }
}
