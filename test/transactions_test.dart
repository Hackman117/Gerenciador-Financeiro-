import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:finamind/core/utils.dart';
import 'package:finamind/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/seed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDateFormatting);

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<Tx>> list({
    DateTime? from,
    DateTime? to,
    String? type,
    String? accountId,
    String? categoryId,
    String? search,
    int limit = 500,
  }) =>
      db
          .watchTransactions(
            from: from,
            to: to,
            type: type,
            accountId: accountId,
            categoryId: categoryId,
            search: search,
            limit: limit,
          )
          .first;

  group('saldo', () {
    test('receita soma, despesa subtrai (valores em centavos)', () async {
      final acc = await seedAccount(db, initialBalance: 10000);
      await seedTx(db, accountId: acc, type: kIncome, amount: 5000);
      await seedTx(db, accountId: acc, type: kExpense, amount: 3000);
      expect(await db.accountBalance(acc), 12000);
    });

    test('transferencia sai de uma conta, entra na outra e nao cria dinheiro', () async {
      final a = await seedAccount(db, id: 'a', name: 'A', initialBalance: 20000);
      final b = await seedAccount(db, id: 'b', name: 'B');
      await seedTx(db, accountId: a, type: kTransfer, amount: 7500, toAccountId: b);
      expect(await db.accountBalance(a), 12500);
      expect(await db.accountBalance(b), 7500);
      expect(await db.totalBalance(), 20000);
    });

    test('conta fora do total nao entra no totalBalance', () async {
      await seedAccount(db, id: 'a', name: 'A', initialBalance: 1000);
      await seedAccount(db, id: 'x', name: 'X', initialBalance: 99999, includeInTotal: false);
      expect(await db.totalBalance(), 1000);
    });

    test('conta arquivada some da lista e do total mas preserva o saldo', () async {
      final a = await seedAccount(db, id: 'a', name: 'A', initialBalance: 5000);
      await seedTx(db, accountId: a, type: kExpense, amount: 2000);
      expect(await db.accountBalance(a), 3000);

      await db.setAccountArchived(a, archived: true);
      expect(await db.getAccounts(), isEmpty);
      expect(await db.totalBalance(), 0);
      expect(await db.accountBalance(a), 3000);
      expect(await db.watchAccounts(includeArchived: true).first, hasLength(1));
    });

    test('until corta o saldo na data (so o que ja aconteceu)', () async {
      final a = await seedAccount(db, id: 'a', name: 'A', initialBalance: 1000);
      await seedTx(db, accountId: a, type: kIncome, amount: 400, date: DateTime(2026, 3, 10));
      await seedTx(db, accountId: a, type: kIncome, amount: 900, date: DateTime(2026, 6, 10));
      expect(await db.accountBalance(a, until: DateTime(2026, 4, 1)), 1400);
      expect(await db.accountBalance(a), 2300);
    });

    test('conta inexistente devolve saldo zero em vez de estourar', () async {
      expect(await db.accountBalance('nao-existe'), 0);
    });
  });

  group('contas', () {
    test('upsert com o mesmo id atualiza em vez de duplicar', () async {
      await seedAccount(db, id: 'a', name: 'Carteira', initialBalance: 100);
      await db.upsertAccount(
        AccountsCompanion.insert(id: 'a', name: 'Nova Carteira', initialBalance: const Value(900)),
        id: 'a',
      );
      final all = await db.getAccounts();
      expect(all, hasLength(1));
      expect(all.single.name, 'Nova Carteira');
      expect(await db.accountBalance('a'), 900);
    });

    test('setDefaultAccount move o marcador (sempre uma so)', () async {
      final a = await seedAccount(db, id: 'a', name: 'A', isDefault: true);
      final b = await seedAccount(db, id: 'b', name: 'B');
      expect((await db.defaultAccount())?.id, a);

      await db.setDefaultAccount(b);
      expect((await db.defaultAccount())?.id, b);
      final marcadas = (await db.getAccounts()).where((x) => x.isDefault).toList();
      expect(marcadas, hasLength(1));
    });

    test('padrao arquivada deixa de ser devolvida', () async {
      final a = await seedAccount(db, id: 'a', name: 'A', isDefault: true);
      await db.setAccountArchived(a, archived: true);
      expect(await db.defaultAccount(), isNull);
    });
  });

  group('lixeira (soft delete)', () {
    test('apagar tira do saldo e da lista, restaurar traz de volta', () async {
      final a = await seedAccount(db, id: 'a', name: 'A', initialBalance: 10000);
      final tx = await seedTx(db, accountId: a, type: kExpense, amount: 2500);
      expect(await db.accountBalance(a), 7500);

      await db.softDelete('transactions', tx);
      expect(await db.accountBalance(a), 10000);
      expect(await list(), isEmpty);
      expect((await db.watchDeletedTransactions().first).map((t) => t.id).toList(), [tx]);

      await db.restoreRow('transactions', tx);
      expect(await db.accountBalance(a), 7500);
      expect(await db.watchDeletedTransactions().first, isEmpty);

      await db.softDelete('transactions', tx);
      await db.purgeRow('transactions', tx);
      expect(await db.accountBalance(a), 10000);
      expect(await db.watchDeletedTransactions().first, isEmpty);
    });

    test('upsert numa linha apagada nao reativa o lancamento', () async {
      final a = await seedAccount(db, id: 'a', name: 'A', initialBalance: 0);
      final tx = await seedTx(db, accountId: a, type: kIncome, amount: 800);
      await db.softDelete('transactions', tx);
      expect(await db.accountBalance(a), 0);

      await db.upsertTransaction(
        TransactionsCompanion.insert(
          id: tx,
          accountId: a,
          type: kIncome,
          amount: 800,
          date: DateTime(2026, 1, 1),
        ),
        id: tx,
      );
      expect(await db.accountBalance(a), 0);
      expect(await list(), isEmpty);
    });
  });

  group('filtros de listagem', () {
    test('busca em descricao e notas, sem diferenciar maiusculas', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      await seedTx(db, accountId: a, type: kExpense, amount: 100, description: 'Supermercado X');
      await seedTx(db, accountId: a, type: kExpense, amount: 200, description: 'Farmacia', notes: 'conta do mercado');
      await seedTx(db, accountId: a, type: kExpense, amount: 300, description: 'Uber');

      expect(await list(search: 'SUPER'), hasLength(1));
      expect(await list(search: 'mercado'), hasLength(2));
      expect(await list(search: 'conta'), hasLength(1));
      expect(await list(search: 'ubER'), hasLength(1));
      expect(await list(search: ''), hasLength(3));
      expect(await list(search: '   '), hasLength(3));
      expect(await list(search: 'inexistente'), isEmpty);
    });

    test('fim do periodo e inclusivo com endOfDay, midnight perde o ultimo dia', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      await seedTx(db, accountId: a, type: kExpense, amount: 100, date: DateTime(2026, 2, 28, 18, 30));
      await seedTx(db, accountId: a, type: kExpense, amount: 200, date: DateTime(2026, 3, 15, 9));

      expect(await list(from: DateTime(2026, 2, 1), to: endOfDay(DateTime(2026, 2, 28))), hasLength(1));
      expect(await list(from: DateTime(2026, 2, 1), to: DateTime(2026, 2, 28)), isEmpty);
    });

    test('ordena por data decrescente e respeita o limite', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      for (var i = 1; i <= 5; i++) {
        await seedTx(
          db,
          accountId: a,
          type: kExpense,
          amount: i * 100,
          date: DateTime(2026, 1, i),
          id: 'tx$i',
        );
      }
      expect((await list()).map((t) => t.id).toList(), ['tx5', 'tx4', 'tx3', 'tx2', 'tx1']);
      expect(await list(limit: 2), hasLength(2));
    });

    test('filtros por tipo, conta e categoria combinam', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      final b = await seedAccount(db, id: 'b', name: 'B');
      final food = await seedCategory(db, 'Alimentacao');
      await seedTx(db, accountId: a, type: kExpense, amount: 100, categoryId: food);
      await seedTx(db, accountId: b, type: kIncome, amount: 900);

      expect(await list(type: kExpense), hasLength(1));
      expect(await list(accountId: b), hasLength(1));
      expect(await list(categoryId: food), hasLength(1));
      expect(await list(categoryId: await seedCategory(db, 'Lazer')), isEmpty);
      expect(await list(type: kExpense, accountId: b), isEmpty);
    });
  });

  group('agregacoes para dashboard e relatorios', () {
    test('categoryBreakdown soma, ordena por valor e junta sem categoria', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      final food = await seedCategory(db, 'Alimentacao');
      final home = await seedCategory(db, 'Casa');
      await seedTx(db, accountId: a, type: kExpense, amount: 300, categoryId: food);
      await seedTx(db, accountId: a, type: kExpense, amount: 700, categoryId: food);
      await seedTx(db, accountId: a, type: kExpense, amount: 400, categoryId: home);
      await seedTx(db, accountId: a, type: kExpense, amount: 50);
      await seedTx(db, accountId: a, type: kIncome, amount: 5000);

      final out = await db.categoryBreakdown(kExpense);
      expect(out.map((e) => e.categoryId).toList(), [food, home, 'sem-categoria']);
      expect(out.map((e) => e.amount).toList(), [1000, 400, 50]);
      expect(await db.categoryBreakdown(kIncome), hasLength(1));
    });

    test('maxAmountByType respeita o periodo e ignora apagados', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      await seedTx(db, accountId: a, type: kExpense, amount: 150, date: DateTime(2026, 1, 5), id: 'm1');
      await seedTx(db, accountId: a, type: kExpense, amount: 900, date: DateTime(2026, 6, 5));
      await seedTx(db, accountId: a, type: kIncome, amount: 99999);

      expect(await db.maxAmountByType(kExpense), 900);
      expect(await db.maxAmountByType(kIncome), 99999);
      expect(
        await db.maxAmountByType(kExpense, from: DateTime(2026, 1, 1), to: endOfDay(DateTime(2026, 1, 31))),
        150,
      );
      expect(await db.maxAmountByType(kExpense, from: DateTime(2027, 1, 1)), 0);
      expect(await db.maxAmountByType('transfer'), 0);

      await db.softDelete('transactions', 'm1');
      expect(
        await db.maxAmountByType(kExpense, from: DateTime(2026, 1, 1), to: endOfDay(DateTime(2026, 1, 31))),
        0,
      );
    });

    test('sumByType e spentByCategory usam periodo inclusivo', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      final food = await seedCategory(db, 'Alimentacao');
      await seedTx(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        categoryId: food,
        date: DateTime(2026, 5, 31, 23, 59),
      );
      await seedTx(db, accountId: a, type: kExpense, amount: 200, categoryId: food, date: DateTime(2026, 6, 1));

      final from = DateTime(2026, 5, 1);
      final to = endOfDay(DateTime(2026, 5, 31));
      expect(await db.sumByType(kExpense, from: from, to: to), 100);
      expect((await db.spentByCategory(from: from, to: to))[food], 100);
      expect(await db.sumByType(kIncome, from: from, to: to), 0);
    });

    test('recentDescriptions agrupa, ordena por recencia e ignora vazio', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      await seedTx(db, accountId: a, type: kExpense, amount: 10, description: 'Mercado', date: DateTime(2026, 1, 1));
      await seedTx(db, accountId: a, type: kExpense, amount: 10, description: 'Mercado', date: DateTime(2026, 3, 1));
      await seedTx(db, accountId: a, type: kExpense, amount: 10, description: 'Farmacia', date: DateTime(2026, 2, 1));
      await seedTx(db, accountId: a, type: kExpense, amount: 10, description: '', date: DateTime(2026, 4, 1));
      await seedTx(db, accountId: a, type: kIncome, amount: 10, description: 'Salario', date: DateTime(2026, 5, 1));

      expect(await db.recentDescriptions(kExpense), ['Mercado', 'Farmacia']);
      expect(await db.recentDescriptions(kIncome), ['Salario']);
      expect(await db.recentDescriptions(kExpense, limit: 1), ['Mercado']);
      expect(await db.recentDescriptions('transfer'), isEmpty);
    });

    test('monthlySummary agrupa por mes no formato yyyy-MM', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      final now = DateTime.now();
      final prev = DateTime(now.year, now.month - 1, 15);
      await seedTx(db, accountId: a, type: kIncome, amount: 1000, date: prev);
      await seedTx(db, accountId: a, type: kExpense, amount: 400, date: prev);
      await seedTx(db, accountId: a, type: kExpense, amount: 600, date: DateTime(now.year, now.month, 1, 8));

      final out = await db.monthlySummary(3);
      expect(out.map((m) => m.month).toList(), [Formats.monthKey(prev), Formats.monthKey(now)]);
      expect(out.first.income, 1000);
      expect(out.first.expense, 400);
      expect(out.last.income, 0);
      expect(out.last.expense, 600);
    });

    test('timeSeries por dia preenche todo o mes, inclusive dias zerados', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      final now = DateTime.now();
      await seedTx(db, accountId: a, type: kExpense, amount: 700, date: DateTime(now.year, now.month, 1, 8));

      final out = await db.timeSeries('mes');
      final days = DateTime(now.year, now.month + 1, 0).day;
      expect(out, hasLength(days));
      expect(out.first.label, '1');
      expect(out.first.expense, 700);
      expect(out.last.income, 0);
      expect(out.last.expense, 0);
    });

    test('timeSeries por ano agrupa por ano', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      final now = DateTime.now();
      await seedTx(db, accountId: a, type: kIncome, amount: 100000, date: DateTime(now.year - 1, 6, 10));
      await seedTx(db, accountId: a, type: kExpense, amount: 20000, date: DateTime(now.year, 1, 10));

      final out = await db.timeSeries('anos');
      expect(out.map((e) => e.label).toList(),
          [for (var y = now.year - 4; y <= now.year; y++) '$y']);
      expect(out.last.income, 0);
      expect(out.last.expense, 20000);
      expect(out.first.expense, 0);
    });
  });
}
