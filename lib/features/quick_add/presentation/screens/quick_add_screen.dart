import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expenses/presentation/widgets/category_picker_sheet.dart';
import '../../../expenses/data/models/expense_category.dart';
import '../../../expenses/data/models/transaction_type.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../providers/quick_add_provider.dart';
import 'live_activity_service.dart';

class QuickAddScreen extends ConsumerStatefulWidget {
  const QuickAddScreen({super.key});

  @override
  ConsumerState<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends ConsumerState<QuickAddScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quickAddProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickAddProvider);
    final allCategories = ref.watch(allCategoriesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (state.isValid)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => context.push('/quick-add/detail'),
                child: Text(
                  'Siguiente',
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          color: state.amountBuffer.isEmpty
                              ? colorScheme.onSurface.withValues(alpha: 0.2)
                              : colorScheme.onSurface,
                          letterSpacing: -1,
                        ),
                        child: Text(
                          state.amountBuffer.isEmpty
                              ? '\$0'
                              : CurrencyFormatter.format(state.parsedAmount ?? 0),
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
                            Icon(state.category!.icon, size: 16, color: state.category!.color),
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

          // ── Type tabs ────────────────────────────────────────────────────
          _TypeTabs(
            selected: state.type,
            onChanged: (t) => ref.read(quickAddProvider.notifier).setType(t),
          ),

          const SizedBox(height: 12),

          // ── Category picker ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: state.type == TransactionType.transfer
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, size: 20, color: Color(0xFF2196F3)),
                        const SizedBox(width: 10),
                        Text(
                          'No cuenta como gasto ni ingreso',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF2196F3).withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: () => _pickCategory(context, ref, state, allCategories),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: state.category != null
                            ? state.category!.color.withValues(alpha: 0.1)
                            : colorScheme.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: state.category != null
                              ? state.category!.color.withValues(alpha: 0.4)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (state.category != null) ...[
                            Icon(state.category!.icon, size: 20, color: state.category!.color),
                            const SizedBox(width: 10),
                            Text(
                              state.category!.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: state.category!.color,
                              ),
                            ),
                          ] else ...[
                            Icon(Icons.grid_view_rounded,
                                size: 20, color: colorScheme.onSurface.withValues(alpha: 0.35)),
                            const SizedBox(width: 10),
                            Text(
                              'Seleccionar categoría',
                              style: TextStyle(
                                fontSize: 15,
                                color: colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              color: colorScheme.onSurface.withValues(alpha: 0.35)),
                        ],
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 4),

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

  Future<void> _pickCategory(BuildContext context, WidgetRef ref, QuickAddState state, List<ExpenseCategory> expenseCategories) async {
    HapticFeedback.selectionClick();
    final categories = state.type == TransactionType.income
        ? ExpenseCategory.incomeBuiltins
        : expenseCategories;
    final picked = await showCategoryPicker(
      context,
      categories: categories,
      selected: state.category,
    );
    if (picked != null) {
      ref.read(quickAddProvider.notifier).setCategory(picked);
      _updateLiveActivity(ref);
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

// ─── Type tabs ───────────────────────────────────────────────────────────────

class _TypeTabs extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TypeTabs({required this.selected, required this.onChanged});

  static Color _color(TransactionType t, ColorScheme cs) => switch (t) {
    TransactionType.expense  => cs.error,
    TransactionType.income   => const Color(0xFF4CAF50),
    TransactionType.transfer => const Color(0xFF2196F3),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: TransactionType.values.map((type) {
        final active = type == selected;
        final color = _color(type, cs);
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(type);
            },
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? color : cs.onSurface.withValues(alpha: 0.35),
                    ),
                    child: Text(type.label, textAlign: TextAlign.center),
                  ),
                ),
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    height: 2.5,
                    width: active ? 28.0 : 0.0,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
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
        Expanded(child: _NumKey(label: '⌫', onTap: onBackspace, dimmed: true, isIcon: true)),
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
