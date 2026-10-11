import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../accounts/accounts_screen.dart';
import '../budgets/budgets_screen.dart';
import '../categories/categories_screen.dart';
import '../credit_cards/credit_cards_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../goals/goals_screen.dart';
import '../recurring/recurring_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';

/// Índice da aba ativa do shell (compartilhado entre telas).
final shellTabProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final index = ref.watch(shellTabProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    final pages = [
      const DashboardScreen(),
      const TransactionsScreen(),
      const BudgetsScreen(),
      const GoalsScreen(),
      const ReportsScreen(),
      const RecurringScreen(),
      const AccountsScreen(),
      const CreditCardsScreen(),
      const CategoriesScreen(),
      const SettingsScreen(),
    ];

    final body = IndexedStack(index: index, children: pages);

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) =>
                      ref.read(shellTabProvider.notifier).state = i,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                    child: _Logo(),
                  ),
                  destinations: _railDestinations,
                ),
                const VerticalDivider(width: 1, thickness: 1, indent: 0, endIndent: 0),
                Expanded(child: body),
              ],
            )
          : body,
      floatingActionButton: index == 0 || index == 1
          ? const _QuickFAB()
          : null,
    );
  }

  List<NavigationRailDestination> get _railDestinations => [
        _rail(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Início'),
        _rail(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Transações'),
        _rail(Icons.pie_chart_outline, Icons.pie_chart_rounded, 'Orçamentos'),
        _rail(Icons.flag_outlined, Icons.flag_rounded, 'Metas'),
        _rail(Icons.insights_outlined, Icons.insights_rounded, 'Relatórios'),
        _rail(Icons.event_repeat_outlined, Icons.event_repeat_rounded, 'Recorrentes'),
        _rail(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Contas'),
        _rail(Icons.credit_card_outlined, Icons.credit_card_rounded, 'Cartões'),
        _rail(Icons.category_outlined, Icons.category_rounded, 'Categorias'),
        _rail(Icons.settings_outlined, Icons.settings_rounded, 'Ajustes'),
      ];

  NavigationRailDestination _rail(IconData icon, IconData selected, String label) =>
      NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label));
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primary.withValues(alpha: .7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.savings_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 6),
        Text(
          'FinaMind',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
      ],
    );
  }
}

class _QuickFAB extends ConsumerWidget {
  const _QuickFAB();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      onPressed: () => context.push('/nova-transacao'),
      tooltip: 'Nova transação',
      child: const Icon(Icons.add_rounded),
    );
  }
}

/// Sincroniza de forma transparente ao abrir o app (se configurado).
class SyncBanner extends ConsumerStatefulWidget {
  const SyncBanner({super.key});

  @override
  ConsumerState<SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends ConsumerState<SyncBanner> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
