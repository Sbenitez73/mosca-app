import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../features/expenses/presentation/providers/expenses_provider.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

class _Page {
  final IconData? icon;
  final bool useAppIcon;
  final String title;
  final String body;

  const _Page({
    this.icon,
    this.useAppIcon = false,
    required this.title,
    required this.body,
  });
}

const _pages = [
  _Page(
    useAppIcon: true,
    title: '¡Bienvenido a Mosca!',
    body: 'Tu plata, clara y sin rollos. El rastreador de finanzas hecho para Colombia.',
  ),
  _Page(
    icon: Icons.auto_awesome_rounded,
    title: 'Tus gastos, solos',
    body: 'Conecta tu Gmail y Mosca detecta y registra automáticamente las transacciones de Bancolombia, Nequi, Davivienda, BBVA, Nu y Falabella.',
  ),
  _Page(
    icon: Icons.bar_chart_rounded,
    title: 'Siempre sabe cómo vas',
    body: 'Presupuestos por categoría con alertas, estadísticas mensuales y proyección de cuánto te queda.',
  ),
  _Page(
    icon: Icons.group_rounded,
    title: 'Divide y cobra fácil',
    body: 'Reparte cualquier gasto entre varias personas y cobra directo por WhatsApp con un toque.',
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _current = 0;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
  }

  bool get _isLast => _current == _pages.length - 1;

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    await ref.read(databaseServiceProvider).setSetting('onboarding_done', '1');
    ref.read(onboardingDoneProvider.notifier).state = true;
    if (mounted) context.go('/');
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip ───────────────────────────────────────────────────────
            SizedBox(
              height: 48,
              child: _isLast
                  ? null
                  : Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton(
                          onPressed: _finish,
                          child: Text(
                            'Saltar',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            // ── Pages ──────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _PageView(page: _pages[i]),
              ),
            ),

            // ── Dots ───────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => _Dot(active: i == _current),
              ),
            ),

            const SizedBox(height: 28),

            // ── Button ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _next,
                  child: Text(_isLast ? 'Comenzar' : 'Siguiente'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single page ──────────────────────────────────────────────────────────────

class _PageView extends StatelessWidget {
  final _Page page;
  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Illustration ─────────────────────────────────────────────────
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: page.useAppIcon
                ? Padding(
                    padding: const EdgeInsets.all(22),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/splash/splash_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  )
                : Icon(page.icon, size: 56, color: Theme.of(context).colorScheme.primary),
          ),

          const SizedBox(height: 40),

          // ── Title ─────────────────────────────────────────────────────────
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          // ── Body ──────────────────────────────────────────────────────────
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dot indicator ────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
