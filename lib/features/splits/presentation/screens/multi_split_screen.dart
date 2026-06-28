import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/thousands_formatter.dart';
import '../../../expenses/data/models/expense.dart';
import '../../data/models/expense_split.dart';
import '../../data/models/payment_method.dart';
import '../providers/splits_provider.dart';
import '../utils/reimbursement_helper.dart';
import '../utils/whatsapp_sender.dart';

// ─── Local participant model ──────────────────────────────────────────────────

class _Participant {
  String name;
  String? phone;
  double amount;

  _Participant({required this.name, this.phone, required this.amount});

  _Participant copyWith({String? name, String? phone, double? amount}) =>
      _Participant(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        amount: amount ?? this.amount,
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MultiSplitScreen extends ConsumerStatefulWidget {
  final List<Expense> expenses;
  const MultiSplitScreen({super.key, required this.expenses});

  @override
  ConsumerState<MultiSplitScreen> createState() => _MultiSplitScreenState();
}

class _MultiSplitScreenState extends ConsumerState<MultiSplitScreen> {
  final List<_Participant> _participants = [];
  final Map<int, GlobalKey> _participantKeys = {};
  final GlobalKey _sendAllKey = GlobalKey();

  GlobalKey _keyFor(int index) =>
      _participantKeys.putIfAbsent(index, () => GlobalKey());

  double get _total => widget.expenses.fold(0.0, (s, e) => s + e.amount);
  double get _assigned => _participants.fold(0.0, (s, p) => s + p.amount);
  bool get _isOver => _assigned > _total + 0.5;
  bool get _isBalanced => (_total - _assigned).abs() < 1;

  List<String> get _photoPaths => widget.expenses
      .map((e) => e.receiptPhotoPath)
      .where((p) => p != null && p.isNotEmpty && File(p).existsSync())
      .cast<String>()
      .toList();

  // ── Message builder ──────────────────────────────────────────────────────────

  String _buildMessage(_Participant p, List<PaymentMethod> methods) {
    final buf = StringBuffer();
    buf.writeln('Hola, ${p.name}. Acá está el resumen de lo que me quedás debiendo:');
    buf.writeln();
    for (final e in widget.expenses) {
      final name = e.displayName.isNotEmpty ? e.displayName : e.description;
      buf.writeln('• $name: ${CurrencyFormatter.format(e.amount, currency: e.currency)}');
    }
    buf.writeln();
    buf.writeln('Tu parte total: ${CurrencyFormatter.format(p.amount)}');
    if (methods.isNotEmpty) {
      buf.writeln();
      buf.writeln('Podés pagarme por:');
      for (final m in methods) {
        buf.writeln('• ${m.label}: ${m.value}');
      }
    }
    return buf.toString().trim();
  }

  // ── Send + save ──────────────────────────────────────────────────────────────

  Future<void> _sendToParticipant(
      _Participant p, List<PaymentMethod> methods,
      {Rect? sharePositionOrigin}) async {
    try {
      await sendViaWhatsApp(
        text: _buildMessage(p, methods),
        phone: p.phone,
        photoPaths: _photoPaths,
        sharePositionOrigin: sharePositionOrigin,
      );
      if (!mounted) return;
      final paid = await maybeRegisterReimbursement(
        context, ref,
        personName: p.name,
        amount: p.amount,
      );
      await _persistSplitsFor(p, settled: paid);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e')),
        );
      }
    }
  }

  // Creates one split per expense for this participant, amount proportional to
  // each expense's fraction of the total. Marked settled immediately since the
  // message is sent right now.
  Future<List<int>> _persistSplitsFor(_Participant p,
      {required bool settled}) async {
    final repo = ref.read(splitRepositoryProvider);
    final ids = <int>[];
    for (final expense in widget.expenses) {
      if (expense.id == null) continue;
      final fraction = _total > 0
          ? expense.amount / _total
          : 1.0 / widget.expenses.length;
      final amount =
          double.parse((p.amount * fraction).toStringAsFixed(0));
      if (amount <= 0) continue;
      final id = await repo.save(ExpenseSplit(
        expenseId: expense.id!,
        name: p.name,
        phone: (p.phone?.isEmpty ?? true) ? null : p.phone,
        amount: amount,
        settled: settled,
      ));
      if (id != null) ids.add(id);
    }
    return ids;
  }

  // ── Quick split ──────────────────────────────────────────────────────────────

  // n = tamaño total del grupo (incluido yo). Se crean n-1 entradas: solo los
  // otros. Mi parte queda implícita como total - suma de splits.
  void _quickSplit(int n) {
    final others = n - 1;
    final share = (_total / n).roundToDouble();
    setState(() {
      if (_participants.length == others) {
        for (var i = 0; i < others; i++) {
          _participants[i] = _participants[i].copyWith(amount: share);
        }
      } else {
        _participants
          ..clear()
          ..addAll(List.generate(
            others,
            (i) => _Participant(name: 'Persona ${i + 1}', amount: share),
          ));
      }
    });
    HapticFeedback.lightImpact();
  }

  // ── Participant sheet ────────────────────────────────────────────────────────

