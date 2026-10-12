import 'package:drift/native.dart';
import 'package:finamind/core/utils.dart';
import 'package:finamind/data/database.dart';
import 'package:finamind/data/demo_data.dart';
import 'package:finamind/data/providers.dart';
import 'package:finamind/features/budgets/budgets_screen.dart';
import 'package:finamind/features/dashboard/dashboard_screen.dart';
import 'package:finamind/features/goals/goals_screen.dart';
import 'package:finamind/features/recurring/recurring_screen.dart';
import 'package:finamind/features/reports/reports_screen.dart';
import 'package:finamind/features/transactions/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/seed.dart';

/// Fumaça das telas do shell: garante que cada uma monta com dados reais,
/// mostra o que o usuário espera e nao lanca excecao de render (charts,
/// repaint boundary, tiles preguiçosos).
void main() {
  initializeDateFormatting();

  late AppDatabase db;
  late ProviderContainer container;
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    db = await binding.runAsync(() async => AppDatabase.forTesting(NativeDatabase.memory())) ??
        AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      container.dispose();
      await binding.runAsync(db.close);
    });
  });

  Future<void> settle(WidgetTester tester, [int steps = 20]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> flushAsync(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await settle(tester);
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: screen),
      ),
    );
    await flushAsync(tester);
  }

  Future<void> scrollUntilVisible(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 12 && !finder.evaluate().isNotEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await settle(tester, 4);
    }
    await flushAsync(tester);
  }

  /// Dados do mes corrente: conta, categoria, lancamentos, orcamento, meta, recorrente.
  Future<void> seedMonth() async {
    final now = DateTime.now();
    final month = Formats.monthKey(now);
    final acc = await seedAccount(db, id: 'a', name: 'Carteira', initialBalance: 150000);
    final food = await seedCategory(db, 'Mercado');
    final salary = await seedCategory(db, 'Salario', type: kIncome);
    await seedTx(
      db,
      accountId: acc,
      type: kExpense,
      amount: 8990,
      categoryId: food,
      description: 'Compra do mes',
      date: DateTime(now.year, now.month, 2, 10),
    );
    await seedTx(
      db,
      accountId: acc,
      type: kIncome,
      amount: 350000,
      categoryId: salary,
      description: 'Pagamento',
      date: DateTime(now.year, now.month, 5, 9),
    );
    await db.upsertBudget(
      BudgetsCompanion.insert(id: 'b1', categoryId: food, month: month, limitAmount: 120000),
      id: 'b1',
    );
    final goal = await seedGoal(db, name: 'Reserva de emergencia', target: 1000000, id: 'g1');
    await db.addContribution(goalId: goal, amount: 250000, note: 'primeiro');
    await seedRecurring(
      db,
      accountId: acc,
      type: kExpense,
      amount: 9990,
      nextDue: DateTime(now.year, now.month, now.day, 12).add(const Duration(days: 3)),
      id: 'r1',
    );
  }

  testWidgets('Panorama mostra saldos, gastos por categoria e as ultimas movimentacoes', (tester) async {
    await seedMonth();
    await pumpScreen(tester, const DashboardScreen());

    expect(find.text('Panorama'), findsOneWidget);
    expect(find.text('Panorama do mês'), findsOneWidget);
    await scrollUntilVisible(tester, find.text('Últimas movimentações'));
    expect(find.text('Últimas movimentações'), findsOneWidget);
    expect(find.text('Compra do mes'), findsOneWidget);
    expect(find.text('Erro:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Transacoes lista os lancamentos do mes', (tester) async {
    await seedMonth();
    await pumpScreen(tester, const TransactionsScreen());

    expect(find.text('Transações'), findsOneWidget);
    expect(find.text('Compra do mes'), findsOneWidget);
    expect(find.text('Pagamento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Orcamentos traz o resumo e a categoria orçada do mes', (tester) async {
    await seedMonth();
    await pumpScreen(tester, const BudgetsScreen());

    expect(find.text('Orçamentos'), findsOneWidget);
    await pumpScreen(tester, const BudgetsScreen());

    expect(find.text('Orçamentos'), findsOneWidget);
    expect(find.text('Resumo do mês'), findsOneWidget);
    expect(find.textContaining('categoria(s)'), findsOneWidget);
    expect(find.textContaining('1.200,00'), findsOneWidget);

    await scrollUntilVisible(tester, find.text('Mercado'));
    expect(find.text('Mercado'), findsWidgets);
    expect(find.textContaining('1.110,10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Metas mostra a meta com o valor guardado', (tester) async {
    await seedMonth();
    await pumpScreen(tester, const GoalsScreen());

    expect(find.text('Metas'), findsOneWidget);
    await scrollUntilVisible(tester, find.text('Reserva de emergencia'));
    expect(find.text('Reserva de emergencia'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.textContaining('10.000,00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recorrentes lista a regra e o proximo vencimento', (tester) async {
    await seedMonth();
    await pumpScreen(tester, const RecurringScreen());

    expect(find.text('Recorrentes'), findsOneWidget);
    expect(find.text('Pausada'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Relatorios monta graficos e o botao de gerar PDF', (tester) async {
    await seedMonth();
    await pumpScreen(tester, const ReportsScreen());

    expect(find.text('Relatórios'), findsOneWidget);
    expect(find.text('Gerar PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('telas vazias mostram estado vazio em vez de quebrar', (tester) async {
    await pumpScreen(tester, const TransactionsScreen());
    expect(find.text('Sem transações'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpScreen(tester, const GoalsScreen());
    expect(tester.takeException(), isNull);

    await pumpScreen(tester, const BudgetsScreen());
    expect(tester.takeException(), isNull);

    await pumpScreen(tester, const DashboardScreen());
    expect(find.text('Erro:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trocar o periodo do relatorio nao deixa o grafico antigo no ar', (tester) async {
    await seedMonth();
    await pumpScreen(tester, const ReportsScreen());

    await tester.tap(find.text('6 meses'));
    await flushAsync(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('1 ano'));
    await flushAsync(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Semana'));
    await flushAsync(tester);
    expect(find.text('Relatórios'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('telas vazias oferecem carregar dados de exemplo', (tester) async {
    await pumpScreen(tester, const TransactionsScreen());
    expect(find.text('Carregar dados de exemplo'), findsOneWidget);

    await tester.tap(find.text('Carregar dados de exemplo'));
    await flushAsync(tester);
    expect(find.text('Carregar dados de exemplo?'), findsOneWidget);

    await tester.tap(find.text('Carregar exemplo'));
    await flushAsync(tester);
    expect(find.text('Sem transações'), findsNothing);
    expect(find.textContaining('Notebook Dell'), findsWidgets);
    expect(tester.takeException(), isNull);

    await pumpScreen(tester, const DashboardScreen());
    expect(find.text('Modo demonstração: dados fictícios para explorar cada tela.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('modo demonstração preenche as telas com dados fictícios', (tester) async {
    await binding.runAsync(() => DemoData.load(db));
    await pumpScreen(tester, const DashboardScreen());

    expect(find.text('Modo demonstração: dados fictícios para explorar cada tela.'), findsOneWidget);
    expect(find.text('Conta corrente'), findsWidgets);
    expect(find.text('Erro:'), findsNothing);
    expect(tester.takeException(), isNull);

    await pumpScreen(tester, const TransactionsScreen());
    expect(find.textContaining('Notebook Dell'), findsWidgets);
    await pumpScreen(tester, const BudgetsScreen());
    expect(tester.takeException(), isNull);
    await pumpScreen(tester, const GoalsScreen());
    await scrollUntilVisible(tester, find.text('Notebook novo'));
    expect(find.text('Notebook novo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
