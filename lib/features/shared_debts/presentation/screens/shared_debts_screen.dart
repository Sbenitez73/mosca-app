import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/models/shared_debt.dart';
import '../../data/models/shared_debt_payment.dart';
import '../providers/shared_debts_provider.dart';

class SharedDebtsScreen extends ConsumerStatefulWidget {
  const SharedDebtsScreen({super.key});

  @override
  ConsumerState<SharedDebtsScreen> createState() => _SharedDebtsScreenState();
}

class _SharedDebtsScreenState extends ConsumerState<SharedDebtsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _prev() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _next() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ym = (_month.year, _month.month);

    final debtsAsync    = ref.watch(activeSharedDebtsProvider);
    final paymentsAsync = ref.watch(sharedDebtPaymentsProvider(ym));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: _prev,
            ),
            Text(
              DateFormatter.monthName(_month),
              style: theme.textTheme.titleLarge,
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                color: _isCurrentMonth
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                    : null,
              ),
              onPressed: _isCurrentMonth ? null : _next,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _showAddDebtSheet(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva'),
            ),
          ),
        ],
      ),
      body: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (debts) {
          if (debts.isEmpty) {
            return _EmptyState(onAdd: () => _showAddDebtSheet(context));
          }

          return paymentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (payments) {
              final paymentByDebt = {
                for (final p in payments) p.debtId: p,
              };

              final totalOwed = debts.fold<double>(0, (s, d) => s + d.amount);
              final paidByOwner = debts
                  .where((d) => paymentByDebt[d.id]?.paidByOwner == true)
                  .fold<double>(0, (s, d) => s + d.amount);
              final paidByMe = debts
                  .where((d) => paymentByDebt[d.id]?.paidByOwner == false)
                  .fold<double>(0, (s, d) => s + d.amount);
              final pending = totalOwed - paidByOwner - paidByMe;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _SummaryRow(
                    pending: pending,
                    paidByOwner: paidByOwner,
                    paidByMe: paidByMe,
                  ),
                  const SizedBox(height: 20),
                  ...debts.map(
                    (debt) => _DebtCard(
                      debt: debt,
                      payment: paymentByDebt[debt.id],
                      month: _month,
                      onMarkPayment: (paidByOwner) =>
                          _markPayment(debt, paidByOwner),
                      onClearPayment: () =>
                          _clearPayment(debt),
                      onEdit: () => _showEditDebtSheet(context, debt),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markPayment(SharedDebt debt, bool paidByOwner) async {
    final repo = ref.read(sharedDebtRepositoryProvider);
    final payment = SharedDebtPayment(
      debtId: debt.id!,
      year: _month.year,
      month: _month.month,
      paidByOwner: paidByOwner,
      paidAt: DateTime.now(),
    );
    await repo.upsertPayment(payment);
    HapticFeedback.lightImpact();
  }

  Future<void> _clearPayment(SharedDebt debt) async {
    await ref
        .read(sharedDebtRepositoryProvider)
        .deletePayment(debt.id!, _month.year, _month.month);
    HapticFeedback.lightImpact();
  }

  Future<void> _showAddDebtSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DebtFormSheet(
        onSave: (debt) async {
          await ref.read(sharedDebtRepositoryProvider).saveDebt(debt);
          HapticFeedback.lightImpact();
        },
      ),
    );
  }

  Future<void> _showEditDebtSheet(
      BuildContext context, SharedDebt debt) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DebtFormSheet(
        existing: debt,
        onSave: (updated) async {
          await ref.read(sharedDebtRepositoryProvider).saveDebt(updated);
          HapticFeedback.lightImpact();
        },
        onDeactivate: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Archivar deuda'),
              content: Text(
                  '¿Archivar "${debt.label}"? Puedes seguir viendo el historial.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Archivar')),
              ],
            ),
          );
          if (confirmed == true) {
            await ref
                .read(sharedDebtRepositoryProvider)
                .deactivateDebt(debt.id!);
            HapticFeedback.mediumImpact();
          }
        },
      ),
    );
  }
}

