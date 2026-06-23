import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expenses/data/models/expense_category.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../expenses/presentation/widgets/category_picker_sheet.dart';
import '../providers/budgets_provider.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusList = ref.watch(budgetStatusProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Presupuestos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: statusList.isEmpty
          ? _EmptyState(onAdd: () => _openForm(context))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: statusList.length,
              itemBuilder: (context, i) => _BudgetCard(
                status: statusList[i],
                onTap: () => _openForm(context, existing: statusList[i].budget),
              ),
            ),
    );
  }

  void _openForm(BuildContext context, {Budget? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BudgetFormSheet(existing: existing),
    );
  }
}

// ─── Budget card ──────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final BudgetStatus status;
  final VoidCallback onTap;

  const _BudgetCard({required this.status, required this.onTap});

  Color _barColor(double pct) {
    if (pct > 1.0) return const Color(0xFFE53935);
    if (pct > 0.8) return const Color(0xFFFF9800);
    return const Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cat = status.budget.category;
    final pct =
        status.budget.limit > 0 ? status.spent / status.budget.limit : 0.0;
    final color = _barColor(pct);
    final isOver = pct > 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cat.icon, size: 20, color: cat.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.label,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${CurrencyFormatter.format(status.spent)} / ${CurrencyFormatter.format(status.budget.limit)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                  ),
                  if (isOver)
                    Icon(Icons.warning_rounded, color: color, size: 20)
                  else
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
              if (isOver) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Excedido por ${CurrencyFormatter.format(status.spent - status.budget.limit)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.savings_outlined,
                size: 72,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 20),
            Text(
              'Sin presupuestos',
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 8),
            Text(
              'Definí cuánto querés gastar por categoría\ncada mes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar presupuesto'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Budget form sheet ────────────────────────────────────────────────────────

class _BudgetFormSheet extends ConsumerStatefulWidget {
  final Budget? existing;

  const _BudgetFormSheet({this.existing});

  @override
  ConsumerState<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<_BudgetFormSheet> {
  ExpenseCategory? _category;
  late final TextEditingController _amountController;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _category = widget.existing?.category;
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing == null
          ? ''
          : _ThousandsFormatter.format(existing.limit.toInt()),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(
        _amountController.text.replaceAll('.', '').replaceAll(',', ''));
    if (_category == null || amount == null || amount <= 0) return;
    setState(() => _isSaving = true);
    await ref.read(budgetRepositoryProvider).save(
          Budget(id: widget.existing?.id, category: _category!, limit: amount),
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar presupuesto'),
        content: Text('¿Eliminar el presupuesto de ${_category?.label}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(budgetRepositoryProvider).delete(id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                _isEditing ? 'Editar presupuesto' : 'Nuevo presupuesto',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_isEditing)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  onPressed: _delete,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Categoría ────────────────────────────────────────────────────
          Text(
            'Categoría',
            style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          if (_isEditing && _category != null)
            _CategoryDisplay(category: _category!)
          else
            GestureDetector(
              onTap: () async {
                final categories = ref.read(allCategoriesProvider);
                final picked = await showCategoryPicker(
                  context,
                  categories: categories,
                  selected: _category,
                );
                if (picked != null) setState(() => _category = picked);
              },
              child: _category != null
                  ? _CategoryDisplay(category: _category!, showChevron: true)
                  : _CategoryPlaceholder(),
            ),

          const SizedBox(height: 20),

          // ── Límite ───────────────────────────────────────────────────────
          Text(
            'Límite mensual',
            style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [_ThousandsFormatter()],
            autofocus: _isEditing,
            style: theme.textTheme.titleMedium,
            decoration: InputDecoration(
              prefixText: '\$ ',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_category != null && !_isSaving) ? _save : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDisplay extends StatelessWidget {
  final ExpenseCategory category;
  final bool showChevron;

  const _CategoryDisplay({required this.category, this.showChevron = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: category.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(category.icon, size: 22, color: category.color),
          const SizedBox(width: 12),
          Text(
            category.label,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: category.color),
          ),
          if (showChevron) ...[
            const Spacer(),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: category.color.withValues(alpha: 0.6)),
          ],
        ],
      ),
    );
  }
}

class _CategoryPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.grid_view_rounded,
              size: 22, color: cs.onSurface.withValues(alpha: 0.35)),
          const SizedBox(width: 12),
          Text(
            'Seleccionar categoría',
            style: TextStyle(
                fontSize: 15, color: cs.onSurface.withValues(alpha: 0.4)),
          ),
          const Spacer(),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: cs.onSurface.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}

// ─── Thousands formatter ──────────────────────────────────────────────────────

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final n = int.tryParse(digits) ?? 0;
    final formatted = format(n);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String format(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
