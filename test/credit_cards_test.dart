import 'package:drift/drift.dart' hide Column, Table, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:finamind/core/utils.dart';
import 'package:finamind/data/credit_models.dart';
import 'package:finamind/data/database.dart';
import 'package:finamind/data/providers.dart';
import 'package:finamind/features/credit_cards/credit_cards_screen.dart';
import 'package:finamind/features/credit_cards/purchases_screen.dart';
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
      await binding.runAsync(db.close);
    });
  });

  Future<void> settle(WidgetTester tester, [int steps = 20]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> flushAsync(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
  }

  Future<void> pumpCards(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CreditCardsScreen()),
    ));
    await flushAsync(tester);
  }

  Future<void> pumpPurchases(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PurchasesScreen()),
    ));
    await flushAsync(tester);
  }

  Future<Account> seedAccount(String id, String name,
      {String type = 'checking', int initial = 0, bool isDefault = false}) async {
    await db.upsertAccount(
      AccountsCompanion.insert(
        id: id,
        name: name,
        type: Value(type),
        initialBalance: Value(initial),
        isDefault: Value(isDefault),
      ),
      id: id,
    );
    return (await (db.select(db.accounts)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<CreditCard> seedCard(
    String id,
    String accountId, {
    String name = 'Nubank',
    int creditLimit = 100000,
    int closingDay = 25,
    int dueDay = 10,
  }) async {
    await db.saveCreditCard(
      id: id,
      name: name,
      accountId: accountId,
      creditLimit: creditLimit,
      closingDay: closingDay,
      dueDay: dueDay,
    );
    return (await db.getCreditCard(id))!;
  }

  Future<void> seedPurchase(String id, String cardId,
      {int total = 120000, int installments = 1, String establishment = 'Mercado'}) async {
    await db.savePurchase(
      id: id,
      creditCardId: cardId,
      establishment: establishment,
      totalAmount: total,
      installmentCount: installments,
      purchaseDate: DateTime(2026, 10, 5),
    );
  }

  /// Data esperada da parcela i (0-based): dia de fechamento no mês da compra + i.
  DateTime expectedDue(DateTime purchaseDate, int closingDay, int i) {
    final targetMonth = purchaseDate.month + i;
    final year = purchaseDate.year + ((targetMonth - 1) ~/ 12);
    final month = ((targetMonth - 1) % 12) + 1;
    return DateTime(year, month, closingDay);
  }

  Finder cardTile(String id) => find.byKey(ValueKey('credit_card_$id'));
  Finder inactiveTile(String id) => find.byKey(ValueKey('credit_card_inactive_$id'));

  group('módulo 12 - cartões de crédito', () {
    testWidgets('listar cartões mostra nome, limite, limite disponível, fechamento e vencimento',
        (tester) async {
      await seedAccount('c1', 'Conta Inter', initial: 0, isDefault: true);
      await seedCard('a1', 'c1', name: 'Inter', creditLimit: 500000);
      await pumpCards(tester);

      expect(cardTile('a1'), findsOneWidget);
      expect(find.text('Inter'), findsOneWidget);
      expect(find.text('Limite'), findsWidgets);
      expect(find.text(Formats.money(500000)), findsWidgets);
      expect(find.text('Disponível'), findsWidgets);
      expect(find.text('Fecha dia 25 • Vence dia 10'), findsOneWidget);
    });

    testWidgets('criar cartão pelo formulário adiciona à lista', (tester) async {
      await seedAccount('c1', 'Conta Inter', isDefault: true);
      await pumpCards(tester);

      expect(find.text('Nenhum cartão'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('credit_cards_add')));
      await settle(tester);

      await tester.enterText(find.byKey(const ValueKey('credit_card_name')), 'Inter');
      await tester.enterText(find.byKey(const ValueKey('credit_card_limit')), '500000');
      await tester.tap(find.byKey(const ValueKey('credit_card_editor_save')));
      await flushAsync(tester);

      expect(find.text('Inter'), findsOneWidget);
      expect(find.text(Formats.money(500000)), findsWidgets);

      final saved = await db.getCreditCards();
      expect(saved.length, 1);
      expect(saved.first.name, 'Inter');
      expect(saved.first.creditLimit, 500000);
      expect(saved.first.accountId, 'c1');
      expect(saved.first.closingDay, 25);
      expect(saved.first.dueDay, 10);
    });

    testWidgets('editar cartão atualiza nome, limite e dias', (tester) async {
      await seedAccount('c1', 'Conta Inter', isDefault: true);
      await seedCard('a1', 'c1', name: 'Inter', creditLimit: 500000);
      await pumpCards(tester);

      await tester.tap(cardTile('a1'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('credit_card_detail_edit')));
      await settle(tester);

      await tester.enterText(find.byKey(const ValueKey('credit_card_name')), 'Inter Black');
      await tester.enterText(find.byKey(const ValueKey('credit_card_limit')), '999999');
      await tester.tap(find.byKey(const ValueKey('credit_card_editor_save')));
      await flushAsync(tester);

      final edited = await db.getCreditCard('a1');
      expect(edited!.name, 'Inter Black');
      expect(edited.creditLimit, 999999);

      expect(find.byKey(const ValueKey('credit_card_detail')), findsOneWidget);
      expect(find.text('Inter Black'), findsWidgets);
    });

    testWidgets('desativar e reativar cartão move entre seções', (tester) async {
      await seedAccount('c1', 'Conta Inter', isDefault: true);
      await seedCard('a1', 'c1', name: 'Inter');
      await pumpCards(tester);

      expect(cardTile('a1'), findsOneWidget);
      expect(inactiveTile('a1'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('credit_card_toggle_a1')));
      await flushAsync(tester);

      expect(cardTile('a1'), findsNothing);
      expect(find.text('Desativados'), findsOneWidget);
      expect(inactiveTile('a1'), findsOneWidget);
      expect((await db.getCreditCard('a1'))!.active, isFalse);

      await tester.tap(find.byKey(const ValueKey('credit_card_toggle_a1')));
      await flushAsync(tester);

      expect(cardTile('a1'), findsOneWidget);
      expect(inactiveTile('a1'), findsNothing);
      expect((await db.getCreditCard('a1'))!.active, isTrue);
    });

    testWidgets('excluir cartão remove da lista e cascateia compras', (tester) async {
      await seedAccount('c1', 'Conta Inter', isDefault: true);
      await seedCard('a1', 'c1', name: 'Inter', creditLimit: 500000);
      await seedPurchase('p1', 'a1', establishment: 'Notebook');
      await pumpCards(tester);

      await tester.tap(cardTile('a1'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('credit_card_detail_delete')));
      await settle(tester);

      expect(find.text('Excluir cartão?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
      await flushAsync(tester);

      expect(cardTile('a1'), findsNothing);
      expect(await db.getCreditCard('a1'), isNull);
      expect(await db.getPurchases(), isEmpty);
      expect(await db.creditCardUsed('a1'), 0);
    });
  });

  group('módulo 13 - compras no cartão', () {
    testWidgets('compra à vista gera 1 parcela, 1 lançamento e consome o limite', (tester) async {
      await seedAccount('c1', 'Conta Inter', initial: 0, isDefault: true);
      await seedCard('a1', 'c1', creditLimit: 500000);
      await seedPurchase('p1', 'a1', total: 120000, installments: 1, establishment: 'Mercado');

      final purchases = await db.getPurchases();
      expect(purchases.length, 1);
      expect(purchases.first.installmentCount, 1);
      expect(purchases.first.installmentAmount, 120000);
      expect(purchases.first.establishment, 'Mercado');

      final parcels = await db.getParcels('p1');
      expect(parcels.length, 1);
      expect(parcels.first.installmentNumber, 1);
      expect(parcels.first.amount, 120000);
      expect(parcels.first.dueDate, DateTime(2026, 10, 25));

      final rows = await db.customSelect(
        'SELECT * FROM transactions WHERE purchase_id = ? AND deleted_at IS NULL',
        variables: [Variable.withString('p1')],
      ).get();
      expect(rows.length, 1);
      expect(rows.first.read<String>('type'), kExpense);
      expect(rows.first.read<String>('description'), 'Mercado');
      expect(rows.first.read<int>('amount'), 120000);

      expect(await db.creditCardUsed('a1'), 120000);
    });

    testWidgets('compra em 2 parcelas divide o valor e gera os lançamentos', (tester) async {
      await seedAccount('c1', 'Conta Inter', isDefault: true);
      await seedCard('a1', 'c1', creditLimit: 500000);
      await seedPurchase('p1', 'a1', total: 100001, installments: 2, establishment: 'Perfume');

      final parcels = await db.getParcels('p1');
      expect(parcels.map((p) => p.amount), [50001, 50000]);
      expect(parcels.map((p) => p.installmentNumber), [1, 2]);
      expect(parcels.map((p) => p.dueDate), [
        DateTime(2026, 10, 25),
        DateTime(2026, 11, 25),
      ]);

      final rows = await db.customSelect(
        'SELECT * FROM transactions WHERE purchase_id = ? AND deleted_at IS NULL ORDER BY date ASC',
        variables: [Variable.withString('p1')],
      ).get();
      expect(rows.length, 2);
      expect(rows.map((r) => r.read<String>('description')), ['Perfume (1/2)', 'Perfume (2/2)']);
    });

    testWidgets('compra em 6 parcelas gera 6 lançamentos coerentes', (tester) async {
      await seedAccount('c1', 'Conta Inter', isDefault: true);
      await seedCard('a1', 'c1', creditLimit: 500000);
      await seedPurchase('p1', 'a1', total: 600000, installments: 6, establishment: 'Viagem');

      final parcels = await db.getParcels('p1');
      expect(parcels.length, 6);
      expect(parcels.fold<int>(0, (sum, p) => sum + p.amount), 600000);
      expect(parcels.any((p) => p.paid), isFalse);

      final rows = await db.customSelect(
        'SELECT * FROM transactions WHERE purchase_id = ? AND deleted_at IS NULL',
        variables: [Variable.withString('p1')],
      ).get();
      expect(rows.length, 6);
      expect(rows.every((r) => r.read<int>('amount') > 0), isTrue);
    });

    testWidgets('compra em 12 parcelas gera 12 lançamentos com datas progressivas', (tester) async {
      await seedAccount('c1', 'Conta Inter', isDefault: true);
      await seedCard('a1', 'c1', creditLimit: 500000, closingDay: 15, dueDay: 5);
      await seedPurchase('p1', 'a1', total: 1234567, installments: 12, establishment: 'Console');

      final parcels = await db.getParcels('p1');
      expect(parcels.length, 12);
      expect(parcels.fold<int>(0, (sum, p) => sum + p.amount), 1234567);
      for (var i = 0; i < parcels.length; i++) {
        expect(parcels[i].dueDate, expectedDue(DateTime(2026, 10, 5), 15, i),
            reason: 'parcela ${i + 1}');
      }
      expect((await db.getPurchases()).first.installmentAmount, 102881);

      final rows = await db.customSelect(
        'SELECT * FROM transactions WHERE purchase_id = ? AND deleted_at IS NULL',
        variables: [Variable.withString('p1')],
      ).get();
      expect(rows.length, 12);
      expect(rows.map((r) => r.read<String>('description')), [
        for (var i = 1; i <= 12; i++) 'Console ($i/12)',
      ]);
    });

    testWidgets('cancelar compra quita parcelas, remove lançamentos e restaura o limite',
        (tester) async {
      await seedAccount('c1', 'Conta Inter', isDefault: true);
      await seedCard('a1', 'c1', creditLimit: 500000);
      await seedPurchase('p1', 'a1', total: 240000, installments: 2, establishment: 'TV');
      expect(await db.creditCardUsed('a1'), 240000);

      await db.cancelPurchase('p1');

      expect(await db.getPurchases(), isEmpty);
      expect(await db.getPurchase('p1'), isNull);
      expect(await db.creditCardUsed('a1'), 0);

      final parcels = await db.getParcels('p1');
      expect(parcels.length, 2);
      expect(parcels.every((p) => p.paid), isTrue);

      final rows = await db.customSelect(
        'SELECT * FROM transactions WHERE purchase_id = ? AND deleted_at IS NOT NULL',
        variables: [Variable.withString('p1')],
      ).get();
      expect(rows.length, 2);
    });

    testWidgets('editar compra regera parcelas e lançamentos', (tester) async {
      await seedAccount('c1', 'Conta Inter', isDefault: true);
      await seedCard('a1', 'c1', creditLimit: 500000);
      await seedPurchase('p1', 'a1', total: 60000, installments: 6, establishment: 'Roupa');

      await db.savePurchase(
        id: 'p1',
        creditCardId: 'a1',
        establishment: 'Tênis',
        totalAmount: 120000,
        installmentCount: 3,
        purchaseDate: DateTime(2026, 10, 5),
      );

      final purchase = await db.getPurchase('p1');
      expect(purchase!.establishment, 'Tênis');
      expect(purchase.installmentCount, 3);
      expect(purchase.totalAmount, 120000);

      final parcels = await db.getParcels('p1');
      expect(parcels.length, 3);
      expect(parcels.fold<int>(0, (sum, p) => sum + p.amount), 120000);

      final active = await db.customSelect(
        'SELECT * FROM transactions WHERE purchase_id = ? AND deleted_at IS NULL',
        variables: [Variable.withString('p1')],
      ).get();
      final deleted = await db.customSelect(
        'SELECT * FROM transactions WHERE purchase_id = ? AND deleted_at IS NOT NULL',
        variables: [Variable.withString('p1')],
      ).get();
      expect(active.length, 3);
      expect(deleted.length, 6);
      expect(await db.creditCardUsed('a1'), 120000);
    });

    testWidgets('registrar compra parcelada pela tela de compras', (tester) async {
      await seedAccount('c1', 'Conta Inter', isDefault: true);
      await seedCard('a1', 'c1', creditLimit: 500000);
      await pumpPurchases(tester);

      expect(find.text('Nenhuma compra'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('purchases_add')));
      await settle(tester);

      expect(find.byType(PurchaseEditorScreen), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('purchase_editor_establishment')), 'Mercado');
      await tester.enterText(find.byKey(const ValueKey('purchase_editor_total')), '30000');

      await tester.tap(find.byKey(const ValueKey('purchase_editor_installment_toggle')));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('purchase_editor_save')));
      await flushAsync(tester);

      final purchases = await db.getPurchases();
      expect(purchases.length, 1);
      expect(purchases.first.establishment, 'Mercado');
      expect(purchases.first.installmentCount, 2);
      expect(await db.creditCardUsed('a1'), 30000);

      expect(find.text('Mercado'), findsOneWidget);
    });

    testWidgets('marcar parcela paga reduz o limite utilizado', (tester) async {
      await seedAccount('c1', 'Conta Inter', isDefault: true);
      await seedCard('a1', 'c1', creditLimit: 500000);
      await seedPurchase('p1', 'a1', total: 60000, installments: 2, establishment: 'Sapatos');
      expect(await db.creditCardUsed('a1'), 60000);

      final parcel1 = (await db.getParcels('p1')).first;
      await db.setParcelPaid(parcel1.id, paid: true);

      expect(await db.creditCardUsed('a1'), 30000);
      final purchase = await db.getPurchase('p1');
      expect(purchase!.paid, isFalse);
    });
  });
}
