import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils.dart';
import '../data/database.dart';
import '../data/report_service.dart';
import 'charts.dart';
import 'common.dart';

/// Renderização idêntica entre a prévia (tema claro) e o PDF gerado.
abstract final class ReportRender {
  static String periodText(ReportPeriod period, DateTime now, DateTime start) => switch (period) {
        ReportPeriod.week => '${Formats.date(start)} – ${Formats.date(now)}',
        ReportPeriod.month => Formats.monthYear(now),
        ReportPeriod.sixMonths =>
          '${Formats.monthYear(DateTime(start.year, start.month, 1))} – ${Formats.monthYear(now)}',
        ReportPeriod.year => '${Formats.monthYear(DateTime(start.year, start.month, 1))} – ${Formats.monthYear(now)}',
        ReportPeriod.all => 'Desde ${start.year}',
      };

  static Widget donutCard(List<({String label, int amount, int color})> expenses, int income, int expense) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dívidas por categoria', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          CategoryDonut(
            data: expenses,
            centerTitle: 'Dívidas',
            centerSubtitle: Formats.money(expense),
          ),
          const Divider(height: 28),
          const Text('Arrecadação do período', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Total recebido: ${Formats.money(income)}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.green),
          ),
        ],
      ),
    );
  }

  static Widget trendCard(ReportData report) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fluxo de caixa no período', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            _trendSubtitle(report),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TrendChart(data: report.trend),
        ],
      ),
    );
  }

  static String _trendSubtitle(ReportData report) => switch (report.period) {
        ReportPeriod.week => 'Receitas x gastos diários',
        ReportPeriod.month => 'Receitas x gastos diários do mês',
        ReportPeriod.sixMonths => 'Comparação dos últimos 6 meses',
        ReportPeriod.year => 'Comparação dos últimos 12 meses',
        ReportPeriod.all => 'Evolução ano a ano',
      };

  static Widget summaryGrid(ReportData r) {
    const items = [
      Icons.account_balance_wallet_rounded,
      Icons.arrow_upward_rounded,
      Icons.arrow_downward_rounded,
      Icons.savings_rounded,
    ];
    final values = [
      ('SALDO', Formats.money(r.balance), AppColors.primary),
      ('RECEITAS', Formats.money(r.income), AppColors.income),
      ('GASTOS', Formats.money(r.expense), AppColors.expense),
      ('ECONOMIA', Formats.money(r.savings), r.savings >= 0 ? AppColors.income : AppColors.expense),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < values.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: values[i].$3.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(items[i], size: 16, color: values[i].$3),
                        const SizedBox(height: 6),
                        Text(values[i].$1,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: values[i].$3)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            values[i].$2,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: values[i].$3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat('Maior gasto', Formats.money(r.largestExpense), AppColors.expense),
              const SizedBox(width: 10),
              _miniStat('Média diária', Formats.money(r.dailyAverage.round()), Colors.black87),
              const SizedBox(width: 10),
              _miniStat('Contas', '${r.accountsCount}', AppColors.info),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _miniStat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black54)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
        ),
      );

  static Widget categoryTable(ReportData r) {
    final rows = r.expensesByCategory.take(10).map((d) {
      final name = r.categories[d.categoryId]?.name ?? 'Outros';
      final color = r.categories[d.categoryId]?.color ?? 0xFF94A3B8;
      final pct = r.expense == 0 ? 0.0 : d.amount / r.expense;
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                CategoryAvatar(icon: r.categories[d.categoryId]?.icon ?? 'other', color: color, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(Formats.percent(pct),
                  style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(Formats.money(d.amount),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gastos por categoria', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Sem gastos no período', style: TextStyle(color: Colors.black54))),
            )
          else
            Table(
              columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.4)},
              children: [
                const TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Categoria', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('%', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Valor', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54)),
                    ),
                  ],
                ),
                for (final row in rows) row,
              ],
            ),
        ],
      ),
    );
  }

  static Widget recentTable(ReportData r) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Últimas movimentações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (r.transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Sem movimentações no período', style: TextStyle(color: Colors.black54))),
            )
          else
            ...r.transactions.map((tx) {
              final name = r.categories[tx.categoryId]?.name ?? '';
              final isIncome = tx.type == kIncome;
              final color = isIncome ? AppColors.income : (tx.type == kTransfer ? AppColors.transfer : AppColors.expense);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${tx.date.day}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          Text(Formats.shortDate(tx.date).split(' ').last,
                              style: const TextStyle(fontSize: 9, color: Colors.black54)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.description.isNotEmpty ? tx.description : name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(isIncome ? 'Receita' : (tx.type == kTransfer ? 'Transferência' : 'Despesa'),
                              style: const TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      ),
                    ),
                    Text('${isIncome ? '+' : '-'} ${Formats.money(tx.amount)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}