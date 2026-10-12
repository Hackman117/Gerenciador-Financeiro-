import 'package:drift/native.dart';
import 'package:finamind/core/utils.dart';
import 'package:finamind/data/database.dart';
import 'package:finamind/data/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  initializeDateFormatting();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('banco novo não tem dados de exemplo', () async {
    expect(await DemoData.isLoaded(db), isFalse);
    expect(await db.getAccounts(), isEmpty);
  });

  test('load cria 5 contas, com uma arquivada e uma padrão', () async {
    await DemoData.load(db);

    final visible = await db.getAccounts();
    expect(visible.length, 4);

    final all = await db.watchAccounts(includeArchived: true).first;
    expect(all.length, 5);
    expect(all.where((a) => a.archived).length, 1);
    expect(all.where((a) => a.isDefault).single.name, 'Conta corrente');
    expect(all.map((a) => a.name), containsAll(['Carteira', 'Poupança', 'Cartão de crédito']));
  });

  test('load cria uma categoria personalizada e deixa outra inativa', () async {
    await DemoData.load(db);

    final categories = await db.getCategories();
    expect(categories.length, 16);
    expect(categories.map((c) => c.name), containsAll(['Alimentação', 'Salário', 'Moradia']));

    /// 'Pets' é personalizada (não é padrão do app).
    final pets = categories.singleWhere((c) => c.name == 'Pets');
    expect(pets.isDefault, isFalse);

    /// 'Educação' fica desligada para mostrar o estado inativo na lista.
    expect(categories.singleWhere((c) => c.name == 'Educação').status, 'inactive');
  });

  test('load gera 357 lançamentos cobrindo 24 meses', () async {
    await DemoData.load(db);

    /// 14 por mês × 24 meses + 7 da padaria + 14 parcelas dos cartões.
    final txs = await db.watchTransactions().first;
    expect(txs.length, 357);

    final months = txs.map((t) => Formats.monthKey(t.date)).toSet();
    final now = DateTime.now();
    for (var back = 0; back < 24; back++) {
      expect(months, contains(Formats.monthKey(DateTime(now.year, now.month - back, 1))));
    }
  });

  test('load cria orçamentos do mês, com um estourado de propósito', () async {
    await DemoData.load(db);

    final now = DateTime.now();
    final budgets = await db.watchBudgets(Formats.monthKey(now)).first;
    expect(budgets.length, 7);
    expect(budgets.fold<int>(0, (s, b) => s + b.limitAmount), 287000);

    /// Restaurantes tem limite de R$ 150 e o gasto do mês passa disso.
    final restaurants = (await db.getCategories()).singleWhere((c) => c.name == 'Restaurantes');
    final spent = await db.spentByCategory(
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
    expect(spent[restaurants.id] ?? 0, greaterThan(15000));

    final previous = await db.watchBudgets(Formats.monthKey(now.subtract(const Duration(days: 31)))).first;
    expect(previous, isEmpty);
  });

  test('load cria 4 metas, uma concluída e uma atrasada', () async {
    await DemoData.load(db);

    final goals = await db.watchGoals().first;
    expect(goals.length, 4);

    final byName = {for (final g in goals) g.name: g};
    expect(byName['Reserva de emergência']!.savedAmount, 800000);
    expect(byName['Viagem para o Nordeste']!.savedAmount, 320000);
    expect(byName['Notebook novo']!.savedAmount, 450000);
    expect(byName['Notebook novo']!.completed, isTrue);
    expect(byName['Reserva de emergência']!.completed, isFalse);
    expect(byName['Reserva de emergência']!.deadline, isNotNull);

    /// O curso passou do prazo e continua em andamento.
    final course = byName['Curso de inglês']!;
    expect(course.savedAmount, 150000);
    expect(course.deadline!.isBefore(DateTime.now()), isTrue);
    expect(course.completed, isFalse);

    final emergency = byName['Reserva de emergência']!;
    expect((await db.watchContributions(emergency.id).first).length, 3);
    final notebook = byName['Notebook novo']!;
    expect((await db.watchContributions(notebook.id).first).length, 1);
  });

  test('load cria 7 recorrentes: vencida, semanal, anual, pausada e manual', () async {
    await DemoData.load(db);

    final rules = await db.watchRecurring().first;
    expect(rules.length, 7);
    expect(rules.where((r) => r.paused).single.description, 'Academia');
    expect(rules.where((r) => !r.autoCreate && !r.paused).single.description, 'Streaming');

    /// A internet está com vencimento no passado, para o alerta laranja.
    final overdue = rules.where((r) => !r.paused && r.nextDueDate.isBefore(DateTime.now()));
    expect(overdue.single.description, 'Internet fibra');

    expect(rules.singleWhere((r) => r.description == 'Faxineira').frequency, 'weekly');
    expect(rules.singleWhere((r) => r.description == 'IPTU (parcela anual)').frequency, 'yearly');
    expect(rules.map((r) => r.description), containsAll(['Salário', 'Aluguel']));
  });

  test('load registra 2 cartões, um desativado, e 3 compras parceladas', () async {
    await DemoData.load(db);

    final cards = await db.getCreditCards();
    expect(cards.length, 2);
    final nubank = cards.singleWhere((c) => c.active);
    expect(nubank.name, 'Cartão Nubank');
    expect(nubank.creditLimit, 500000);
    expect(cards.singleWhere((c) => !c.active).name, 'Cartão Itaú (antigo)');

    final purchases = await db.getPurchases();
    expect(purchases.length, 3);

    final notebook = purchases.singleWhere((p) => p.establishment == 'Notebook Dell');
    expect(notebook.installmentCount, 10);

    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    for (final purchase in purchases) {
      final list = await db.getParcels(purchase.id);
      expect(list.fold<int>(0, (s, p) => s + p.amount), purchase.totalAmount);

      /// Parcelas vencidas chegam quitadas; as futuras seguem em aberto.
      for (final parcel in list) {
        expect(parcel.paid, parcel.dueDate.isBefore(midnight));
      }
    }
    expect((await db.getParcels(notebook.id)).any((p) => p.paid), isTrue);
  });

  test('load grava metas mensais e marca o demo como ativo', () async {
    await DemoData.load(db);

    expect(await db.getSetting('goal_expense'), '350000');
    expect(await db.getSetting('goal_income'), '550000');
    expect(await db.getSetting('goal_savings'), '150000');
    expect(await DemoData.isLoaded(db), isTrue);
  });

  test('dados alimentam todos os gráficos do app', () async {
    await DemoData.load(db);

    final now = DateTime.now();

    /// Semana: gasto em cada um dos últimos 7 dias.
    final week = await db.timeSeries('semana');
    expect(week.length, 7);
    for (final point in week) {
      expect(point.expense, greaterThan(0), reason: 'dia sem gastos');
    }

    /// Ano: todos os meses do último ano têm receita e gasto.
    final year = await db.timeSeries('ano');
    expect(year.length, 13);
    for (final point in year) {
      expect(point.income, greaterThan(0), reason: 'mês sem receita');
      expect(point.expense, greaterThan(0), reason: 'mês sem gastos');
    }

    /// Anos: 5 baldes, o mais antigo vazio e os recentes com movimento.
    final years = await db.timeSeries('anos');
    expect(years.length, 5);
    expect(years.first.expense, 0);
    expect(years.last.label, now.year.toString());
    expect(years.where((p) => p.expense > 0).length, inInclusiveRange(2, 3));

    /// Mês: o mês corrente tem os dois lados do fluxo.
    final month = await db.timeSeries('mes');
    expect(month.fold<int>(0, (s, p) => s + p.expense), greaterThan(0));
    expect(month.fold<int>(0, (s, p) => s + p.income), greaterThan(0));
  });

  test('notas dos lançamentos aparecem na busca', () async {
    await DemoData.load(db);

    final found = await db.watchTransactions(search: 'Thor').first;
    expect(found, isNotEmpty);
    expect(found.first.notes, contains('Thor'));
  });

  test('load é idempotente: recarregar não duplica dados', () async {
    await DemoData.load(db);
    await DemoData.load(db);

    expect((await db.watchTransactions().first).length, 357);
    expect((await db.watchAccounts(includeArchived: true).first).length, 5);
    expect((await db.watchGoals().first).length, 4);
    expect((await db.getCreditCards()).length, 2);
    expect((await db.getPurchases()).length, 3);
  });

  test('saldos ficam coerentes: corrente, poupança e carteira positivas', () async {
    await DemoData.load(db);

    final accounts = await db.watchAccounts(includeArchived: true).first;
    final checking = accounts.singleWhere((a) => a.name == 'Conta corrente');
    final savings = accounts.singleWhere((a) => a.name == 'Poupança');
    final wallet = accounts.singleWhere((a) => a.name == 'Carteira');

    expect(await db.accountBalance(checking.id), greaterThan(0));
    expect(await db.accountBalance(savings.id), greaterThan(0));
    expect(await db.accountBalance(wallet.id), greaterThan(0));
  });

  test('clear apaga o demo e devolve o estado inicial do app', () async {
    await DemoData.load(db);
    await DemoData.clear(db);

    expect(await DemoData.isLoaded(db), isFalse);
    expect(await db.watchTransactions().first, isEmpty);
    expect(await db.watchGoals().first, isEmpty);
    expect(await db.watchRecurring().first, isEmpty);
    expect(await db.watchBudgets(Formats.monthKey(DateTime.now())).first, isEmpty);
    expect(await db.getCreditCards(), isEmpty);
    expect(await db.getPurchases(), isEmpty);

    final accounts = await db.getAccounts();
    expect(accounts.length, 1);
    expect(accounts.single.name, 'Carteira');
    expect(accounts.single.isDefault, isTrue);

    expect((await db.getCategories()).length, 15);
  });

  test('clear em banco novo não quebra e deixa o app usável', () async {
    await DemoData.clear(db);

    expect(await DemoData.isLoaded(db), isFalse);
    final accounts = await db.getAccounts();
    expect(accounts.length, 1);
    expect(accounts.single.name, 'Carteira');
    expect((await db.getCategories()).length, 15);
  });
}
