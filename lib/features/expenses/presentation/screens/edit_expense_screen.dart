import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/expense.dart';
import '../../data/models/expense_category.dart';
import '../../data/models/expense_source.dart';
import '../providers/expenses_provider.dart';

class EditExpenseScreen extends ConsumerStatefulWidget {
  final Expense expense;

  const EditExpenseScreen({super.key, required this.expense});

  @override
  ConsumerState<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends ConsumerState<EditExpenseScreen> {
  late ExpenseCategory _category;
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _notesController;
  bool _isSaving = false;
  String? _error;

  bool get _isGmail => widget.expense.source == ExpenseSource.gmail;

  @override
  void initState() {
    super.initState();
    _category = widget.expense.category;
    _amountController = TextEditingController(
      text: widget.expense.amount % 1 == 0
          ? widget.expense.amount.toInt().toString()
          : widget.expense.amount.toStringAsFixed(2),
    );
    // Gmail: título = merchantName (display name), descripción = description field
    // Manual: título = description
    _titleController = TextEditingController(
      text: _isGmail
          ? (widget.expense.merchantName ?? widget.expense.description)
          : widget.expense.description,
    );
    _descController = TextEditingController(
      text: _isGmail ? widget.expense.description : '',
    );
    _notesController = TextEditingController(
      text: widget.expense.notes ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: const Text('¿Seguro que quieres eliminar este gasto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && widget.expense.id != null) {
      await ref.read(expenseRepositoryProvider).delete(widget.expense.id!);
      // ignore: use_build_context_synchronously
      if (mounted) context.pop();
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final notes = _notesController.text.trim();

    double? amount;
    if (!_isGmail) {
      amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
      if (amount == null || amount <= 0) {
        setState(() => _error = 'Ingresa un monto válido');
        return;
      }
    }

    final updated = Expense(
      id: widget.expense.id,
      amount: _isGmail ? widget.expense.amount : amount!,
      currency: widget.expense.currency,
      category: _category,
      description: _isGmail
          ? (desc.isEmpty ? widget.expense.description : desc)
          : (title.isEmpty ? _category.label : title),
      merchantName: _isGmail ? (title.isEmpty ? null : title) : widget.expense.merchantName,
      notes: notes.isEmpty ? null : notes,
      date: widget.expense.date,
      source: widget.expense.source,
      bankName: widget.expense.bankName,
      cardLastFour: widget.expense.cardLastFour,
      gmailMessageId: widget.expense.gmailMessageId,
    );

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(expenseRepositoryProvider).save(updated);
      if (mounted) context.pop();
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        title: const Text('Editar gasto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: colorScheme.error,
            onPressed: _isSaving ? null : () => _delete(context),
            tooltip: 'Eliminar',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Monto ────────────────────────────────────────────────────────
          Text(
            'Monto',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.55),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (_isGmail)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      CurrencyFormatter.format(
                        widget.expense.amount,
                        currency: widget.expense.currency,
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            )
          else
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(
                prefixText: '\$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

          const SizedBox(height: 24),

          // ── Categoría ────────────────────────────────────────────────────
          Text(
            'Categoría',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.55),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ref.watch(allCategoriesProvider).map((cat) {
                final selected = _category == cat;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _category = cat);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
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
                        Icon(
                          cat.icon,
                          size: 16,
                          color: selected
                              ? cat.color
                              : colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? cat.color
                                : colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // ── Título ───────────────────────────────────────────────────────
          Text(
            'Título',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.55),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction:
                _isGmail ? TextInputAction.next : TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Ej. Netflix, Almuerzo…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          if (_isGmail) ...[
            const SizedBox(height: 20),
            Text(
              'Descripción',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.55),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Descripción del gasto…',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          const SizedBox(height: 20),

          Text(
            'Nota (opcional)',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.55),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Detalles adicionales…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
