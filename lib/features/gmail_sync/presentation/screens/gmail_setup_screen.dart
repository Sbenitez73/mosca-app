import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/biometric_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/mosca_button.dart';
import '../../../splits/data/models/payment_method.dart';
import '../../../splits/presentation/providers/splits_provider.dart';
import '../providers/gmail_sync_provider.dart';

class GmailSetupScreen extends ConsumerWidget {
  const GmailSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(gmailAuthProvider);
    final syncState = ref.watch(gmailSyncProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Gmail sync section ─────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.mark_email_read_rounded,
                            color: Colors.red.shade400),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gmail sync', style: theme.textTheme.titleMedium),
                          Text(
                            'Importa tus gastos automáticamente',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  authAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (isSignedIn) => isSignedIn
                        ? _SignedInContent(syncState: syncState)
                        : _SignedOutContent(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Categories ────────────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.label_rounded, color: AppColors.primary),
              ),
              title: const Text('Mis categorías'),
              subtitle: const Text('Crea categorías personalizadas'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/categories'),
            ),
          ),

          const SizedBox(height: 16),

          // ── Budgets ───────────────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.savings_rounded, color: Colors.green.shade600),
              ),
              title: const Text('Presupuestos'),
              subtitle: const Text('Límites mensuales por categoría'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/budgets'),
            ),
          ),

          const SizedBox(height: 16),

          // ── Recurring expenses ────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.repeat_rounded, color: Colors.blue.shade600),
              ),
              title: const Text('Gastos Recurrentes'),
              subtitle: const Text('Se registran automáticamente cada mes'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/recurring'),
            ),
          ),

          const SizedBox(height: 16),

          // ── Savings goals ─────────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.emoji_events_rounded,
                    color: Colors.teal.shade600),
              ),
              title: const Text('Metas de ahorro'),
              subtitle: const Text('Seguí el progreso hacia tus objetivos'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/savings'),
            ),
          ),

          const SizedBox(height: 16),

          // ── Biometric lock ────────────────────────────────────────────
          _BiometricToggleCard(),

          const SizedBox(height: 16),

          // ── Payment methods ───────────────────────────────────────────
          const _PaymentMethodsCard(),

          const SizedBox(height: 16),

          // ── Supported banks ───────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bancos soportados', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ..._banks.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(b, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Más bancos próximamente',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _banks = [
    'Bancolombia',
    'Nequi',
    'Davivienda / DAVIbank',
    'Nubank (Colombia & Brasil)',
    'BBVA',
    'Falabella / CMR',
  ];
}

class _SignedInContent extends ConsumerWidget {
  final GmailSyncState syncState;

  const _SignedInContent({required this.syncState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              ref.read(gmailClientProvider).currentUser?.email ?? 'Cuenta conectada',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        if (syncState.lastSync != null) ...[
          const SizedBox(height: 8),
          Text(
            'Última sincronización: ${_formatDate(syncState.lastSync!)}  '
            '· ${syncState.newExpenses} nuevos',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
        if (syncState.error != null) ...[
          const SizedBox(height: 8),
          Text(
            syncState.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        MoscaButton(
          label: 'Sincronizar ahora',
          icon: Icons.sync_rounded,
          isLoading: syncState.isSyncing,
          onPressed: () => ref.read(gmailSyncProvider.notifier).sync(),
        ),
        const SizedBox(height: 10),
        MoscaButton(
          label: 'Desconectar cuenta',
          outlined: true,
          onPressed: () => ref.read(gmailAuthProvider.notifier).signOut(),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

class _BiometricToggleCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final enabledAsync = ref.watch(biometricEnabledProvider);
    final enabled = enabledAsync.valueOrNull ?? false;
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.fingerprint_rounded, color: Colors.indigo.shade400),
        ),
        title: const Text('Bloqueo biométrico'),
        subtitle: Text(
          available
              ? 'Requiere Face ID / huella al abrir la app'
              : 'No disponible en este dispositivo',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: Switch(
          value: enabled,
          onChanged: available
              ? (v) => ref.read(biometricEnabledProvider.notifier).toggle(v)
              : null,
        ),
      ),
    );
  }
}

// ─── Payment methods card ─────────────────────────────────────────────────────

class _PaymentMethodsCard extends ConsumerStatefulWidget {
  const _PaymentMethodsCard();

  @override
  ConsumerState<_PaymentMethodsCard> createState() =>
      _PaymentMethodsCardState();
}

class _PaymentMethodsCardState extends ConsumerState<_PaymentMethodsCard> {
  void _showAddSheet([PaymentMethod? existing, int? index]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentMethodSheet(
        existing: existing,
        onSave: (method) async {
          final current =
              ref.read(paymentMethodsProvider).valueOrNull ?? [];
          final updated = existing == null
              ? [...current, method]
              : [
                  for (var i = 0; i < current.length; i++)
                    i == index ? method : current[i],
                ];
          await ref.read(paymentMethodsProvider.notifier).save(updated);
        },
        onDelete: existing == null
            ? null
            : () async {
                final current =
                    ref.read(paymentMethodsProvider).valueOrNull ?? [];
                final updated = [
                  for (var i = 0; i < current.length; i++)
                    if (i != index) current[i],
                ];
                await ref
                    .read(paymentMethodsProvider.notifier)
                    .save(updated);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(paymentMethodsProvider);
    final methods = methodsAsync.valueOrNull ?? [];
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(Icons.payments_rounded, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mis datos de pago',
                          style: theme.textTheme.titleMedium),
                      Text(
                        'Se incluyen al cobrarle a alguien',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _showAddSheet(),
                  tooltip: 'Agregar',
                ),
              ],
            ),
            if (methods.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...methods.asMap().entries.map(
                    (e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_balance_wallet_rounded,
                          size: 20),
                      title: Text(e.value.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(e.value.value),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showAddSheet(e.value, e.key),
                      ),
                    ),
                  ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Agregá Nequi, Bancolombia, etc. para que aparezcan en los mensajes de cobro',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodSheet extends StatefulWidget {
  final PaymentMethod? existing;
  final Future<void> Function(PaymentMethod) onSave;
  final VoidCallback? onDelete;

  const _PaymentMethodSheet({
    this.existing,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<_PaymentMethodSheet> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _valueCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.existing?.label ?? '');
    _valueCtrl = TextEditingController(text: widget.existing?.value ?? '');
  }

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
              width: 36,
              height: 4,
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
                      ? 'Agregar método de pago'
                      : 'Editar método de pago',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (widget.onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: theme.colorScheme.error),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete!();
                  },
                ),
            ],
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueCtrl,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Número / usuario',
              hintText: 'Ej. 300 000 0000 o @tuusuario',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    TextStyle(color: theme.colorScheme.error, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Signed out ───────────────────────────────────────────────────────────────

class _SignedOutContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conecta tu Gmail para importar gastos de tus notificaciones bancarias automáticamente.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
        ),
        const SizedBox(height: 16),
        MoscaButton(
          label: 'Conectar con Google',
          icon: Icons.login_rounded,
          onPressed: () => ref.read(gmailAuthProvider.notifier).signIn(),
        ),
      ],
    );
  }
}
