import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expenses/data/models/expense.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../data/models/expense_split.dart';
import '../../data/models/payment_method.dart';
import '../../data/models/split_contact.dart';
import '../providers/splits_provider.dart';

final _thousandsFmt = NumberFormat('#,##0', 'es_CO');

class SplitExpenseScreen extends ConsumerStatefulWidget {
  final Expense expense;
  const SplitExpenseScreen({super.key, required this.expense});

  @override
  ConsumerState<SplitExpenseScreen> createState() => _SplitExpenseScreenState();
}

class _SplitExpenseScreenState extends ConsumerState<SplitExpenseScreen> {
  String? _photoPath;
  bool _savingPhoto = false;

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
                    style:
                        TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final updated =
                      widget.expense.copyWith(receiptPhotoPath: '');
                  await ref.read(expenseRepositoryProvider).save(updated);
                  if (mounted) setState(() => _photoPath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareWithPerson(
      ExpenseSplit split, List<PaymentMethod> methods) async {
    final amount = CurrencyFormatter.format(split.amount,
        currency: widget.expense.currency);
    final desc = widget.expense.displayName.isNotEmpty
        ? widget.expense.displayName
        : widget.expense.description;

    final buffer = StringBuffer();
    buffer.writeln(
        'Hola, ${split.name}. Me quedaste debiendo $amount de $desc.');
    if (methods.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Podés pagarme por:');
      for (final m in methods) {
        buffer.writeln('• ${m.label}: ${m.value}');
      }
    }
    final text = buffer.toString().trim();

    if (_photoPath != null && File(_photoPath!).existsSync()) {
      await Share.shareXFiles([XFile(_photoPath!)], text: text);
    } else {
      await Share.share(text);
    }

    await ref.read(splitRepositoryProvider).markSettled(split.id!);
    await NotificationService.cancelSplitReminder(split.id!);
    HapticFeedback.lightImpact();
  }

  void _showAddParticipantSheet({ExpenseSplit? existing, required int expenseId}) {
    final expense = widget.expense;
    final expenseDesc = expense.displayName.isNotEmpty
        ? expense.displayName
        : expense.description;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParticipantSheet(
        existing: existing,
        expenseId: expenseId,
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

  Future<void> _splitEqually(List<ExpenseSplit> splits) async {
    if (splits.isEmpty) return;
    final each = widget.expense.amount / splits.length;
    for (final s in splits) {
      await ref.read(splitRepositoryProvider).save(
            s.copyWith(amount: double.parse(each.toStringAsFixed(0))),
          );
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
          await ref
              .read(paymentMethodsProvider.notifier)
              .save([...current, method]);
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

    // Block until at least one payment method is configured
    final methods = methodsAsync.valueOrNull;
    if (methods != null && methods.isEmpty) {
      return _PaymentMethodsRequired(onAdd: _showAddPaymentMethodSheet);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dividir gasto')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
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
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(expense.amount,
                        currency: expense.currency),
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
          GestureDetector(
            onTap: _showPhotoOptions,
            child: _savingPhoto
                ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()))
                : _photoPath != null && File(_photoPath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Image.file(File(_photoPath!),
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover),
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
                      )
                    : Container(
                        height: 90,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.04),
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
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (splits) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Participantes',
                          style: theme.textTheme.titleMedium),
                    ),
                    if (splits.length > 1)
                      TextButton.icon(
                        onPressed: () => _splitEqually(splits),
                        icon: const Icon(Icons.balance_rounded, size: 16),
                        label: const Text('Dividir igual'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (splits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Agregá las personas que deben parte de este gasto',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  )
                else
                  ...splits.map((s) => _SplitTile(
                        split: s,
                        methods: methodsAsync.valueOrNull ?? [],
                        onShare: () => _shareWithPerson(
                            s, methodsAsync.valueOrNull ?? []),
                        onEdit: () => _showAddParticipantSheet(
                            existing: s, expenseId: expense.id!),
                        onDelete: () async =>
                            ref.read(splitRepositoryProvider).delete(s.id!),
                      )),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showAddParticipantSheet(expenseId: expense.id!),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Agregar persona'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
            ),
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
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary),
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
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SplitTile({
    required this.split,
    required this.methods,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final contact = SplitContact(name: split.name, phone: split.phone);
    final isFav = ref.watch(splitFavoritesProvider).valueOrNull
            ?.any((c) => c.name == contact.name && c.phone == contact.phone) ??
        false;

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
                split.name.isNotEmpty ? split.name[0].toUpperCase() : '?',
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
                  Text(split.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (split.phone != null && split.phone!.isNotEmpty)
                    Text(split.phone!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        )),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(split.amount),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            // Star / favorite toggle
            IconButton(
              icon: Icon(
                isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFav ? Colors.amber : theme.colorScheme.onSurface.withValues(alpha: 0.3),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                onPressed: onShare,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(
                    value: 'delete', child: Text('Eliminar')),
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
  final Future<void> Function(ExpenseSplit) onSave;

  const _ParticipantSheet({
    this.existing,
    required this.expenseId,
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

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _amountCtrl = TextEditingController(
      text: e == null ? '' : _thousandsFmt.format(e.amount.toInt()),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _fillFromContact(SplitContact contact) {
    setState(() {
      _nameCtrl.text = contact.name;
      _phoneCtrl.text = contact.phone ?? '';
    });
    Navigator.pop(context); // close contact picker
  }

  void _openContactPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactPickerSheet(onSelect: _fillFromContact),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe un nombre');
      return;
    }
    final amount = double.tryParse(
      _amountCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingresa un monto válido');
      return;
    }
    setState(() { _saving = true; _error = null; });
    await widget.onSave(ExpenseSplit(
      id: widget.existing?.id,
      expenseId: widget.expenseId,
      name: name,
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      amount: amount,
    ));
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
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.existing == null
                      ? 'Agregar persona'
                      : 'Editar persona',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: _openContactPicker,
                icon: const Icon(Icons.contacts_rounded, size: 18),
                label: const Text('Contactos'),
              ),
            ],
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
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Teléfono (opcional)',
              hintText: '+57 300 000 0000',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [_ThousandsInputFormatter()],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Monto que debe',
              prefixText: '\$ ',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
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

// ─── Contact picker sheet ─────────────────────────────────────────────────────

class _ContactPickerSheet extends ConsumerStatefulWidget {
  final ValueChanged<SplitContact> onSelect;
  const _ContactPickerSheet({required this.onSelect});

  @override
  ConsumerState<_ContactPickerSheet> createState() =>
      _ContactPickerSheetState();
}

class _ContactPickerSheetState extends ConsumerState<_ContactPickerSheet> {
  List<Contact>? _contacts;
  bool _permissionDenied = false;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (mounted) setState(() => _contacts = contacts);
  }

  List<Contact> get _filtered {
    final all = _contacts ?? [];
    if (_search.isEmpty) return all;
    final q = _search.toLowerCase();
    return all.where((c) {
      if (c.displayName.toLowerCase().contains(q)) return true;
      return c.phones.any((p) => p.number.contains(q));
    }).toList();
  }

  void _selectContact(Contact c) {
    final phone =
        c.phones.isNotEmpty ? c.phones.first.number.replaceAll(' ', '') : null;
    widget.onSelect(SplitContact(name: c.displayName, phone: phone));
  }

  void _selectFavorite(SplitContact fav) {
    widget.onSelect(fav);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favorites = ref.watch(splitFavoritesProvider).valueOrNull ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Buscar contacto…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _permissionDenied
                  ? _PermissionDeniedView()
                  : _contacts == null
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          controller: scrollCtrl,
                          children: [
                            // ── Favoritos ──────────────────────────────
                            if (favorites.isNotEmpty && _search.isEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 16, color: Colors.amber),
                                    const SizedBox(width: 6),
                                    Text('Favoritos',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5)),
                                  ],
                                ),
                              ),
                              ...favorites.map(
                                (fav) => ListTile(
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.amber
                                        .withValues(alpha: 0.15),
                                    child: Text(
                                      fav.name.isNotEmpty
                                          ? fav.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.amber),
                                    ),
                                  ),
                                  title: Text(fav.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: fav.phone != null
                                      ? Text(fav.phone!)
                                      : null,
                                  onTap: () => _selectFavorite(fav),
                                ),
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 12, 16, 4),
                                child: Text('Todos los contactos',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5)),
                              ),
                            ],
                            // ── All contacts ───────────────────────────
                            if (_filtered.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                    child: Text('No se encontraron contactos')),
                              )
                            else
                              ..._filtered.map(
                                (c) => ListTile(
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      c.displayName.isNotEmpty
                                          ? c.displayName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary),
                                    ),
                                  ),
                                  title: Text(c.displayName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: c.phones.isNotEmpty
                                      ? Text(c.phones.first.number)
                                      : null,
                                  onTap: () => _selectContact(c),
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contacts_rounded,
                size: 48,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Sin acceso a contactos',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Habilitá el permiso en Ajustes del sistema para buscar contactos.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
              width: 72,
              height: 72,
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

// ─── Quick payment method sheet (used from the gate) ─────────────────────────

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

// ─── Thousands formatter ──────────────────────────────────────────────────────

class _ThousandsInputFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat('#,##0', 'es_CO');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final formatted = _fmt.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
