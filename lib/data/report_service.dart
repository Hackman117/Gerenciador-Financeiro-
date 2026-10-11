import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils.dart';
import 'database.dart';

enum ReportPeriod {
  week,
  month,
  sixMonths,
  year,
  all;

  String get label => switch (this) {
        ReportPeriod.week => 'Semana',
        ReportPeriod.month => 'Mês',
        ReportPeriod.sixMonths => '6 meses',
        ReportPeriod.year => '1 ano',
        ReportPeriod.all => 'Todos os anos',
      };

  DateTime start(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      ReportPeriod.week => today.subtract(const Duration(days: 6)),
      ReportPeriod.month => DateTime(now.year, now.month, 1),
      ReportPeriod.sixMonths => DateTime(now.year, now.month - 5, 1),
      ReportPeriod.year => DateTime(now.year - 1, now.month, 1),
      ReportPeriod.all => DateTime(2000, 1, 1),
    };
  }

  /// Limite superior inclusivo do período (os filtros usam `date <= fim`).
  DateTime end(DateTime now) => switch (this) {
        ReportPeriod.week => endOfDay(now),
        ReportPeriod.month || ReportPeriod.sixMonths || ReportPeriod.year || ReportPeriod.all =>
          endOfDay(DateTime(now.year, now.month + 1, 0)),
      };

  String subtitle(DateTime now, DateTime start) => switch (this) {
        ReportPeriod.week => FormatNow.dayRange(now, start),
        ReportPeriod.month => Formats.monthYear(now),
        ReportPeriod.sixMonths => FormatNow.monthRange(now, start),
        ReportPeriod.year => Formats.monthYear(start),
        ReportPeriod.all => 'Desde ${DateTime(start.year, start.month, 1).year}',
      };
}

/// Extrai atalhos de data usados no relatório.
abstract final class FormatNow {
  static String dayRange(DateTime now, DateTime start) =>
      '${Formats.date(start)} - ${Formats.date(now)}';

  static String monthRange(DateTime now, DateTime start) {
    final end = DateTime(now.year, now.month, 1);
    final begin = DateTime(start.year, start.month, 1);
    return '${Formats.monthYear(begin)} - ${Formats.monthYear(end)}';
  }
}

class ReportData {
  final ReportPeriod period;
  final DateTime start;
  final DateTime now;
  final int income;
  final int expense;
  final int balance;
  final int largestExpense;
  final double dailyAverage;
  final List<({String categoryId, int amount})> expensesByCategory;
  final List<({String categoryId, int amount})> incomeByCategory;
  final Map<String, Category> categories;
  final List<({String label, int income, int expense})> trend;
  final List<Account> accounts;
  final List<Tx> transactions;
  final int accountsCount;

  ReportData({
    required this.period,
    required this.start,
    required this.now,
    required this.income,
    required this.expense,
    required this.balance,
    required this.largestExpense,
    required this.dailyAverage,
    required this.expensesByCategory,
    required this.incomeByCategory,
    required this.categories,
    required this.trend,
    required this.accounts,
    required this.transactions,
    required this.accountsCount,
  });

  int get savings => income - expense;
  double get savingsRate => income == 0 ? 0 : (savings / income).clamp(0, 1);
}

class ReportService {
  static const PdfColor _primary = PdfColor.fromInt(0xFF0E9F6E);
  static const PdfColor _income = PdfColor.fromInt(0xFF12B76A);
  static const PdfColor _expense = PdfColor.fromInt(0xFFF04438);

  static Uint8List _png(Uint8List bytes) => bytes;

