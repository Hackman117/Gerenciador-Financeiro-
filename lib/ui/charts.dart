import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils.dart';

/// Doughnut com centro e legenda vertical.
class CategoryDonut extends StatelessWidget {
  final List<({String label, int amount, int color})> data;
  final String centerTitle;
  final String centerSubtitle;

  const CategoryDonut({
    super.key,
    required this.data,
    required this.centerTitle,
    required this.centerSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = data.fold<int>(0, (sum, d) => sum + d.amount);
    final visible = data.take(6).toList();
    final others = data.skip(6).fold<int>(0, (sum, d) => sum + d.amount);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 62,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                    sections: [
                      ...List.generate(visible.length, (i) {
                        final d = visible[i];
                        return PieChartSectionData(
                          value: total == 0 ? 1 : d.amount.toDouble(),
                          color: Color(d.color),
                          radius: 34,
                          title: '',
                        );
                      }),
                      if (others > 0)
                        PieChartSectionData(
                          value: others.toDouble(),
                          color: Colors.grey.shade600,
                          radius: 34,
                          title: '',
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      centerSubtitle,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final d in visible.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Color(d.color),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        Formats.money(d.amount),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              if (others > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Outras', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        Formats.money(others),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Barras agrupadas receita x gasto (mês a mês).
class CashFlowBars extends StatelessWidget {
  final List<({String label, int income, int expense})> data;

  const CashFlowBars({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEmpty = data.every((d) => d.income == 0 && d.expense == 0);
    final maxValue = data.fold<int>(0, (m, d) => d.income > m ? d.income : (d.expense > m ? d.expense : m));
    final labels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    if (isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded, size: 34, color: scheme.outlineVariant),
              const SizedBox(height: 8),
              Text(
                'Sem movimentação no período',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxValue == 0 ? 100 : maxValue.toDouble(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final d = data[group.x];
                return BarTooltipItem(
                  '${d.label}\n${rodIndex == 0 ? 'Receitas' : 'Gastos'}: ${Formats.money(rod.toY.round())}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: .25),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          alignment: BarChartAlignment.spaceAround,
          groupsSpace: 6,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) return const SizedBox.shrink();
                  final month = DateTime.tryParse('${data[index].label}-01')?.month;
                  final hasTransactions = data[index].income != 0 || data[index].expense != 0;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      month != null ? labels[month - 1] : data[index].label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: hasTransactions ? FontWeight.w800 : FontWeight.w500,
                        color: hasTransactions ? scheme.onSurface : scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 3,
                barRods: [
                  BarChartRodData(
                    toY: data[i].income.toDouble(),
                    color: AppColors.income,
                    width: 9,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  BarChartRodData(
                    toY: data[i].expense.toDouble(),
                    color: AppColors.expense,
                    width: 9,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
          minY: 0,
        ),
      ),
    );
  }
}

/// Linha de tendência para gastos ao longo do tempo.
class TrendChart extends StatelessWidget {
  final List<({String label, int income, int expense})> data;
  final bool showIncome;
  final bool showExpense;

  const TrendChart({super.key, required this.data, this.showIncome = true, this.showExpense = true});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = data.fold<int>(
      0,
      (m, d) => [
        if (showExpense) d.expense,
        if (showIncome) d.income,
        m,
      ].reduce((a, b) => a > b ? a : b),
    );

    List<FlSpot> spots(bool income) => [
          for (var i = 0; i < data.length; i++)
            FlSpot(i.toDouble(), (income ? data[i].income : data[i].expense).toDouble()),
        ];

    final lineTouch = LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (spots) => [
          for (final s in spots)
            LineTooltipItem(
              '${data[s.x.toInt()].label}\n'
              '${s.bar.color == AppColors.income ? 'Receitas' : 'Gastos'}: ${Formats.money(s.y.round())}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
        ],
      ),
    );

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          maxY: maxValue == 0 ? 100 : maxValue * 1.15,
          lineTouchData: lineTouch,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: .25),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: data.length > 8 ? 2 : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) return const SizedBox.shrink();
                  final show = data.length <= 12 || index % 3 == 0;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      show ? data[index].label : '',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            if (showExpense)
              LineChartBarData(
                spots: spots(false),
                isCurved: true,
                curveSmoothness: .35,
                preventCurveOverShooting: true,
                color: AppColors.expense,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.expense.withValues(alpha: .10),
                ),
              ),
            if (showIncome)
              LineChartBarData(
                spots: spots(true),
                isCurved: true,
                curveSmoothness: .35,
                preventCurveOverShooting: true,
                color: AppColors.income,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.income.withValues(alpha: .08),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const ChartLegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class FilterSegmented<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  const FilterSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < values.length; i++)
            GestureDetector(
              onTap: () => onChanged(values[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected == values[i] ? scheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected == values[i] ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}