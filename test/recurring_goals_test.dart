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

  group('proxima data (nextDueDate)', () {
    test('diaria, semanal e anual somam o intervalo', () {
      final from = DateTime(2026, 2, 10);
      expect(db.nextDueDate(frequency: 'daily', interval: 3, from: from), DateTime(2026, 2, 13));
      expect(db.nextDueDate(frequency: 'weekly', interval: 2, from: from), DateTime(2026, 2, 24));
      expect(db.nextDueDate(frequency: 'yearly', interval: 1, from: from), DateTime(2027, 2, 10));
    });

    test('mensal vira o ano quando passa de dezembro', () {
      expect(
        db.nextDueDate(frequency: 'monthly', interval: 1, from: DateTime(2026, 12, 5)),
        DateTime(2027, 1, 5),
      );
      expect(
        db.nextDueDate(frequency: 'monthly', interval: 12, from: DateTime(2026, 3, 31)),
        DateTime(2027, 3, 31),
      );
    });

    test('dia 31 nao transborda para o mes seguinte (mes curto)', () {
      expect(
        db.nextDueDate(frequency: 'monthly', interval: 1, from: DateTime(2026, 1, 31)),
        DateTime(2026, 2, 28),
      );
      expect(
        db.nextDueDate(frequency: 'monthly', interval: 1, from: DateTime(2024, 1, 31)),
        DateTime(2024, 2, 29),
      );
    });

    test('frequencia desconhecida cai no comportamento mensal', () {
      expect(
        db.nextDueDate(frequency: 'quinzenal', interval: 1, from: DateTime(2026, 5, 10)),
        DateTime(2026, 6, 10),
      );
    });
  });

  group('recorrentes', () {
    test('advanceRecurring joga a data para frente sem pausar', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      final id = await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        nextDue: DateTime(2026, 1, 10),
      );

      await db.advanceRecurring(id);
      var rule = (await db.watchRecurring().first).single;
      expect(rule.nextDueDate, DateTime(2026, 2, 10));
      expect(rule.paused, isFalse);

      await db.advanceRecurring(id);
      rule = (await db.watchRecurring().first).single;
      expect(rule.nextDueDate, DateTime(2026, 3, 10));
    });

    test('advanceRecurring pausa a regra quando passa do endDate', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      final id = await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        nextDue: DateTime(2026, 1, 10),
        endDate: DateTime(2026, 2, 1),
      );

      await db.advanceRecurring(id);
      final rule = (await db.watchRecurring().first).single;
      expect(rule.nextDueDate, DateTime(2026, 2, 10));
      expect(rule.paused, isTrue);
    });

    test('advanceRecurring em id inexistente nao faz nada', () async {
      await db.advanceRecurring('fantasma');
      expect(await db.watchRecurring().first, isEmpty);
    });

    test('dueRecurring traz so o que venceu (fora pausado, manual e apagado)', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      final due = await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        nextDue: DateTime(2026, 10, 1),
        id: 'r-venceu',
      );
      await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        nextDue: DateTime(2026, 10, 20),
        id: 'r-futuro',
      );
      await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        nextDue: DateTime(2026, 9, 1),
        paused: true,
        id: 'r-pausado',
      );
      await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        nextDue: DateTime(2026, 9, 1),
        autoCreate: false,
        id: 'r-manual',
      );
      final deleted = await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        nextDue: DateTime(2026, 9, 1),
        id: 'r-apagado',
      );
      await db.softDelete('recurring_rules', deleted);

      final ids = (await db.dueRecurring(on: DateTime(2026, 10, 11, 15))).map((r) => r.id).toList();
      expect(ids, [due]);
    });

    test('dueRecurring inclui o proprio dia ate as 23:59', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      await seedRecurring(
        db,
        accountId: a,
        type: kIncome,
        amount: 5000,
        nextDue: DateTime(2026, 10, 11, 8),
      );
      expect(await db.dueRecurring(on: DateTime(2026, 10, 11, 23, 59)), hasLength(1));
    });
  });

  group('janela de proximos vencimentos', () {
    test('upcomingRecurring respeita os dias e ignora pausados e atrasados', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      final now = DateTime.now();
      final today9 = DateTime(now.year, now.month, now.day, 9);
      final soon = await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        nextDue: today9.add(const Duration(days: 5)),
        id: 'r-soon',
      );
      await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        nextDue: today9.add(const Duration(days: 60)),
        id: 'r-longe',
      );
      await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        nextDue: today9.subtract(const Duration(days: 5)),
        id: 'r-atrasado',
      );
      await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 100,
        nextDue: today9.add(const Duration(days: 5)),
        paused: true,
        id: 'r-pausado',
      );

      expect((await db.upcomingRecurring(days: 30)).map((r) => r.id).toList(), [soon]);
      expect(await db.upcomingRecurring(days: 3), isEmpty);
    });

    test('projectedDeltaUntil subtrai gastos e soma receitas ate a data', () async {
      final a = await seedAccount(db, id: 'a', name: 'A');
      await seedRecurring(
        db,
        accountId: a,
        type: kIncome,
        amount: 50000,
        nextDue: DateTime(2026, 10, 20),
      );
      await seedRecurring(db, accountId: a, type: kExpense, amount: 12000, nextDue: DateTime(2026, 10, 25));
      await seedRecurring(db, accountId: a, type: kExpense, amount: 9000, nextDue: DateTime(2026, 12, 5));
      await seedRecurring(
        db,
        accountId: a,
        type: kExpense,
        amount: 99000,
        nextDue: DateTime(2026, 10, 5),
        paused: true,
      );

      expect(await db.projectedDeltaUntil(until: endOfDay(DateTime(2026, 10, 31))), 38000);
      expect(await db.projectedDeltaUntil(until: endOfDay(DateTime(2026, 12, 31))), 29000);
    });
  });

  group('orcamentos', () {
    test('watchBudgets mostra apenas o mes pedido e atualiza pelo mesmo id', () async {
      final food = await seedCategory(db, 'Alimentacao');
      final home = await seedCategory(db, 'Casa');
      await db.upsertBudget(
        BudgetsCompanion.insert(id: 'b1', categoryId: food, month: '2026-10', limitAmount: 80000),
        id: 'b1',
      );
      await db.upsertBudget(
        BudgetsCompanion.insert(id: 'b2', categoryId: home, month: '2026-11', limitAmount: 40000),
        id: 'b2',
      );

      final oct = await db.watchBudgets('2026-10').first;
      expect(oct.map((b) => b.id).toList(), ['b1']);
      expect(oct.single.limitAmount, 80000);
      expect(await db.watchBudgets('2026-12').first, isEmpty);

      await db.upsertBudget(
        BudgetsCompanion.insert(id: 'b1', categoryId: food, month: '2026-10', limitAmount: 90000),
        id: 'b1',
      );
      final again = await db.watchBudgets('2026-10').first;
      expect(again, hasLength(1));
      expect(again.single.limitAmount, 90000);

      await db.softDelete('budgets', 'b2');
      expect(await db.watchBudgets('2026-11').first, isEmpty);
    });
  });

  group('metas', () {
    test('contribuicoes somam em savedAmount e completam a meta no alvo', () async {
      final goal = await seedGoal(db, name: 'Reserva', target: 10000);
      await db.addContribution(goalId: goal, amount: 4000, note: 'primeira');
      var g = (await db.watchGoals().first).single;
      expect(g.savedAmount, 4000);
      expect(g.completed, isFalse);

      await db.addContribution(goalId: goal, amount: 6000, note: 'segunda');
      g = (await db.watchGoals().first).single;
      expect(g.savedAmount, 10000);
      expect(g.completed, isTrue);

      await db.addContribution(goalId: goal, amount: 2500, note: 'extra');
      g = (await db.watchGoals().first).single;
      expect(g.savedAmount, 12500);
      expect(g.completed, isTrue);
    });

    test('remover contribuicao recalcula e reabre a meta', () async {
      final goal = await seedGoal(db, name: 'Viagem', target: 5000);
      await db.addContribution(goalId: goal, amount: 3000, note: 'a');
      final primeira = await db.watchContributions(goal).first;
      await db.addContribution(goalId: goal, amount: 2000, note: 'b');

      await db.removeContribution(primeira.single.id);
      var g = (await db.watchGoals().first).single;
      expect(g.savedAmount, 2000);
      expect(g.completed, isFalse);

      final restantes = await db.watchContributions(goal).first;
      expect(restantes.map((c) => c.note).toList(), ['b']);

      await db.removeContribution('nao-existe');
      expect((await db.watchGoals().first).single.savedAmount, 2000);
    });

    test('contribuicoes vem da mais nova para a mais antiga', () async {
      final goal = await seedGoal(db, name: 'Notebook', target: 60000);
      await db.addContribution(goalId: goal, amount: 1000, note: 'antiga');
      await db.addContribution(goalId: goal, amount: 2000, note: 'nova');

      final registro = (await db.watchContributions(goal).first).firstWhere((c) => c.note == 'antiga');
      await (db.update(db.goalContributions)..where((t) => t.id.equals(registro.id)))
          .write(GoalContributionsCompanion(date: Value(DateTime(2026, 1, 1))));

      expect((await db.watchContributions(goal).first).map((c) => c.note).toList(), ['nova', 'antiga']);
    });

    test('watchGoals mantem incompletas na frente das concluidas', () async {
      final first = await seedGoal(db, name: 'Primeira', target: 1000, id: 'g-first');
      await db.addContribution(goalId: first, amount: 1000, note: 'ok');
      final second = await seedGoal(db, name: 'Segunda', target: 1000, id: 'g-second');

      expect((await db.watchGoals().first).map((g) => g.id).toList(), [second, first]);
    });

    test('soft delete esconde a meta mas preserva as contribuicoes', () async {
      final goal = await seedGoal(db, name: 'Sumico', target: 1000);
      await db.addContribution(goalId: goal, amount: 500, note: 'guardada');
      await db.softDelete('goals', goal);
      expect(await db.watchGoals().first, isEmpty);
      expect(await db.watchContributions(goal).first, hasLength(1));

      await db.restoreRow('goals', goal);
      final g = (await db.watchGoals().first).single;
      expect(g.id, goal);
      expect(g.savedAmount, 500);
    });

    test('upsertGoal no mesmo id atualiza alvo sem dobrar o salvo', () async {
      final goal = await seedGoal(db, name: 'Fundo', target: 10000, id: 'g1');
      await db.addContribution(goalId: goal, amount: 4000, note: 'x');
      await db.upsertGoal(
        GoalsCompanion.insert(id: goal, name: 'Fundo de emergência', targetAmount: 20000),
        id: goal,
      );
      final g = (await db.watchGoals().first).single;
      expect(g.name, 'Fundo de emergência');
      expect(g.targetAmount, 20000);
      expect(g.savedAmount, 4000);
      expect(g.completed, isFalse);
    });
  });
}