  static Future<Uint8List> buildPdf(ReportData report, {required Uint8List pieImage, required Uint8List trendImage}) async {
    final doc = pw.Document(title: 'Relatório FinaMind');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 3)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Relatório Financeiro', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _primary)),
                    pw.Text('FinaMind - ${report.period.label}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(report.period.subtitle(report.now, report.start),
                        style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Gerado em ${Formats.fullDate(report.now)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.SizedBox(height: 16, width: 470, child: pw.Image(pw.MemoryImage(_png(pieImage)), fit: pw.BoxFit.contain)),
          pw.SizedBox(height: 8),
          _summary(report),
          pw.SizedBox(height: 24),
          _sectionTitle('Gastos por categoria', report.period.label),
          pw.SizedBox(height: 8),
          _categoryTable(report),
          pw.SizedBox(height: 24),
          _sectionTitle('Fluxo de caixa no período', _trendTitle(report)),
          pw.SizedBox(height: 8),
          pw.SizedBox(height: 150, width: 470, child: pw.Image(pw.MemoryImage(_png(trendImage)), fit: pw.BoxFit.contain)),
          pw.SizedBox(height: 24),
          _sectionTitle('Contas', '${report.accountsCount} conta(s)'),
          pw.SizedBox(height: 8),
          _accountsTable(report),
          pw.SizedBox(height: 24),
          _sectionTitle('Últimas movimentações', 'top ${report.transactions.length}'),
          pw.SizedBox(height: 8),
          _transactionsTable(report),
        ],
      ),
    );

    return doc.save();
  }

  static String _trendTitle(ReportData report) => switch (report.period) {
        ReportPeriod.week || ReportPeriod.month => 'diário',
        ReportPeriod.sixMonths || ReportPeriod.year => 'mensal',
        ReportPeriod.all => 'anual',
      };

  static pw.Widget _sectionTitle(String title, String subtitle) => pw.Row(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
          pw.Spacer(),
          pw.Text(subtitle, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        ],
      );

  static pw.Widget _summary(ReportData r) {
    final items = <(String, String, PdfColor)>[
      ('SALDO TOTAL', Formats.money(r.balance), _primary),
      ('RECEITAS', Formats.money(r.income), _income),
      ('GASTOS', Formats.money(r.expense), _expense),
      ('ECONOMIA', Formats.money(r.savings), r.savings >= 0 ? _income : _expense),
      ('MÉDIA DIÁRIA', Formats.money(r.dailyAverage.round()), PdfColors.grey700),
      ('MAIOR GASTO', Formats.money(r.largestExpense), PdfColors.orange),
    ];
    return pw.GridView(
      crossAxisCount: 3,
      childAspectRatio: 2.1,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final (label, value, color) in items)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
              ],
            ),
          ),
      ],
    );
  }

  /// Listras alternadas com divisor fino; a linha 0 é o cabeçalho (tem `headerDecoration`).
  static pw.BoxDecoration _zebraRow(int cellIndex, dynamic data, int rowNum) => rowNum == 0
      ? const pw.BoxDecoration()
      : pw.BoxDecoration(
          color: rowNum.isEven ? PdfColors.white : PdfColors.grey100,
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5)),
        );

  static pw.Widget _categoryTable(ReportData r) {
    final rows = r.expensesByCategory.take(12).map((d) {
      final name = r.categories[d.categoryId]?.name ?? (d.categoryId == 'sem-categoria' ? 'Sem categoria' : 'Outros');
      final pct = r.expense == 0 ? 0.0 : d.amount / r.expense;
      return [
        name,
        Formats.percent(pct),
        Formats.money(d.amount),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: ['Categoria', '%', 'Valor'],
      data: rows,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
      headerStyle: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: pw.TextStyle(fontSize: 10, color: PdfColors.black),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
      },
      cellDecoration: _zebraRow,
    );
  }

  static pw.Widget _accountsTable(ReportData r) {
    // Tabela de contas com saldo - os saldos foram calculados no app.
    final rows = r.accounts
        .where((a) => !a.archived)
        .map((a) => [
              a.name,
              _accountTypeName(a.type),
              '-',
            ])
        .toList();

    return pw.Container(
      child: rows.isEmpty
          ? pw.Text('Nenhuma conta cadastrada.', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
          : pw.TableHelper.fromTextArray(
              headers: ['Conta', 'Tipo', 'Observação'],
              data: rows,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
              headerStyle: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: pw.TextStyle(fontSize: 10, color: PdfColors.black),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              cellDecoration: _zebraRow,
            ),
    );
  }

  static pw.Widget _transactionsTable(ReportData r) {
    final lastWithCategory = r.transactions.take(15).map((t) {
      final name = r.categories[t.categoryId]?.name ?? '';
      final type = t.type == 'income' ? 'Receita' : (t.type == 'expense' ? 'Despesa' : 'Transf.');
      final color = t.type == 'income' ? _income : _expense;
      return [
        Formats.date(t.date),
        t.description.isNotEmpty ? t.description : name,
        type,
        pw.Text(Formats.money(t.amount), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: ['Data', 'Descrição', 'Tipo', 'Valor'],
      data: lastWithCategory,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
      headerStyle: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: pw.TextStyle(fontSize: 10, color: PdfColors.black),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FlexColumnWidth(1.6),
      },
      cellDecoration: _zebraRow,
    );
  }

  static String _accountTypeName(String type) => switch (type) {
        'checking' => 'Conta corrente',
        'savings' => 'Poupança',
        'cash' => 'Dinheiro',
        'credit' => 'Cartão de crédito',
        'investment' => 'Investimento',
        'digital' => 'Conta digital',
        _ => 'Carteira',
      };
}