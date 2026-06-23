import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/recurring/presentation/screens/recurring_screen.dart';
import '../../features/expenses/data/models/expense.dart';
import '../../features/expenses/presentation/providers/expenses_provider.dart';
import '../../features/expenses/presentation/screens/home_screen.dart';
import '../../features/expenses/presentation/screens/expense_list_screen.dart';
import '../../features/expenses/presentation/screens/edit_expense_screen.dart';
import '../../features/expenses/presentation/screens/manage_categories_screen.dart';
import '../../features/quick_add/presentation/screens/quick_add_screen.dart';
import '../../features/quick_add/presentation/screens/quick_add_detail_screen.dart';
import '../../features/gmail_sync/presentation/screens/gmail_setup_screen.dart';
import '../../features/stats/presentation/screens/stats_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _Shell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/expenses',
          builder: (context, state) => const ExpenseListScreen(),
        ),
        GoRoute(
          path: '/stats',
          builder: (context, state) => const StatsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const GmailSetupScreen(),
        ),
        GoRoute(
          path: '/categories',
          builder: (context, state) => const ManageCategoriesScreen(),
        ),
        GoRoute(
          path: '/budgets',
          builder: (context, state) => const BudgetsScreen(),
        ),
        GoRoute(
          path: '/recurring',
          builder: (context, state) => const RecurringScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/expenses/edit',
      pageBuilder: (context, state) {
        final expense = state.extra as Expense;
        return MaterialPage(
          fullscreenDialog: true,
          child: EditExpenseScreen(expense: expense),
        );
      },
    ),
    GoRoute(
      path: '/quick-add',
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: QuickAddScreen(),
      ),
      routes: [
        GoRoute(
          path: 'detail',
          builder: (context, state) => const QuickAddDetailScreen(),
        ),
      ],
    ),
  ],
);

class _Shell extends ConsumerWidget {
  final Widget child;
  const _Shell({required this.child});

  static const _tabs = [
    ('/', Icons.home_rounded, 'Inicio'),
    ('/expenses', Icons.receipt_long_rounded, 'Gastos'),
    ('/stats', Icons.bar_chart_rounded, 'Estadísticas'),
    ('/settings', Icons.settings_rounded, 'Config'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final idx = _tabs.indexWhere((t) => t.$1 == location);
    return idx < 0 ? 0 : idx;
  }

  static const _noFabRoutes = {'/settings', '/categories', '/budgets', '/recurring'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final isSearching = ref.watch(searchActiveProvider);
    final showFab = !_noFabRoutes.contains(location) && !isSearching;

    return Scaffold(
      body: child,
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/quick-add'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar'),
              elevation: 2,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex(context),
        onTap: (i) => context.go(_tabs[i].$1),
        items: _tabs
            .map(
              (t) => BottomNavigationBarItem(icon: Icon(t.$2), label: t.$3),
            )
            .toList(),
      ),
    );
  }
}
