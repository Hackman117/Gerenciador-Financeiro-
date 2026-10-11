import 'package:drift/drift.dart' hide Column, Table, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:finamind/core/utils.dart';
import 'package:finamind/data/database.dart';
import 'package:finamind/data/providers.dart';
import 'package:finamind/features/accounts/accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  initializeDateFormatting();

  late AppDatabase db;
  late ProviderContainer container;

  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    db = await binding.runAsync(() async => AppDatabase.forTesting(NativeDatabase.memory())) ??
        AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      // O Drift roda em zona real; fecha o banco fora do FakeAsync do teste.
      await binding.runAsync(db.close);
    });
  });

  /// Avança o relógio de forma limitada (evita loops infinitos de frames).
  Future<void> settle(WidgetTester tester, [int steps = 20]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Deixa o Drift (execução em zona real) concluir fora do FakeAsync.
  Future<void> flushAsync(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsScreen()),
    ));
    await flushAsync(tester);
  }

  Future<Account> seedAccount(
    String id,
    String name, {
    String type = 'checking',
    int initial = 0,
    bool isDefault = false,
    bool archived = false,
  }) async {
    await db.upsertAccount(
      AccountsCompanion.insert(
        id: id,
        name: name,
        type: Value(type),
        initialBalance: Value(initial),
        isDefault: Value(isDefault),
        archived: Value(archived),
      ),
      id: id,
    );
    return (await (db.select(db.accounts)..where((t) => t.id.equals(id))).getSingle())!;
  }

  Future<void> seedIncome(String id, String accountId, int amount) async {
    await db.upsertTransaction(
      TransactionsCompanion.insert(
        id: id,
        accountId: accountId,
        type: kIncome,
        amount: amount,
        date: DateTime(2026, 10, 5),
      ),
      id: id,
    );
  }

  Finder cardOf(String id) => find.byKey(ValueKey('account_card_$id'));
  Finder archivedTileOf(String id) => find.byKey(ValueKey('account_archived_$id'));

  testWidgets('listar contas mostra nome, tipo e saldo atual', (tester) async {
    await seedAccount('c1', 'Carteira', type: 'cash', initial: 1000, isDefault: true);
    await seedAccount('n1', 'Nubank', type: 'checking', initial: 25000);
    await pumpScreen(tester);

    expect(find.text('Carteira'), findsOneWidget);
    expect(find.text('Nubank'), findsOneWidget);
    expect(find.text('Dinheiro'), findsOneWidget);
    expect(find.text('Conta corrente'), findsOneWidget);
    expect(find.text(Formats.money(1000)), findsOneWidget);
    expect(find.text(Formats.money(25000)), findsOneWidget);
    expect(find.text('Padrão'), findsOneWidget);
  });

  testWidgets('criar conta (tipo conta digital) com saldo inicial mostra o card', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Nenhuma conta'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);

    await tester.enterText(find.byKey(const ValueKey('account_name')), 'Poupança Digital');
    await tester.enterText(find.byKey(const ValueKey('account_initial')), '150000');

    await tester.tap(find.byKey(const ValueKey('account_type')));
    await settle(tester);
    await tester.tap(find.text('Conta digital').last);
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await flushAsync(tester);

    expect(find.text('Poupança Digital'), findsOneWidget);
    expect(find.text('Conta digital'), findsOneWidget);
    expect(find.text(Formats.money(150000)), findsOneWidget);

    final saved = await (db.select(db.accounts)..where((t) => t.name.equals('Poupança Digital'))).getSingleOrNull();
    expect(saved, isNotNull);
    expect(saved!.type, 'digital');
    expect(saved.initialBalance, 150000);
  });

  testWidgets('visualizar conta mostra tipo, saldo inicial e saldo atual', (tester) async {
    await seedAccount('n1', 'Nubank', type: 'checking', initial: 5000, isDefault: true);
    await seedIncome('t1', 'n1', 3000);
    await pumpScreen(tester);

    await tester.tap(cardOf('n1'));
    await settle(tester);

    expect(find.byKey(const ValueKey('account_detail')), findsOneWidget);
    expect(find.text('Nubank'), findsOneWidget);
    expect(find.text('Conta corrente'), findsWidgets);
    expect(find.text('Saldo inicial'), findsOneWidget);
    expect(find.text(Formats.money(5000)), findsOneWidget);
    expect(find.text(Formats.money(8000)), findsOneWidget);
    final balanceText = tester.widget<Text>(find.byKey(const ValueKey('account_detail_balance')));
    expect(balanceText.data, Formats.money(8000));
  });

  testWidgets('editar conta atualiza nome e saldo inicial', (tester) async {
    await seedAccount('n1', 'Nubank', type: 'checking', initial: 5000, isDefault: true);
    await pumpScreen(tester);

    await tester.tap(cardOf('n1'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('account_detail_edit')));
    await settle(tester);

    await tester.enterText(find.byKey(const ValueKey('account_name')), 'Nubank PJ');
    await tester.enterText(find.byKey(const ValueKey('account_initial')), '999');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await flushAsync(tester);

    expect(find.byKey(const ValueKey('account_detail')), findsOneWidget);
    expect(find.text('Nubank PJ'), findsWidgets);
    expect(find.text(Formats.money(999)), findsWidgets);

    final edited = await (db.select(db.accounts)..where((t) => t.id.equals('n1'))).getSingle();
    expect(edited.name, 'Nubank PJ');
    expect(edited.initialBalance, 999);
  });

  testWidgets('desativar e reativar conta move entre as seções', (tester) async {
    await seedAccount('c1', 'Carteira', type: 'cash', isDefault: true);
    await seedAccount('n1', 'Nubank', type: 'checking', initial: 1000);
    await pumpScreen(tester);

    await tester.tap(cardOf('n1'));
    await settle(tester);
    expect(find.byKey(const ValueKey('account_detail')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('account_detail_deactivate')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('account_detail_deactivate')));
    await flushAsync(tester);

    expect(find.byKey(const ValueKey('account_detail')), findsNothing);
    expect(find.text('Desativadas'), findsOneWidget);
    expect(archivedTileOf('n1'), findsOneWidget);

    await tester.tap(archivedTileOf('n1'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('account_detail_reactivate')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('account_detail_reactivate')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account_detail_reactivate')));
    await flushAsync(tester);

    expect(cardOf('n1'), findsOneWidget);
    expect(find.text('Desativadas'), findsNothing);
  });

  testWidgets('excluir conta remove da lista, arquiva transações e redefine a padrão', (tester) async {
    await seedAccount('c1', 'Carteira', type: 'cash', initial: 2000);
    await seedAccount('n1', 'Nubank', type: 'checking', initial: 700, isDefault: true);
    await seedIncome('t1', 'n1', 100);
    await pumpScreen(tester);

    await tester.tap(cardOf('n1'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('account_detail_delete')));
    await settle(tester);

    expect(find.text('Excluir conta?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await flushAsync(tester);

    expect(find.text('Nubank'), findsNothing);
    expect(cardOf('c1'), findsOneWidget);

    final deleted = await (db.select(db.accounts)..where((t) => t.id.equals('n1'))).getSingle();
    expect(deleted.deletedAt, isNotNull);
    final remaining = await db.getAccounts();
    expect(remaining.map((a) => a.id), ['c1']);
    final newDefault = await db.defaultAccount();
    expect(newDefault!.id, 'c1');
  });
}