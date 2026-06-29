import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/thousands_formatter.dart';
import '../../../expenses/data/models/expense.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../data/models/expense_split.dart';
import '../../data/models/payment_method.dart';
import '../../data/models/split_contact.dart';
import '../providers/splits_provider.dart';
import '../utils/reimbursement_helper.dart';
import '../utils/whatsapp_sender.dart';

class SplitExpenseScreen extends ConsumerStatefulWidget {
  final Expense expense;
  const SplitExpenseScreen({super.key, required this.expense});

  @override
  ConsumerState<SplitExpenseScreen> createState() => _SplitExpenseScreenState();
}

class _SplitExpenseScreenState extends ConsumerState<SplitExpenseScreen> {
  String? _photoPath;
  bool _savingPhoto = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _photoPath = widget.expense.receiptPhotoPath;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    setState(() => _savingPhoto = true);
    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(dir.path, 'receipts', '${widget.expense.id}.jpg');
    await Directory(p.dirname(dest)).create(recursive: true);
    await File(file.path).copy(dest);
    final updated = widget.expense.copyWith(receiptPhotoPath: dest);
    await ref.read(expenseRepositoryProvider).save(updated);
    if (mounted) setState(() { _photoPath = dest; _savingPhoto = false; });
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Tomar foto'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de galería'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            if (_photoPath != null)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: Theme.of(ctx).colorScheme.error),
                title: Text('Eliminar foto',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final updated = widget.expense.copyWith(receiptPhotoPath: '');
                  await ref.read(expenseRepositoryProvider).save(updated);
                  if (mounted) setState(() => _photoPath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _buildMessage(ExpenseSplit split, List<PaymentMethod> methods) {
    final amount = CurrencyFormatter.format(split.amount,
        currency: widget.expense.currency);
    final desc = widget.expense.displayName.isNotEmpty
        ? widget.expense.displayName
        : widget.expense.description;
    final buffer = StringBuffer();
    buffer.writeln('Hola, ${split.name}. Me quedaste debiendo $amount de $desc.');
    if (methods.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Podés pagarme por:');
      for (final m in methods) {
        buffer.writeln('• ${m.label}: ${m.value}');
      }
    }
    return buffer.toString().trim();
  }

  Future<void> _shareWithPerson(
      ExpenseSplit split, List<PaymentMethod> methods, Rect? origin) async {
    try {
      await sendViaWhatsApp(
        text: _buildMessage(split, methods),
        phone: split.phone,
        photoPaths: _photoPath != null ? [_photoPath!] : [],
        sharePositionOrigin: origin,
      );

      if (!mounted) return;
      final paid = await maybeRegisterReimbursement(
        context, ref,
        personName: split.name,
        amount: split.amount,
      );
      if (paid && mounted) {
        await ref.read(splitRepositoryProvider).markSettled(split.id!);
        await NotificationService.cancelSplitReminder(split.id!);
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e')),
        );
      }
    }
  }

  void _showAddParticipantSheet({
    ExpenseSplit? existing,
    required int expenseId,
    required List<ExpenseSplit> currentSplits,
  }) {
    final expense = widget.expense;
    final expenseDesc = expense.displayName.isNotEmpty
        ? expense.displayName
        : expense.description;

    // Sum of all splits except the one being edited
    final alreadyAssigned = currentSplits
        .where((s) => s.id != existing?.id)
        .fold(0.0, (sum, s) => sum + s.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParticipantSheet(
        existing: existing,
        expenseId: expenseId,
        expenseAmount: expense.amount,
        alreadyAssigned: alreadyAssigned,
        onSave: (split) async {
          final isNew = split.id == null;
          final insertedId = await ref.read(splitRepositoryProvider).save(split);
          if (isNew && insertedId != null) {
            await NotificationService.scheduleSplitReminder(
              splitId: insertedId,
              personName: split.name,
              amount: split.amount,
              expenseDesc: expenseDesc,
            );
          }
          HapticFeedback.lightImpact();
        },
      ),
    );
  }

  Future<void> _quickSplit(int n, List<ExpenseSplit> currentSplits) async {
    final total = widget.expense.amount.round();
    final base = (total ~/ n).toDouble();
    final remainder = (total % n).toDouble();
    final repo = ref.read(splitRepositoryProvider);
    // n = total people including the user, so we create n-1 participants.
    final othersCount = n - 1;

    if (currentSplits.length == othersCount) {
      // Redistribute existing splits keeping names
      for (var i = 0; i < othersCount; i++) {
        final amount = base + (i == 0 ? remainder : 0);
        await repo.save(currentSplits[i].copyWith(amount: amount));
      }
    } else {
      // Delete all and create othersCount placeholders
      for (final s in currentSplits) {
        await repo.delete(s.id!);
        await NotificationService.cancelSplitReminder(s.id!);
      }
      for (var i = 1; i <= othersCount; i++) {
        final amount = base + (i == 1 ? remainder : 0);
        await repo.save(ExpenseSplit(
          expenseId: widget.expense.id!,
          name: 'Persona $i',
          amount: amount,
        ));
      }
    }
    HapticFeedback.lightImpact();
  }

  void _showAddPaymentMethodSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickPaymentMethodSheet(
        onSave: (method) async {
          final current = ref.read(paymentMethodsProvider).valueOrNull ?? [];
          await ref.read(paymentMethodsProvider.notifier).save([...current, method]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final splitsAsync = ref.watch(splitsForExpenseProvider(expense.id!));
    final methodsAsync = ref.watch(paymentMethodsProvider);
    final theme = Theme.of(context);

    final methods = methodsAsync.valueOrNull;
    if (methods != null && methods.isEmpty) {
      return _PaymentMethodsRequired(onAdd: _showAddPaymentMethodSheet);
    }

    // Read-only when at least one participant exists and nobody is over-charged.
    // The leftover is implicitly the user's own share — no need to add themselves.
    // _editing lets the user temporarily unlock the screen to make corrections.
    final currentSplits = splitsAsync.valueOrNull ?? [];
    final currentAssigned = currentSplits.fold(0.0, (s, e) => s + e.amount);
    final readOnly = !_editing &&
        currentSplits.isNotEmpty &&
        currentAssigned <= expense.amount + 0.5;

    return Scaffold(
      appBar: AppBar(title: const Text('Dividir gasto')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // ── Read-only banner ────────────────────────────────────────────
          if (readOnly) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 16, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gasto dividido — solo lectura',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4CAF50),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _editing = true),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Editar',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // ── Editing banner ──────────────────────────────────────────────
          if (_editing) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_rounded,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modo edición',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _editing = false),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Listo',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Expense header ──────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.displayName.isNotEmpty
                              ? expense.displayName
                              : expense.description,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total del gasto',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(expense.amount, currency: expense.currency),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Receipt photo ───────────────────────────────────────────────
          Text('Factura', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_savingPhoto)
            const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()))
          else if (_photoPath != null && File(_photoPath!).existsSync())
            GestureDetector(
              onTap: readOnly ? null : _showPhotoOptions,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Image.file(File(_photoPath!),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover),
                    if (!readOnly)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.edit_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else if (!readOnly)
            GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'Agregar foto de la factura',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // ── Participants ────────────────────────────────────────────────
          splitsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (splits) {
              final assignedTotal = splits.fold(0.0, (s, e) => s + e.amount);
              final remaining = expense.amount - assignedTotal;
              final isBalanced = remaining.abs() < 1;
              final isOver = remaining < -0.5;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text('Participantes', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),

                  // ── Quick split (oculto en solo lectura) ──────────────
                  if (!readOnly) ...[
                    FilledButton.tonal(
                      onPressed: () => _quickSplit(2, splits),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.call_split_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Dividir a la mitad (entre 2)',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            'Otras divisiones:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(width: 8),
                          for (final n in [3, 4, 5, 6])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text('÷$n',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                onPressed: () => _quickSplit(n, splits),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Split summary bar ─────────────────────────────────
                  if (splits.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isOver
                            ? theme.colorScheme.error.withValues(alpha: 0.08)
                            : isBalanced
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                                : theme.colorScheme.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOver
                                ? Icons.warning_amber_rounded
                                : isBalanced
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded,
                            size: 16,
                            color: isOver
                                ? theme.colorScheme.error
                                : isBalanced
                                    ? const Color(0xFF4CAF50)
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isOver
                                  ? 'Excede el total por ${CurrencyFormatter.format(remaining.abs())}'
                                  : isBalanced
                                      ? 'División completa — suma el total exacto'
                                      : 'Tu parte: ${CurrencyFormatter.format(remaining)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isOver
                                    ? theme.colorScheme.error
                                    : isBalanced
                                        ? const Color(0xFF4CAF50)
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (splits.isNotEmpty) const SizedBox(height: 8),

                  // ── Split list ────────────────────────────────────────
                  if (splits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Agregá las personas que deben parte de este gasto',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  else
                    ...splits.map((s) => _SplitTile(
                          split: s,
                          methods: methodsAsync.valueOrNull ?? [],
                          readOnly: readOnly,
                          onShare: (origin) => _shareWithPerson(s, methodsAsync.valueOrNull ?? [], origin),
                          onEdit: () => _showAddParticipantSheet(
                              existing: s,
                              expenseId: expense.id!,
                              currentSplits: splits),
                          onDelete: () async =>
                              ref.read(splitRepositoryProvider).delete(s.id!),
                        )),

                  // ── "Tu parte" row ────────────────────────────────────
                  if (readOnly && !isBalanced && !isOver)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.08),
                              child: Icon(Icons.person_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tu parte',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(remaining),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Agregar persona (oculto en solo lectura) ──────────
                  if (!readOnly) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showAddParticipantSheet(
                          expenseId: expense.id!, currentSplits: splits),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Agregar persona'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Payment methods hint ────────────────────────────────────────
          methodsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
            data: (methods) => methods.isEmpty
                ? Card(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    child: ListTile(
                      leading: Icon(Icons.info_outline_rounded,
                          color: theme.colorScheme.primary, size: 20),
                      title: Text(
                        'Configurá tus datos de pago en Ajustes para que aparezcan en el mensaje',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── Split tile ───────────────────────────────────────────────────────────────

class _SplitTile extends ConsumerWidget {
  final ExpenseSplit split;
  final List<PaymentMethod> methods;
  final bool readOnly;
  final Future<void> Function(Rect? origin) onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  _SplitTile({
    required this.split,
    required this.methods,
    required this.readOnly,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
  });

  final GlobalKey _btnKey = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final contact = SplitContact(name: split.name, phone: split.phone);
    final isFav = ref.watch(splitFavoritesProvider).valueOrNull
            ?.any((c) => c.name == contact.name) ??
        false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Text(
                split.name.isNotEmpty ? split.name[0].toUpperCase() : '?',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(split.name,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Text(
              CurrencyFormatter.format(split.amount),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFav
                    ? Colors.amber
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
              onPressed: () =>
                  ref.read(splitFavoritesProvider.notifier).toggle(contact),
              tooltip: isFav ? 'Quitar de favoritos' : 'Agregar a favoritos',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            if (split.settled)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Cobrado',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50))),
              )
            else
              FilledButton.tonal(
                key: _btnKey,
                onPressed: () {
                  final box =
                      _btnKey.currentContext?.findRenderObject() as RenderBox?;
                  final origin =
                      box == null ? null : box.localToGlobal(Offset.zero) & box.size;
                  onShare(origin);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            if (!readOnly)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Participant form sheet ───────────────────────────────────────────────────

class _ParticipantSheet extends ConsumerStatefulWidget {
  final ExpenseSplit? existing;
  final int expenseId;
  final double expenseAmount;
  final double alreadyAssigned;
  final Future<void> Function(ExpenseSplit) onSave;

  const _ParticipantSheet({
    this.existing,
    required this.expenseId,
    required this.expenseAmount,
    required this.alreadyAssigned,
    required this.onSave,
  });

  @override
  ConsumerState<_ParticipantSheet> createState() => _ParticipantSheetState();
}

class _ParticipantSheetState extends ConsumerState<_ParticipantSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _amountCtrl;
  bool _saving = false;
  String? _error;

  Future<void> _pickContact() async {
    final (name, phone) = await pickContact();
    if (!mounted) return;
    setState(() {
      if (name.isNotEmpty) _nameCtrl.text = name;
      _phoneCtrl.text = phone;
    });
  }

  double get _maxAmount => widget.expenseAmount - widget.alreadyAssigned;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl  = TextEditingController(text: e?.name ?? '');
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

  Future<void> _save() async {
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
    if (amount > _maxAmount + 0.5) {
      setState(() => _error =
          'El monto excede lo disponible (máx. \$${ThousandsInputFormatter.format(_maxAmount.toInt())})');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final phone = _phoneCtrl.text.trim();
      await widget.onSave(ExpenseSplit(
        id: widget.existing?.id,
        expenseId: widget.expenseId,
        name: name,
        phone: phone.isEmpty ? null : phone,
        amount: amount,
      ));
    } catch (_) {
      // Ignore non-critical errors (e.g. notification scheduling)
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final favorites = ref.watch(splitFavoritesProvider).valueOrNull ?? [];

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
              width: 36, height: 4,
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
            'Disponible: \$${ThousandsInputFormatter.format(_maxAmount.toInt())}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          // Favorites quick-select
          if (favorites.isNotEmpty && widget.existing == null) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: favorites.map((fav) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.amber.withValues(alpha: 0.2),
                      child: Text(
                        fav.name[0].toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber),
                      ),
                    ),
                    label: Text(fav.name),
                    onPressed: () => setState(() {
                      _nameCtrl.text = fav.name;
                      if (fav.phone?.isNotEmpty == true) {
                        _phoneCtrl.text = fav.phone!;
                      }
                    }),
                  ),
                )).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Sebastián',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              helperText: 'Máx. \$${ThousandsInputFormatter.format(_maxAmount.toInt())}',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
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
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payment methods required gate ───────────────────────────────────────────

class _PaymentMethodsRequired extends StatelessWidget {
  final VoidCallback onAdd;
  const _PaymentMethodsRequired({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Dividir gasto')),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.payments_rounded,
                  size: 36, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Antes de dividir,\nagregá tus datos de pago',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Los datos de pago (Nequi, Bancolombia, etc.) se incluyen en el mensaje que le mandás a cada persona para que te paguen.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar dato de pago'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick payment method sheet ───────────────────────────────────────────────

class _QuickPaymentMethodSheet extends StatefulWidget {
  final Future<void> Function(PaymentMethod) onSave;
  const _QuickPaymentMethodSheet({required this.onSave});

  @override
  State<_QuickPaymentMethodSheet> createState() =>
      _QuickPaymentMethodSheetState();
}

class _QuickPaymentMethodSheetState extends State<_QuickPaymentMethodSheet> {
  final _labelCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    final value = _valueCtrl.text.trim();
    if (label.isEmpty || value.isEmpty) {
      setState(() => _error = 'Completá los dos campos');
      return;
    }
    setState(() { _saving = true; _error = null; });
    await widget.onSave(PaymentMethod(label: label, value: value));
    if (mounted) Navigator.pop(context);
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
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Agregar dato de pago', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Podés agregar más en Ajustes después.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Nequi, Bancolombia',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueCtrl,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Número / usuario',
              hintText: 'Ej. 300 000 0000',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
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
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar y continuar'),
            ),
          ),
        ],
      ),
    );
  }
}

