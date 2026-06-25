import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/biometric_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/biometric_service.dart';
import 'core/theme/app_theme.dart';

class MoscaApp extends ConsumerWidget {
  const MoscaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Mosca',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) => _BiometricGate(child: child!),
    );
  }
}

class _BiometricGate extends ConsumerStatefulWidget {
  final Widget child;
  const _BiometricGate({required this.child});

  @override
  ConsumerState<_BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<_BiometricGate>
    with WidgetsBindingObserver {
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final enabled = ref.read(biometricEnabledProvider).valueOrNull ?? false;
      if (enabled) {
        ref.read(appLockedProvider.notifier).state = true;
        await _tryAuth();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tryAuth();
    } else if (state == AppLifecycleState.paused) {
      final enabled = ref.read(biometricEnabledProvider).valueOrNull ?? false;
      if (enabled) {
        ref.read(appLockedProvider.notifier).state = true;
      }
    }
  }

  Future<void> _tryAuth() async {
    if (_authenticating) return;
    final isLocked = ref.read(appLockedProvider);
    if (!isLocked) return;

    _authenticating = true;
    final ok = await BiometricService.authenticate();
    _authenticating = false;

    if (ok && mounted) {
      ref.read(appLockedProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(appLockedProvider);
    if (!isLocked) return widget.child;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'Mosca bloqueada',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _authenticating ? null : _tryAuth,
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Desbloquear'),
            ),
          ],
        ),
      ),
    );
  }
}
