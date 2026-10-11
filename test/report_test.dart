import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:finamind/core/utils.dart';
import 'package:finamind/data/database.dart';
import 'package:finamind/data/report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/seed.dart';

/// PNG 1x1 valido: o servico de PDF so precisa decodificar o cabecalho.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Referencia fixa para nao depender do dia em que o teste roda.
final DateTime _ref = DateTime(2026, 10, 11, 14, 30);

ReportData _empty({ReportPeriod period = ReportPeriod.month}) => ReportData(
      period: period,
      start: period.start(_ref),
      now: _ref,
      income: 0,
      expense: 0,
      balance: 0,
      largestExpense: 0,
      dailyAverage: 0,
      expensesByCategory: const [],
      incomeByCategory: const [],
      categories: const {},
      trend: const [],
      accounts: const [],
      transactions: const [],
      accountsCount: 0,
    );

ReportData _totals({required int income, required int expense}) => ReportData(
      period: ReportPeriod.month,
      start: ReportPeriod.month.start(_ref),
      now: _ref,
      income: income,
      expense: expense,
      balance: income - expense,
      largestExpense: 0,
      dailyAverage: 0,
      expensesByCategory: const [],
      incomeByCategory: const [],
      categories: const {},
      trend: const [],
      accounts: const [],
      transactions: const [],
      accountsCount: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDateFormatting);

  group('periodos do relatorio', () {
    test('labels curtos para os chips', () {
      expect(ReportPeriod.week.label, 'Semana');
      expect(ReportPeriod.month.label, 'Mês');
      expect(ReportPeriod.sixMonths.label, '6 meses');
      expect(ReportPeriod.year.label, '1 ano');
      expect(ReportPeriod.all.label, 'Todos os anos');
    });

    test('start marca o primeiro dia correto de cada periodo', () {
      expect(ReportPeriod.week.start(_ref), DateTime(2026, 10, 5));
      expect(ReportPeriod.month.start(_ref), DateTime(2026, 10, 1));
      expect(ReportPeriod.sixMonths.start(_ref), DateTime(2026, 5, 1));
      expect(ReportPeriod.year.start(_ref), DateTime(2025, 10, 1));
      expect(ReportPeriod.all.start(_ref), DateTime(2000, 1, 1));
    });

    test('start nunca carrega a hora do dia (comeca em midnight)', () {
      for (final p in ReportPeriod.values) {
        final s = p.start(_ref);
        expect(s.hour, 0);
        expect(s.minute, 0);
        expect(s.isAfter(p.end(_ref)), isFalse);
      }
    });

    test('end e o ultimo instante do periodo (inclusivo)', () {
      expect(ReportPeriod.week.end(_ref), endOfDay(_ref));
      expect(ReportPeriod.month.end(_ref), endOfDay(DateTime(2026, 10, 31)));
      expect(ReportPeriod.sixMonths.end(_ref), endOfDay(DateTime(2026, 10, 31)));
      expect(ReportPeriod.year.end(_ref), endOfDay(DateTime(2026, 10, 31)));
      expect(ReportPeriod.all.end(_ref), endOfDay(DateTime(2026, 10, 31)));

      final e = ReportPeriod.month.end(_ref);
      expect(e.hour, 23);
      expect(e.minute, 59);
      expect(e.day, 31);
    });

    test('end de fevereiro considera ano bissexto', () {
      expect(ReportPeriod.month.end(DateTime(2026, 2, 9)), endOfDay(DateTime(2026, 2, 28)));
      expect(ReportPeriod.month.end(DateTime(2024, 2, 9)), endOfDay(DateTime(2024, 2, 29)));
      expect(ReportPeriod.month.end(DateTime(2026, 12, 9)), endOfDay(DateTime(2026, 12, 31)));
    });

    test('subtitle traz o texto humanizado de cada periodo', () {
      expect(ReportPeriod.month.subtitle(_ref, ReportPeriod.month.start(_ref)), 'Outubro 2026');
      expect(ReportPeriod.year.subtitle(_ref, ReportPeriod.year.start(_ref)), 'Outubro 2025');
      expect(ReportPeriod.all.subtitle(_ref, ReportPeriod.all.start(_ref)), 'Desde 2000');

      final week = ReportPeriod.week.subtitle(_ref, ReportPeriod.week.start(_ref));
      expect(week, contains('05/10/2026'));
      expect(week, contains('11/10/2026'));

      final six = ReportPeriod.sixMonths.subtitle(_ref, ReportPeriod.sixMonths.start(_ref));
      expect(six, contains('Maio 2026'));
      expect(six, contains('Outubro 2026'));
    });
  });

  group('numeros do relatorio', () {
    test('savings e a diferenca entre receita e despesa', () {
      expect(_totals(income: 100000, expense: 40000).savings, 60000);
      expect(_totals(income: 30000, expense: 50000).savings, -20000);
    });

    test('savingsRate vira 0 quando nao ha receita', () {
      expect(_totals(income: 0, expense: 5000).savingsRate, 0);
    });

    test('savingsRate fica entre 0 e 1 (gastar mais nao vira percentual negativo)', () {
      expect(_totals(income: 100000, expense: 40000).savingsRate, 0.6);
      expect(_totals(income: 100000, expense: 100000).savingsRate, 0);
      expect(_totals(income: 10000, expense: 99999).savingsRate, 0);
      expect(_totals(income: 100000, expense: 1).savingsRate, closeTo(1, 0.001));
    });
  });

  group('geracao do PDF', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<ReportData> buildData(ReportPeriod period) async {
      final start = period.start(_ref);
      final end = period.end(_ref);
      final transactions = await db.watchTransactions(from: start, to: end, limit: 15).first;
      final categories = await db.getCategories();
      final accounts = await db.getAccounts();
      return ReportData(
        period: period,
        start: start,
        now: _ref,
        income: await db.sumByType(kIncome, from: start, to: end),
        expense: await db.sumByType(kExpense, from: start, to: end),
        balance: await db.totalBalance(),
        largestExpense: await db.maxAmountByType(kExpense, from: start, to: end),
        dailyAverage: 12345,
        expensesByCategory: await db.categoryBreakdown(kExpense, from: start, to: end),
        incomeByCategory: await db.categoryBreakdown(kIncome, from: start, to: end),
        categories: {for (final c in categories) c.id: c},
        trend: const [],
        accounts: accounts,
        transactions: transactions,
        accountsCount: accounts.length,
      );
    }

    test('com dados: comeca com a assinatura %PDF e tem tamanho util', () async {
      final a = await seedAccount(db, id: 'a', name: 'Conta corrente', type: 'checking', initialBalance: 150000);
      final b = await seedAccount(db, id: 'b', name: 'Dinheiro', type: 'cash', archived: true);
      final food = await seedCategory(db, 'Alimentacao');
      await seedTx(
        db,
        accountId: a,
        type: kExpense,
        amount: 8990,
        categoryId: food,
        description: 'Mercado do mes',
        date: DateTime(2026, 10, 3, 12),
      );
      await seedTx(db, accountId: a, type: kExpense, amount: 4500, date: DateTime(2026, 10, 4));
      await seedTx(db, accountId: a, type: kIncome, amount: 350000, description: 'Salario', date: DateTime(2026, 10, 5));
      await seedTx(db, accountId: a, type: kTransfer, amount: 1000, toAccountId: b, date: DateTime(2026, 10, 6));

      final data = await buildData(ReportPeriod.month);
      expect(data.income, 350000);
      expect(data.expense, 13490);
      expect(data.largestExpense, 8990);
      expect(data.expensesByCategory.map((e) => e.categoryId).toSet(), {food, 'sem-categoria'});

      final bytes = await ReportService.buildPdf(data, pieImage: _png, trendImage: _png);
      expect(bytes, isA<Uint8List>());
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    });

    test('sem dados: gera um PDF valido em vez de estourar tabela vazia', () async {
      final bytes = await ReportService.buildPdf(_empty(), pieImage: _png, trendImage: _png);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('todos os periodos geram PDF (cada um usa um formato de data diferente)', () async {
      final a = await seedAccount(db, id: 'a', name: 'Carteira');
      await seedTx(db, accountId: a, type: kExpense, amount: 1000, date: DateTime(2026, 10, 8));
      await seedTx(db, accountId: a, type: kIncome, amount: 2000, date: DateTime(2024, 3, 4));

      for (final period in ReportPeriod.values) {
        final data = await buildData(period);
        final bytes = await ReportService.buildPdf(data, pieImage: _png, trendImage: _png);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: period.label);
      }
    });
  });
}
