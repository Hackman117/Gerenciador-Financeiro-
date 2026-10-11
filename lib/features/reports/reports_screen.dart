import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/report_service.dart';
import '../../ui/charts.dart';
import '../../ui/common.dart';
import '../../ui/report_render.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.month;
  bool _generating = false;
  final _pieKey = GlobalKey();
  final _trendKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _generating ? null : () => _generatePdf(db),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: _generating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Gerar PDF'),
            ),
          ),
        ],
      ),
      body: FutureBuilder<ReportData>(
        future: _buildReport(db),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ReportPreview(
            report: snapshot.data!,
            onPeriodChanged: (p) => setState(() => _period = p),
            pieKey: _pieKey,
            trendKey: _trendKey,
          );
        },
      ),
    );
  }

  Future<ReportData> _buildReport(AppDatabase db) async {
    final now = DateTime.now();
    final start = _period.start(now);
    final end = DateTime(now.year, now.month + 1, 0);

    final categories = await db.getCategories();
    final categoriesMap = {for (final c in categories) c.id: c};

    final income = await db.sumByType(kIncome, from: start, to: end);
    final expense = await db.sumByType(kExpense, from: start, to: end);
    final balance = await db.totalBalance();
    final expensesByCategory = await db.categoryBreakdown(kExpense, from: start, to: end);
    final incomeByCategory = await db.categoryBreakdown(kIncome, from: start, to: end);
    final accounts = await db.getAccounts();
    final transactions = await db.watchTransactions(from: start, to: end, limit: 15).first;

    var largest = 0;
    final allTx = await db.watchTransactions(from: start, to: end, limit: 5000).first;
    for (final t in allTx) {
      if (t.type == kExpense && t.amount > largest) largest = t.amount;
    }
    final days = end.difference(start).inDays + 1;
    final dailyAvg = days == 0 ? 0.0 : expense / days;

    final trend = switch (_period) {
      ReportPeriod.week || ReportPeriod.month => await db.timeSeries(_period == ReportPeriod.week ? 'semana' : 'mes'),
      ReportPeriod.sixMonths || ReportPeriod.year => [
        for (final m in await db.monthlySummary(_period == ReportPeriod.sixMonths ? 6 : 12))
          (label: m.month, income: m.income, expense: m.expense),
      ],
      ReportPeriod.all => await db.timeSeries('anos'),
    };

    return ReportData(
      period: _period,
      start: start,
      now: now,
      income: income,
      expense: expense,
      balance: balance,
      largestExpense: largest,
      dailyAverage: dailyAvg,
      expensesByCategory: expensesByCategory,
      incomeByCategory: incomeByCategory,
      categories: categoriesMap,
      trend: trend,
      accounts: accounts,
      transactions: transactions,
      accountsCount: accounts.length,
    );
  }

  Future<void> _generatePdf(AppDatabase db) async {
    setState(() => _generating = true);
    try {
      final report = await _buildReport(db);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final piePng = await _capture(_pieKey);
      final trendPng = await _capture(_trendKey);

      final bytes = await ReportService.buildPdf(
        report,
        pieImage: piePng,
        trendImage: trendPng,
      );

      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'finamind-${_period.name}-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      if (mounted) showAppSnack(context, 'PDF gerado com sucesso!');
    } catch (e) {
      if (mounted) showAppSnack(context, 'Erro ao gerar PDF: $e', error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<Uint8List> _capture(GlobalKey key) async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.5);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

/// Pré-visualização do relatório em tema claro (para o PDF sair consistente).
class _ReportPreview extends StatelessWidget {
  final ReportData report;
  final ValueChanged<ReportPeriod> onPeriodChanged;
  final GlobalKey pieKey;
  final GlobalKey trendKey;

  const _ReportPreview({
    required this.report,
    required this.onPeriodChanged,
    required this.pieKey,
    required this.trendKey,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final expenses = [
      for (final d in report.expensesByCategory)
        (
          label: report.categories[d.categoryId]?.name ?? 'Outros',
          amount: d.amount,
          color: report.categories[d.categoryId]?.color ?? 0xFF94A3B8,
        ),
    ];

    return Theme(
      data: AppTheme.light(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Center(
            child: FilterSegmented<ReportPeriod>(
              values: ReportPeriod.values,
              labels: [for (final p in ReportPeriod.values) p.label],
              selected: report.period,
              onChanged: onPeriodChanged,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              ReportRender.periodText(report.period, now, report.start),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 16),
          // Gráficos que serão capturados para o PDF (tema claro).
          RepaintBoundary(
            key: pieKey,
            child: ReportRender.donutCard(expenses, report.income, report.expense),
          ),
          const SizedBox(height: 16),
          RepaintBoundary(
            key: trendKey,
            child: ReportRender.trendCard(report),
          ),
          const SizedBox(height: 16),
          ReportRender.summaryGrid(report),
          const SizedBox(height: 16),
          ReportRender.categoryTable(report),
          const SizedBox(height: 16),
          ReportRender.recentTable(report),
        ],
      ),
    );
  }
}