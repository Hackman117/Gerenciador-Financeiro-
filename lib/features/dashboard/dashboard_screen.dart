import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/demo_data.dart';
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
          if (ref.watch(settingsProvider(DemoData.settingKey)).value == 'true') ...[
            const _DemoBanner(),
            const SizedBox(height: 12),
          ],
          _HeroCard(data: data),
          const SizedBox(height: 16),
          const _QuickActions(),
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
          if (data.hasActivity) ...[
            const SizedBox(height: 16),
            _MonthSummaryCard(data: data),
          ],
          if (data.hasMonthGoals) ...[
            const SizedBox(height: 16),
            _MoneyGoalsCard(data: data),
          ],
          const SizedBox(height: 16),
          _monthlyCard(),
          const SizedBox(height: 16),
          _budgetCard(),
          if (data.expenses.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TopCategoriesCard(data: data),
          ],
          if (data.upcoming.isNotEmpty) ...[
            const SizedBox(height: 16),
            _UpcomingCard(data: data),
          ],
          const SizedBox(height: 16),
          _recentCard(),
        ],
      ),
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
              Expanded(
                child: Text('Panorama do mês',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
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
    final summary = data.budgetSummary;
    if (summary.count == 0) {
      return _RecentTxTile(
        title: 'Orçamentos e Metas',
        icon: Icons.pie_chart_rounded,
        iconColor: AppColors.primary,
        subtitle: 'Acompanhe limites e objetivos',
        onTap: () => ref.read(shellTabProvider.notifier).state = 2,
      );
    }

    final ratio = summary.limit == 0 ? 0.0 : summary.spent / summary.limit;
    final over = summary.over;
    final barColor = over > 0 ? AppColors.expense : (ratio >= .85 ? AppColors.warning : AppColors.primary);
    final overLabel = over == 0 ? 'Tudo no limite' : (over == 1 ? '1 estourado' : '$over estourados');

    return AppCard(
      onTap: () => ref.read(shellTabProvider.notifier).state = 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Orçamentos do mês',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (over > 0 ? AppColors.expense : AppColors.income).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  overLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: over > 0 ? AppColors.expense : AppColors.income,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(Formats.money(summary.spent),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: barColor)),
              const SizedBox(width: 6),
              Text('de ${Formats.money(summary.limit)}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const Spacer(),
              Text(Formats.percent(ratio),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: barColor)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0), minHeight: 10, color: barColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${summary.count - over} de ${summary.count} categorias dentro do limite',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ],
      ),
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
                subtitle: 'Adicione sua primeira despesa ou receita para começar — '
                    'ou carregue dados de exemplo para ver o app cheio.',
                action: const LoadDemoButton(),
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
        separatorBuilder: (_, _) => const SizedBox(width: 10),
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
                Text(
                  _accountTypeLabel(type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.9)),
                ),
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

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _QuickAction(
          label: 'Receita',
          icon: Icons.arrow_upward_rounded,
          color: AppColors.income,
          onTap: () => context.push('/nova-transacao?tipo=receita'),
        ),
        const SizedBox(width: 10),
        _QuickAction(
          label: 'Gasto',
          icon: Icons.arrow_downward_rounded,
          color: AppColors.expense,
          onTap: () => context.push('/nova-transacao?tipo=despesa'),
        ),
        const SizedBox(width: 10),
        _QuickAction(
          label: 'Transferir',
          icon: Icons.swap_horiz_rounded,
          color: AppColors.transfer,
          onTap: () => context.push('/nova-transacao?tipo=transferencia'),
        ),
        const SizedBox(width: 10),
        _QuickAction(
          label: 'Nova meta',
          icon: Icons.flag_rounded,
          color: AppColors.warning,
          onTap: () => ref.read(shellTabProvider.notifier).state = 3,
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .25)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  final DashboardData data;

  const _MonthSummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Resumo do mês',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(Formats.monthYear(DateTime.now()),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Média por dia',
                  value: Formats.money(data.dailyAverage.round()),
                  icon: Icons.today_rounded,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Maior gasto',
                  value: Formats.money(data.largestExpense),
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Taxa de economia',
                  value: Formats.percent(data.savingsRate),
                  icon: Icons.savings_rounded,
                  color: AppColors.income,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Projeção até o fim do mês',
                  value: Formats.money(data.balance + data.projectedDelta),
                  icon: Icons.trending_up_rounded,
                  color: AppColors.transfer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CompareRow(label: 'Arrecadação', current: data.income, previous: data.prevIncome, goodWhenUp: true),
          const SizedBox(height: 8),
          _CompareRow(label: 'Gastos', current: data.expense, previous: data.prevExpense, goodWhenUp: false),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final int current;
  final int previous;
  final bool goodWhenUp;

  const _CompareRow({required this.label, required this.current, required this.previous, required this.goodWhenUp});

  @override
  Widget build(BuildContext context) {
    final delta = previous > 0 ? (current - previous) / previous : null;
    final up = (delta ?? 0) >= 0;
    final bad = delta != null && up != goodWhenUp;
    final color = bad ? AppColors.expense : AppColors.income;

    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
        ),
        if (delta != null) ...[
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 15, color: color),
          const SizedBox(width: 3),
          Text(Formats.percent(delta.abs()),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 10),
        ],
        Text(Formats.money(current), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _MoneyGoalsCard extends ConsumerWidget {
  final DashboardData data;

  const _MoneyGoalsCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final goals = data.monthGoals;
    final saved = data.savings;
    final target = goals.savings;
    final ratio = target <= 0 ? 0.0 : saved / target;
    final hit = target > 0 && saved >= target;

    final savedTotal = data.savingsGoals.fold<int>(0, (s, g) => s + g.savedAmount);
    final targetTotal = data.savingsGoals.fold<int>(0, (s, g) => s + g.targetAmount);
    final completed = data.savingsGoals.where((g) => g.completed).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Meta de juntar dinheiro',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const Icon(Icons.savings_rounded, size: 20, color: AppColors.income),
            ],
          ),
          const SizedBox(height: 2),
          Text('Sua economia do mês comparada com o quanto planejou guardar',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          if (target > 0) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Formats.money(saved),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: hit ? AppColors.income : scheme.onSurface,
                    )),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('de ${Formats.money(target)}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (hit ? AppColors.income : AppColors.primary).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(Formats.percent(ratio),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: hit ? AppColors.income : AppColors.primary,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 12,
                color: hit ? AppColors.income : AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hit
                  ? 'Meta do mês batida! Continue guardando assim.'
                  : 'Faltam ${Formats.money(target - saved)} para bater a meta do mês.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hit ? AppColors.income : scheme.onSurfaceVariant,
              ),
            ),
          ] else
            Text('Defina a meta de economia em Ajustes para acompanhar aqui.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          if (goals.income > 0) ...[
            const SizedBox(height: 16),
            _GoalBar(label: 'Arrecadação', current: data.income, target: goals.income, color: AppColors.income),
          ],
          if (goals.expense > 0) ...[
            const SizedBox(height: 12),
            _GoalBar(label: 'Gastos', current: data.expense, target: goals.expense, color: AppColors.primary, limitBad: true),
          ],
          if (data.savingsGoals.isNotEmpty) ...[
            const Divider(height: 24),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ref.read(shellTabProvider.notifier).state = 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.flag_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Objetivos: ${Formats.money(savedTotal)} de ${Formats.money(targetTotal)} guardados',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (completed > 0) ...[
                      Text(completed == 1 ? '1 concluída' : '$completed concluídas',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.income)),
                      const SizedBox(width: 4),
                    ],
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final Color color;
  final bool limitBad;

  const _GoalBar({
    required this.label,
    required this.current,
    required this.target,
    required this.color,
    this.limitBad = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = target <= 0 ? 0.0 : current / target;
    final over = limitBad && ratio > 1;
    final barColor = over ? AppColors.expense : color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
            const Spacer(),
            Text('${Formats.money(current)} de ${Formats.money(target)}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            Text(Formats.percent(ratio),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: barColor)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0), minHeight: 7, color: barColor),
        ),
      ],
    );
  }
}