// ─── Summary row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final double pending;
  final double paidByOwner;
  final double paidByMe;

  const _SummaryRow({
    required this.pending,
    required this.paidByOwner,
    required this.paidByMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            _Cell(
              label: 'Pendiente',
              value: pending,
              color: const Color(0xFFFF9800),
            ),
            Container(width: 1, height: 40, color: theme.dividerColor),
            _Cell(
              label: 'Pagaron ellos',
              value: paidByOwner,
              color: const Color(0xFF4CAF50),
            ),
            Container(width: 1, height: 40, color: theme.dividerColor),
            _Cell(
              label: 'Pagué yo',
              value: paidByMe,
              color: const Color(0xFFE53935),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _Cell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.format(value),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Debt card ────────────────────────────────────────────────────────────────

class _DebtCard extends StatelessWidget {
  final SharedDebt debt;
  final SharedDebtPayment? payment;
  final DateTime month;
  final void Function(bool paidByOwner) onMarkPayment;
  final VoidCallback onClearPayment;
  final VoidCallback onEdit;

  const _DebtCard({
    required this.debt,
    required this.payment,
    required this.month,
    required this.onMarkPayment,
    required this.onClearPayment,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isPaid = payment != null;
    final paidByOwner = payment?.paidByOwner ?? false;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (!isPaid) {
      statusColor = const Color(0xFFFF9800);
      statusLabel = 'Pendiente';
      statusIcon = Icons.schedule_rounded;
    } else if (paidByOwner) {
      statusColor = const Color(0xFF4CAF50);
      statusLabel = 'Pagó ${debt.ownerName}';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = const Color(0xFFE53935);
      statusLabel = 'Pagué yo';
      statusIcon = Icons.account_balance_wallet_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.label,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${debt.ownerName} · vence día ${debt.dueDayOfMonth}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(debt.amount),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: cs.onSurface.withValues(alpha: 0.4),
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isPaid)
                  TextButton(
                    onPressed: onClearPayment,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Desmarcar',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      _ActionChip(
                        label: 'Pagó ${debt.ownerName}',
                        color: const Color(0xFF4CAF50),
                        onTap: () => onMarkPayment(true),
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        label: 'Pagué yo',
                        color: const Color(0xFFE53935),
                        onTap: () => onMarkPayment(false),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      );
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
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.handshake_outlined,
              size: 72,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin deudas compartidas',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registrá deudas que están a tu nombre\npero le corresponden a otra persona.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar deuda'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Debt form sheet ──────────────────────────────────────────────────────────

class _DebtFormSheet extends StatefulWidget {
  final SharedDebt? existing;
  final Future<void> Function(SharedDebt) onSave;
  final VoidCallback? onDeactivate;

  const _DebtFormSheet({
    this.existing,
    required this.onSave,
    this.onDeactivate,
  });

  @override
  State<_DebtFormSheet> createState() => _DebtFormSheetState();
}

final _thousandsFmt = NumberFormat('#,##0', 'es_CO');

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final formatted = _thousandsFmt.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _DebtFormSheetState extends State<_DebtFormSheet> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _amountCtrl;
  late int _dueDay;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl  = TextEditingController(text: e?.label ?? '');
    _ownerCtrl  = TextEditingController(text: e?.ownerName ?? '');
    _amountCtrl = TextEditingController(
      text: e == null ? '' : _thousandsFmt.format(e.amount.toInt()),
    );
    _dueDay = e?.dueDayOfMonth ?? 1;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _ownerCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label  = _labelCtrl.text.trim();
    final owner  = _ownerCtrl.text.trim();
    final amount = double.tryParse(
      _amountCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
    );

    if (label.isEmpty) {
      setState(() => _error = 'Escribe un nombre para la deuda');
      return;
    }
    if (owner.isEmpty) {
      setState(() => _error = 'Escribe el nombre de quien debe');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingresa un monto válido');
      return;
    }

    setState(() {
      _saving = true;
      _error  = null;
    });

    final debt = SharedDebt(
      id: widget.existing?.id,
      label: label,
      ownerName: owner,
      amount: amount,
      dueDayOfMonth: _dueDay,
    );

    await widget.onSave(debt);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.existing != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEdit ? 'Editar deuda' : 'Nueva deuda compartida',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            // Label
            TextField(
              controller: _labelCtrl,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Netflix, Celular mamá…',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Owner
            TextField(
              controller: _ownerCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '¿A nombre de quién está?',
                hintText: 'Ej. Mamá, Tío Carlos…',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [_ThousandsFormatter()],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Monto mensual',
                prefixText: '\$ ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Due day
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Día de vencimiento',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                DropdownButton<int>(
                  value: _dueDay,
                  items: List.generate(
                    28,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('Día ${i + 1}'),
                    ),
                  ),
                  onChanged: (v) {
                    if (v != null) setState(() => _dueDay = v);
                  },
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                    color: theme.colorScheme.error, fontSize: 13),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEdit ? 'Guardar cambios' : 'Agregar'),
              ),
            ),

            if (isEdit && widget.onDeactivate != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDeactivate!();
                  },
                  child: Text(
                    'Archivar deuda',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
