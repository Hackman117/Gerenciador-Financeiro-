import 'package:drift/native.dart';
import 'package:finamind/data/database.dart';
import 'package:finamind/data/providers.dart';
import 'package:finamind/features/dashboard/dashboard_screen.dart';
import 'package:finamind/features/editors/transaction_editor.dart';
import 'package:finamind/features/shell/app_shell.dart';
import 'package:finamind/features/transactions/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/seed.dart';

/// Teste dos BOTOES: cada atalho precisa navegar de verdade para a tela certa.
/// Regressao: botoes que usavam Navigator.pushNamed nao navegavam nada
/// (o app usa go_router), entao o toque falhava em silencio.
void main() {
  initializeDateFormatting();

  /// Cinto de segurança: nada pode pendurar 10 minutos se um teste travar.
  void testBtn(String description, Future<void> Function(WidgetTester) body) =>
      testWidgets(description, body, timeout: const Timeout(Duration(seconds: 120)));

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

  /// O dashboard encadeia ~15 consultas assincronas; com uma unica janela de
  /// async real o provider nao completa e a tela fica no spinner. Alternar
  /// janelas reais com pumps deixa o drift avancar com folga.
  Future<void> flushAsync(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Monta as mesmas rotas do app para os botoes navegarem de verdade.
  /// A janela e alta o bastante para o ListView construir os botoes do rodape
  /// do editor ('Adicionar'/'Salvar alterações') sem precisar rolar.
  Future<void> pumpRouted(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: '/nova-transacao',
          builder: (_, state) => TransactionEditorScreen(initialType: state.uri.queryParameters['tipo']),
        ),
        GoRoute(
          path: '/nova-transacao/:id',
          builder: (_, state) => TransactionEditorScreen(txId: state.pathParameters['id']),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await flushAsync(tester);
  }

  Future<void> scrollUntilVisible(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 26 && !finder.evaluate().isNotEmpty; i++) {
      if (find.byType(Scrollable).evaluate().isEmpty) {
        await flushAsync(tester);
        if (find.byType(Scrollable).evaluate().isEmpty) break;
      }
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await settle(tester, 4);
    }
    await flushAsync(tester);
  }

  /// Conta, categoria e um lancamento no mes corrente para as telas terem dados.
  Future<void> seedBasics() async {
    final now = DateTime.now();
    final acc = await seedAccount(db, id: 'a', name: 'Carteira', initialBalance: 150000);
    final food = await seedCategory(db, 'Mercado');
    await seedTx(
      db,
      accountId: acc,
      type: kExpense,
      amount: 8990,
      categoryId: food,
      description: 'Compra do mes',
      date: DateTime(now.year, now.month, 2, 10),
    );
  }

  testBtn('FAB do shell abre o editor de nova transacao', (tester) async {
    await seedBasics();
    await pumpRouted(tester, const AppShell());

    await tester.tap(find.byTooltip('Nova transação'));
    await flushAsync(tester);

    expect(find.text('Nova transação'), findsOneWidget);
    expect(find.text('Valor'), findsOneWidget);
    expect(find.text('Adicionar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testBtn('na aba Transacoes o FAB ainda abre o editor', (tester) async {
    await seedBasics();
    await pumpRouted(tester, const AppShell());

    container.read(shellTabProvider.notifier).state = 1;
    await flushAsync(tester);
    await tester.tap(find.byTooltip('Nova transação'));
    await flushAsync(tester);

    expect(find.text('Nova transação'), findsOneWidget);
    expect(find.text('Adicionar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testBtn('toque numa transacao da lista abre o editor preenchido', (tester) async {
    await seedBasics();
    await pumpRouted(tester, const TransactionsScreen());

    expect(find.text('Compra do mes'), findsOneWidget);
    await tester.tap(find.text('Compra do mes'));
    await flushAsync(tester);

    expect(find.text('Editar transação'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Compra do mes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testBtn('toque numa movimentacao recente do panorama abre o editor', (tester) async {
    await seedBasics();
    await pumpRouted(tester, const DashboardScreen());

    await scrollUntilVisible(tester, find.text('Compra do mes'));
    await tester.tap(find.text('Compra do mes'));
    await flushAsync(tester);

    expect(find.text('Editar transação'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testBtn('atalhos Gasto e Transferir abrem o editor no tipo certo', (tester) async {
    await seedBasics();
    await pumpRouted(tester, const DashboardScreen());

    await tester.tap(find.text('Gasto'));
    await flushAsync(tester);
    expect(find.text('Categoria'), findsOneWidget);
    expect(find.text('Adicionar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpRouted(tester, const DashboardScreen());
    await tester.tap(find.text('Transferir'));
    await flushAsync(tester);
    expect(find.text('Conta de destino'), findsOneWidget);
    expect(find.text('Adicionar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testBtn('atalho Nova meta troca para a aba Metas', (tester) async {
    await seedBasics();
    await pumpRouted(tester, const AppShell());
    expect(container.read(shellTabProvider), 0);
    expect(find.byTooltip('Nova transação'), findsOneWidget);

    await tester.tap(find.text('Nova meta'));
    await flushAsync(tester);

    expect(container.read(shellTabProvider), 3);
    expect(find.byTooltip('Nova transação'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testBtn('tela de Transacoes nao tem FAB proprio (evita botao duplicado)', (tester) async {
    await seedBasics();
    await pumpRouted(tester, const TransactionsScreen());

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
