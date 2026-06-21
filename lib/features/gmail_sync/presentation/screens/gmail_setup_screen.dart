import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/mosca_button.dart';
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
    'Davivienda',
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