class _TopCategoriesCard extends ConsumerWidget {
  final DashboardData data;

  const _TopCategoriesCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final top = data.expenses.take(5).toList();
    final total = data.expense;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Top categorias do mês',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              TextButton(
                onPressed: () => ref.read(shellTabProvider.notifier).state = 4,
                child: const Text('Relatórios'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CategoryAvatar(
                    icon: data.categories[item.categoryId]?.icon ?? 'other',
                    color: data.categories[item.categoryId]?.color ?? 0xFF94A3B8,
                    size: 34,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data.categories[item.categoryId]?.name ?? 'Outros',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(Formats.money(item.amount),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 40,
                              child: Text(
                                total == 0 ? '' : Formats.percent(item.amount / total),
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : (item.amount / total).clamp(0.0, 1.0),
                            minHeight: 6,
                            color: Color(data.categories[item.categoryId]?.color ?? 0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends ConsumerWidget {
  final DashboardData data;

  const _UpcomingCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = data.upcoming.take(4).toList();
    final today = DateTime.now();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Próximos 30 dias',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              TextButton(
                onPressed: () => ref.read(shellTabProvider.notifier).state = 5,
                child: const Text('Recorrentes'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final rule in rules) _UpcomingTile(rule: rule, categories: data.categories, today: today),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final RecurringRule rule;
  final Map<String, Category> categories;
  final DateTime today;

  const _UpcomingTile({required this.rule, required this.categories, required this.today});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIncome = rule.type == kIncome;
    final isTransfer = rule.type == kTransfer;
    final color = isTransfer ? AppColors.transfer : (isIncome ? AppColors.income : AppColors.expense);
    final category = categories[rule.categoryId];
    final due = DateTime(rule.nextDueDate.year, rule.nextDueDate.month, rule.nextDueDate.day);
    final days = due.difference(DateTime(today.year, today.month, today.day)).inDays;
    final when = days <= 0 ? 'hoje' : (days == 1 ? 'amanhã' : 'em ${days}d');
    final sign = isIncome ? '+' : (isTransfer ? '→' : '-');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CategoryAvatar(
            icon: category?.icon ?? (isTransfer ? 'cash' : 'other'),
            color: category?.color ?? 0xFF94A3B8,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${Formats.shortDate(rule.nextDueDate)} • $when',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            '$sign ${Formats.money(rule.amount)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
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
      onTap: () => context.push('/nova-transacao/${tx.id}'),
    );
  }
}

/// Faixa mostrada acima do panorama enquanto o modo demonstração está ativo,
/// com atalho para apagar os dados de exemplo.
class _DemoBanner extends ConsumerWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: .30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Modo demonstração: dados fictícios para explorar cada tela.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _exit(context, ref),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  Future<void> _exit(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Sair do modo demonstração?',
      message: 'Os dados de exemplo serão apagados e o app volta ao estado limpo.',
      confirmLabel: 'Sair do demo',
    );
    if (!ok) return;
    await DemoData.clear(ref.read(databaseProvider));
    if (context.mounted) showAppSnack(context, 'Dados de exemplo removidos');
  }
}