  void _showParticipantSheet([int? editIndex]) {
    final existing = editIndex != null ? _participants[editIndex] : null;
    final available =
        _total - _assigned + (existing?.amount ?? 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MultiParticipantSheet(
        existing: existing,
        maxAmount: available,
        onSave: (p) => setState(() {
          if (editIndex == null) {
            _participants.add(p);
          } else {
            _participants[editIndex] = p;
          }
        }),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final methods = ref.watch(paymentMethodsProvider).valueOrNull ?? [];
    final hasPhones = _participants.any((p) => p.phone?.isNotEmpty == true);

    return Scaffold(
      appBar: AppBar(title: const Text('Dividir gastos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // ── Expense summary ─────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.expenses.map((e) {
                    final name = e.displayName.isNotEmpty
                        ? e.displayName
                        : e.description;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: theme.textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(
                            CurrencyFormatter.format(e.amount,
                                currency: e.currency),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        CurrencyFormatter.format(_total),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  if (_photoPaths.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.photo_library_rounded,
                            size: 14,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${_photoPaths.length} factura(s) adjunta(s) — se enviarán con el mensaje',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text('Participantes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),

          // ── Quick split ─────────────────────────────────────────────────
          FilledButton.tonal(
            onPressed: () => _quickSplit(2),
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call_split_rounded, size: 18),
                SizedBox(width: 8),
                Text('Dividir entre 2 — cobrar la mitad',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Dividir entre:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    )),
                const SizedBox(width: 8),
                for (final n in [3, 4, 5, 6])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text('$n personas',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () => _quickSplit(n),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
              ],
            ),
          ),

          // ── Validation bar ──────────────────────────────────────────────
          if (_participants.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isOver
                    ? theme.colorScheme.error.withValues(alpha: 0.08)
                    : _isBalanced
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _isOver
                        ? Icons.warning_amber_rounded
                        : _isBalanced
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                    size: 16,
                    color: _isOver
                        ? theme.colorScheme.error
                        : _isBalanced
                            ? const Color(0xFF4CAF50)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isOver
                          ? 'Excede el total por ${CurrencyFormatter.format(_assigned - _total)}'
                          : _isBalanced
                              ? 'Cobrás el total — tu parte es \$0'
                              : 'A cobrar ${CurrencyFormatter.format(_assigned)} · '
                                  'Tu parte ${CurrencyFormatter.format(_total - _assigned)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _isOver
                            ? theme.colorScheme.error
                            : _isBalanced
                                ? const Color(0xFF4CAF50)
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ── Participant tiles ───────────────────────────────────────────
          ..._participants.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final btnKey = _keyFor(i);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                      child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          if (p.phone?.isNotEmpty == true)
                            Text(p.phone!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                )),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(p.amount),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.tonal(
                      key: btnKey,
                      onPressed: () {
                        final box = btnKey.currentContext
                            ?.findRenderObject() as RenderBox?;
                        final origin = box == null
                            ? null
                            : box.localToGlobal(Offset.zero) & box.size;
                        _sendToParticipant(p, methods,
                            sharePositionOrigin: origin);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        foregroundColor: theme.colorScheme.primary,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.send_rounded, size: 14),
                          SizedBox(width: 4),
                          Text('Cobrar', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4)),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'edit', child: Text('Editar')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Eliminar')),
                      ],
                      onSelected: (v) {
                        if (v == 'edit') _showParticipantSheet(i);
                        if (v == 'delete') {
                          setState(() => _participants.removeAt(i));
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showParticipantSheet(),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Agregar persona'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44)),
          ),

          // ── Send all ────────────────────────────────────────────────────
          if (hasPhones) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: _sendAllKey,
              onPressed: () async {
                final box = _sendAllKey.currentContext
                    ?.findRenderObject() as RenderBox?;
                final origin = box == null
                    ? null
                    : box.localToGlobal(Offset.zero) & box.size;
                for (final p in _participants
                    .where((p) => p.phone?.isNotEmpty == true)) {
                  await _sendToParticipant(p, methods,
                      sharePositionOrigin: origin);
                }
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Enviar a todos'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Participant form sheet ───────────────────────────────────────────────────

class _MultiParticipantSheet extends StatefulWidget {
  final _Participant? existing;
  final double maxAmount;
  final void Function(_Participant) onSave;

  const _MultiParticipantSheet({
    this.existing,
    required this.maxAmount,
    required this.onSave,
  });

  @override
  State<_MultiParticipantSheet> createState() => _MultiParticipantSheetState();
}

class _MultiParticipantSheetState extends State<_MultiParticipantSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _amountCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _amountCtrl = TextEditingController(
      text: e == null ? '' : ThousandsInputFormatter.format(e.amount.toInt()),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }


  Future<void> _pickContact() async {
    final (name, phone) = await pickContact();
    if (!mounted) return;
    setState(() {
      if (name.isNotEmpty) _nameCtrl.text = name;
      _phoneCtrl.text = phone;
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe un nombre');
      return;
    }
    final amount = ThousandsInputFormatter.parse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingresa un monto válido');
      return;
    }
    if (amount > widget.maxAmount + 0.5) {
      setState(() => _error =
          'Excede lo disponible (máx. \$${ThousandsInputFormatter.format(widget.maxAmount.toInt())})');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    widget.onSave(_Participant(
      name: name,
      phone: phone.isEmpty ? null : phone,
      amount: amount,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.existing == null ? 'Agregar persona' : 'Editar persona',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Disponible: \$${ThousandsInputFormatter.format(widget.maxAmount.toInt())}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Sebastián',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'WhatsApp',
                    hintText: '+57 300 000 0000',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Text('📱', style: TextStyle(fontSize: 16)),
                    ),
                    helperText: 'Al cobrar se abre directo su chat',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconButton.outlined(
                  onPressed: _pickContact,
                  icon: const Icon(Icons.contacts_rounded),
                  tooltip: 'Elegir de contactos',
                  style: IconButton.styleFrom(
                    fixedSize: const Size(52, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsInputFormatter()],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Monto que debe',
              prefixText: '\$ ',
              helperText:
                  'Máx. \$${ThousandsInputFormatter.format(widget.maxAmount.toInt())}',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(
                    color: theme.colorScheme.error, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}
