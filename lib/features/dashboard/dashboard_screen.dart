import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/charts.dart';
import '../../ui/common.dart';
import '../shell/app_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panorama'),
        actions: [
          IconButton(
            onPressed: () => ref.read(shellTabProvider.notifier).state = 4,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Relatório PDF',
          ),
        ],
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (data) => _DashboardBody(data: data),
      ),
    );
  }
}

class _DashboardBody extends ConsumerStatefulWidget {
  final DashboardData data;

  const _DashboardBody({required this.data});

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  String _trendKind = 'semana';

  DashboardData get data => widget.data;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(dashboardProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          _HeroCard(data: data),
          const SizedBox(height: 16),
          _AccountsStrip(accounts: data.accounts),
          const SizedBox(height: 8),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: [_overviewCard(), const SizedBox(height: 16)])),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _trendCard()),
              ],
            )
          else ...[
            _overviewCard(),
            const SizedBox(height: 16),
            _trendCard(),
          ],
          const SizedBox(height: 16),
          _monthlyCard(),
          const SizedBox(height: 16),
          _budgetCard(),
          const SizedBox(height: 16),
          _recentCard(),
        ],
      ),
    );
  }

  // --------------------------------------------------------- hero

  Widget _heroBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'SALDO TOTAL',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {},
              style: IconButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.9)),
              icon: const Icon(Icons.more_horiz),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          Formats.money(data.balance),
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _HeroStat(label: 'Receitas', value: Formats.money(data.income), icon: Icons.arrow_upward_rounded),
            const SizedBox(width: 20),
            _HeroStat(label: 'Gastos', value: Formats.money(data.expense), icon: Icons.arrow_downward_rounded),
            const SizedBox(width: 20),
            _HeroStat(
              label: 'Economia',
              value: Formats.money(data.savings),
              icon: Icons.savings_rounded,
              valueColor: data.savings >= 0 ? const Color(0xFFB7F7D3) : const Color(0xFFFFC7CF),
            ),
          ],
        ),
      ],
    );
  }

  Widget _overviewCard() {
    final expenses = [
      for (final d in data.expenses)
        (
          label: data.categories[d.categoryId]?.name ?? 'Outros',
          amount: d.amount,
          color: data.categories[d.categoryId]?.color ?? 0xFF94A3B8,
        ),
    ];
    final incomes = [
      for (final d in data.incomes)
        (
          label: data.categories[d.categoryId]?.name ?? 'Outros',
          amount: d.amount,
          color: data.categories[d.categoryId]?.color ?? 0xFF16A34A,
        ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Panorama do mês', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(Formats.monthYear(DateTime.now()),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.expense.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CategoryDonut(
              data: expenses,
              centerTitle: 'Dívidas',
              centerSubtitle: Formats.money(data.expense),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CategoryDonut(
              data: incomes,
              centerTitle: 'Arrecadação',
              centerSubtitle: Formats.money(data.income),
            ),
          ),
          const SizedBox(height: 14),
          _InsightRow(data: data),
        ],
      ),
    );
  }

  Widget _trendCard() {
    final trend = ref.watch(timeSeriesProvider(_trendKind));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Gastos ao longo do tempo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              FilterSegmented<String>(
                values: const ['semana', 'mes', 'ano', 'anos'],
                labels: const ['Semana', 'Mês', 'Ano', 'Anos'],
                selected: _trendKind,
                onChanged: (v) => setState(() => _trendKind = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              ChartLegendDot(color: AppColors.expense, label: 'Gastos'),
              SizedBox(width: 18),
              ChartLegendDot(color: AppColors.income, label: 'Receitas'),
            ],
          ),
          const SizedBox(height: 16),
          trend.when(
            loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SizedBox(height: 220, child: Center(child: Text('Erro: $e'))),
            data: (points) => TrendChart(data: points),
          ),
        ],
      ),
    );
  }

  Widget _monthlyCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Fluxo mês a mês',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const Row(
                children: [
                  ChartLegendDot(color: AppColors.income, label: 'Receitas'),
                  SizedBox(width: 14),
                  ChartLegendDot(color: AppColors.expense, label: 'Gastos'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          CashFlowBars(data: data.monthly),
        ],
      ),
    );
  }

  Widget _budgetCard() {
    return _RecentTxTile(
      title: 'Orçamentos e Metas',
      icon: Icons.pie_chart_rounded,
      iconColor: AppColors.primary,
      subtitle: 'Acompanhe limites e objetivos',
      onTap: () => ref.read(shellTabProvider.notifier).state = 2,
    );
  }

  Widget _recentCard() {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text('Últimas movimentações',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(onPressed: () => ref.read(shellTabProvider.notifier).state = 1, child: const Text('Ver tudo')),
              ],
            ),
          ),
          if (data.recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Nada por aqui ainda',
                subtitle: 'Adicione sua primeira despesa ou receita para começar.',
              ),
            )
          else
            for (final tx in data.recent) _TxTile(tx: tx, categories: data.categories),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final DashboardData data;

  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradientDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.seed.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _HeroBody.from(data),
    );
  }
}

