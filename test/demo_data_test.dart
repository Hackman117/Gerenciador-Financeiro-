import 'package:drift/native.dart';
import 'package:finamind/core/utils.dart';
import 'package:finamind/data/database.dart';
import 'package:finamind/data/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('load mantém as categorias padrão do app', () async {
    await DemoData.load(db);

    final categories = await db.getCategories();
    expect(categories.length, 15);
    expect(categories.map((c) => c.name), containsAll(['Alimentação', 'Salário', 'Moradia']));
  });

  test('load gera 86 lançamentos cobrindo 6 meses', () async {
    await DemoData.load(db);

    /// 72 lançamentos fixos (12 por mês) + 14 parcelas das compras do cartão.
    final txs = await db.watchTransactions().first;
    expect(txs.length, 86);

    final months = txs.map((t) => Formats.monthKey(t.date)).toSet();
    final now = DateTime.now();
    for (var back = 0; back < 6; back++) {
      expect(months, contains(Formats.monthKey(DateTime(now.year, now.month - back, 1))));
    }
  });

  test('load cria orçamentos apenas para o mês atual', () async {
    await DemoData.load(db);

    final budgets = await db.watchBudgets(Formats.monthKey(DateTime.now())).first;
    expect(budgets.length, 5);
    expect(budgets.fold<int>(0, (s, b) => s + b.limitAmount), 250000);

    final previous = await db.watchBudgets(Formats.monthKey(DateTime.now().subtract(const Duration(days: 31)))).first;
    expect(previous, isEmpty);
  });

  test('load cria 3 metas com contribuições, uma concluída', () async {
    await DemoData.load(db);

    final goals = await db.watchGoals().first;
    expect(goals.length, 3);

    final byName = {for (final g in goals) g.name: g};
    expect(byName['Reserva de emergência']!.savedAmount, 800000);
    expect(byName['Viagem para o Nordeste']!.savedAmount, 320000);
    expect(byName['Notebook novo']!.savedAmount, 450000);
    expect(byName['Notebook novo']!.completed, isTrue);
    expect(byName['Reserva de emergência']!.completed, isFalse);
    expect(byName['Reserva de emergência']!.deadline, isNotNull);

    final emergency = byName['Reserva de emergência']!;
    expect((await db.watchContributions(emergency.id).first).length, 3);
    final notebook = byName['Notebook novo']!;
    expect((await db.watchContributions(notebook.id).first).length, 1);
  });

  test('load cria 5 recorrentes, uma pausada e uma manual', () async {
    await DemoData.load(db);

    final rules = await db.watchRecurring().first;
    expect(rules.length, 5);
    expect(rules.where((r) => r.paused).single.description, 'Academia');
    expect(rules.where((r) => !r.autoCreate).single.description, 'Streaming');
    expect(rules.map((r) => r.description), containsAll(['Salário', 'Aluguel']));
  });

  test('load registra cartão e 3 compras parceladas', () async {
    await DemoData.load(db);

    final cards = await db.getCreditCards();
    expect(cards.single.name, 'Cartão Nubank');
    expect(cards.single.creditLimit, 500000);

    final purchases = await db.getPurchases();
    expect(purchases.length, 3);

    final notebook = purchases.singleWhere((p) => p.establishment == 'Notebook Dell');
    expect(notebook.installmentCount, 10);

    final parcels = await db.getParcels(notebook.id);
    expect(parcels.length, 10);
    expect(parcels.fold<int>(0, (s, p) => s + p.amount), notebook.totalAmount);

    for (final purchase in purchases) {
      final list = await db.getParcels(purchase.id);
      expect(list.fold<int>(0, (s, p) => s + p.amount), purchase.totalAmount);
    }
  });

  test('load grava metas mensais e marca o demo como ativo', () async {
    await DemoData.load(db);

    expect(await db.getSetting('goal_expense'), '350000');
    expect(await db.getSetting('goal_income'), '550000');
    expect(await db.getSetting('goal_savings'), '150000');
    expect(await DemoData.isLoaded(db), isTrue);
  });

  test('load é idempotente: recarregar não duplica dados', () async {
    await DemoData.load(db);
    await DemoData.load(db);

    expect((await db.watchTransactions().first).length, 86);
    expect((await db.watchAccounts(includeArchived: true).first).length, 5);
    expect((await db.watchGoals().first).length, 3);
    expect((await db.getCreditCards()).length, 1);
    expect((await db.getPurchases()).length, 3);
  });

  test('saldos ficam coerentes: corrente e poupança positivas', () async {
    await DemoData.load(db);

    final accounts = await db.watchAccounts(includeArchived: true).first;
    final checking = accounts.singleWhere((a) => a.name == 'Conta corrente');
    final savings = accounts.singleWhere((a) => a.name == 'Poupança');

    expect(await db.accountBalance(checking.id), greaterThan(0));
    expect(await db.accountBalance(savings.id), greaterThan(0));
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
