import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/date_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expenses/data/models/expense_category.dart';
import '../../../expenses/data/models/transaction_type.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../expenses/presentation/widgets/category_picker_sheet.dart';
import '../providers/recurring_provider.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(recurringExpensesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos Recurrentes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? _EmptyState(onAdd: () => _openForm(context))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final item = list[i];
                  return Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      HapticFeedback.mediumImpact();
                      ref.read(recurringRepositoryProvider).delete(item.id!);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Recurrente eliminado'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                    },
                    child: _RecurringCard(
                      item: item,
                      onTap: () => _openForm(context, existing: item),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _openForm(BuildContext context, {RecurringExpense? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurringFormSheet(existing: existing),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _RecurringCard extends StatelessWidget {
  final RecurringExpense item;
  final VoidCallback onTap;

  const _RecurringCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cat = item.category;
    final typeColor = item.type == TransactionType.income
        ? const Color(0xFF4CAF50)
        : const Color(0xFFE53935);
    final typeLabel = item.type == TransactionType.income ? 'Ingreso' : 'Gasto';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, size: 22, color: cat.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Cada mes el día ${item.dayOfMonth}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                    Text(
                      item.lastGeneratedAt != null
                          ? 'Último: ${DateFormatter.relative(item.lastGeneratedAt!)}'
                          : 'Nunca registrado',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.35),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(item.amount),
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700, color: typeColor),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(typeLabel,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: typeColor)),
                  ),
                ],
              ),
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
            Icon(Icons.repeat_rounded,
                size: 72,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 20),
            Text('Sin gastos recurrentes',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Text(
              'Configurá gastos que se registran\nautomáticamente cada mes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar recurrente'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Form sheet ───────────────────────────────────────────────────────────────

class _RecurringFormSheet extends ConsumerStatefulWidget {
  final RecurringExpense? existing;
  const _RecurringFormSheet({this.existing});

  @override
  ConsumerState<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<_RecurringFormSheet> {
  ExpenseCategory? _category;
  TransactionType _type = TransactionType.expense;
  late final TextEditingController _amountController;
  late final TextEditingController _descController;
  int _day = 1;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category;
    _type = e?.type ?? TransactionType.expense;
    _day = e?.dayOfMonth ?? 1;
    _amountController = TextEditingController(
      text: e == null ? '' : _ThousandsFormatter.format(e.amount.toInt()),
    );
    _descController = TextEditingController(text: e?.description ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(
        _amountController.text.replaceAll('.', '').replaceAll(',', ''));
    final desc = _descController.text.trim();
    if (_category == null || amount == null || amount <= 0 || desc.isEmpty) return;
    setState(() => _isSaving = true);
    await ref.read(recurringRepositoryProvider).save(RecurringExpense(
          id: widget.existing?.id,
          amount: amount,
          category: _category!,
          description: desc,
          dayOfMonth: _day,
          type: _type,
          lastGeneratedAt: widget.existing?.lastGeneratedAt,
        ));
    if (mounted) Navigator.pop(context);
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
      child: SingleChildScrollView(
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
            Text(
              _isEditing ? 'Editar recurrente' : 'Nuevo recurrente',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // ── Tipo ──────────────────────────────────────────────────────
            Text('Tipo',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final t in [TransactionType.expense, TransactionType.income])
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _type = t;
                          _category = null;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == t
                              ? (t == TransactionType.expense
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFF4CAF50))
                                  .withValues(alpha: 0.12)
                              : cs.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _type == t
                                ? (t == TransactionType.expense
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF4CAF50))
                                : Colors.transparent,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            t == TransactionType.expense ? 'Gasto' : 'Ingreso',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _type == t
                                  ? (t == TransactionType.expense
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFF4CAF50))
                                  : cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Categoría ─────────────────────────────────────────────────
            Text('Categoría',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final categories = _type == TransactionType.income
                    ? ExpenseCategory.incomeBuiltins
                    : ref.read(allCategoriesProvider);
                final picked = await showCategoryPicker(
                  context,
                  categories: categories,
                  selected: _category,
                );
                if (picked != null) setState(() => _category = picked);
              },
              child: _category != null
                  ? _CategoryChip(category: _category!, showChevron: true)
                  : _CategoryPlaceholder(),
            ),
            const SizedBox(height: 20),

            // ── Monto ─────────────────────────────────────────────────────
            Text('Monto',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [_ThousandsFormatter()],
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(
                prefixText: '\$ ',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // ── Descripción ───────────────────────────────────────────────
            Text('Descripción',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                hintText: 'Ej: Arriendo, Netflix, Gym…',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // ── Día del mes ───────────────────────────────────────────────
            Text('Día del mes',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 28,
                itemBuilder: (context, i) {
                  final day = i + 1;
                  final selected = _day == day;
                  return GestureDetector(
                    onTap: () => setState(() => _day = day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final ExpenseCategory category;
  final bool showChevron;

  const _CategoryChip({required this.category, this.showChevron = false});

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
          Text(category.label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: category.color)),
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
          Text('Seleccionar categoría',
              style: TextStyle(
                  fontSize: 15, color: cs.onSurface.withValues(alpha: 0.4))),
          const Spacer(),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: cs.onSurface.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}

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