class _HeroBody extends StatelessWidget {
  final String total;
  final String income;
  final String expense;
  final String savings;
  final bool positive;

  const _HeroBody({
    required this.total,
    required this.income,
    required this.expense,
    required this.savings,
    required this.positive,
  });

  factory _HeroBody.from(DashboardData data) => _HeroBody(
        total: Formats.money(data.balance),
        income: Formats.money(data.income),
        expense: Formats.money(data.expense),
        savings: Formats.money(data.savings),
        positive: data.savings >= 0,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            _ChipLabel('SALDO TOTAL'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          total,
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _HeroStat(label: 'Receitas', value: income, icon: Icons.arrow_upward_rounded),
            const SizedBox(width: 20),
            _HeroStat(label: 'Gastos', value: expense, icon: Icons.arrow_downward_rounded),
            const SizedBox(width: 20),
            _HeroStat(
              label: 'Economia',
              value: savings,
              icon: Icons.savings_rounded,
              valueColor: positive ? const Color(0xFFC7F6D9) : const Color(0xFFFFD3D8),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String text;

  const _ChipLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _HeroStat({required this.label, required this.value, required this.icon, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountsStrip extends StatelessWidget {
  final List<Account> accounts;

  const _AccountsStrip({required this.accounts});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final account = accounts[i];
            final isDefaultColor = AppColors.accountColors[i % AppColors.accountColors.length];
          return _AccountChip(
            name: account.name,
            type: account.type,
            color: Color(isDefaultColor),
            isDefault: account.isDefault,
          );
        },
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  final String name;
  final String type;
  final Color color;
  final bool isDefault;

  const _AccountChip({required this.name, required this.type, required this.color, required this.isDefault});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Icon(AccountIcons.byType(type), size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    if (isDefault) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
                    ],
                  ],
                ),
                  Text(_accountTypeLabel(type), style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }

static String _accountTypeLabel(String type) => switch (type) {
        'checking' => 'Conta corrente',
        'savings' => 'Poupança',
        'cash' => 'Dinheiro',
        'credit' => 'Cartão',
        'investment' => 'Investimento',
        'digital' => 'Conta digital',
        _ => 'Carteira',
      };
}

class _InsightRow extends StatelessWidget {
  final DashboardData data;

  const _InsightRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text('Maior gasto do mês:',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Text(
            Formats.money(data.largestExpense),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.expense),
          ),
          const Spacer(),
          Text('Média/dia:', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Text(Formats.money(data.dailyAverage.round()),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RecentTxTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _RecentTxTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _TxTile extends StatelessWidget {
  final Tx tx;
  final Map<String, Category> categories;

  const _TxTile({required this.tx, required this.categories});

  @override
  Widget build(BuildContext context) {
    final category = categories[tx.categoryId];
    final isIncome = tx.type == kIncome;
    final isTransfer = tx.type == kTransfer;
    final color = isTransfer ? AppColors.transfer : (isIncome ? AppColors.income : AppColors.expense);

    return ListTile(
      leading: CategoryAvatar(icon: category?.icon ?? 'other', color: category?.color ?? 0xFF94A3B8),
      title: Text(
        tx.description.isNotEmpty ? tx.description : (category?.name ?? 'Sem categoria'),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        isTransfer
            ? 'Transferência • ${Formats.date(tx.date)}'
            : '${category?.name ?? 'Sem categoria'} • ${Formats.date(tx.date)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(
        '${isIncome ? '+' : '-'} ${Formats.money(tx.amount)}',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
      ),
      onTap: () => Navigator.of(context).pushNamed('/nova-transacao/${tx.id}'),
    );
  }
}
