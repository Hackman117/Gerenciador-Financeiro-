import 'package:drift/drift.dart' hide Column, Table, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:finamind/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<Set<String>> columnsOf(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('schemaVersion = 2 (migração definida)', () {
    expect(db.schemaVersion, 2);
  });

  test('todas as tabelas base existem com as colunas corretas', () async {
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'drift_%' ORDER BY name",
        )
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'accounts',
        'users',
        'categories',
        'subcategories',
        'transactions',
        'recurring_rules',
        'budgets',
        'goals',
        'goal_contributions',
        'settings',
      ]),
    );

    // usuário
    var cols = await columnsOf('users');
    expect(cols,
        containsAll(['id', 'name', 'email', 'status', 'created_at', 'updated_at', 'deleted_at']));

    // conta — valores monetários em centavos (INTEGER)
    cols = await columnsOf('accounts');
    expect(
      cols,
      containsAll([
        'id',
        'name',
        'type',
        'initial_balance',
        'is_default',
        'archived',
        'created_at',
        'updated_at',
        'deleted_at',
      ]),
    );

    // categoria — com status
    cols = await columnsOf('categories');
    expect(cols, containsAll(['id', 'name', 'type', 'status', 'created_at', 'updated_at', 'deleted_at']));

    // subcategoria — FK category_id
    cols = await columnsOf('subcategories');
    expect(
      cols,
      containsAll([
        'id',
        'category_id',
        'name',
        'icon',
        'color',
        'status',
        'created_at',
        'updated_at',
        'deleted_at',
      ]),
    );

    // lançamento — relacionamentos + status
    cols = await columnsOf('transactions');
    expect(
      cols,
      containsAll([
        'id',
        'account_id',
        'to_account_id',
        'category_id',
        'subcategory_id',
        'type',
        'amount',
        'date',
        'status',
        'created_at',
        'updated_at',
        'deleted_at',
      ]),
    );
  });

  test('seed no create: categorias padrão e conta padrão', () async {
    await db.ensureDefaultAccount();
    final cats = await db.getCategories();
    expect(cats.length, greaterThan(0));
    expect((await db.defaultAccount()), isNotNull);
  });

  test('usuário: id, nome, status e timestamps automáticos; email único', () async {
    await db.upsertUser(UsersCompanion.insert(id: 'u1', name: 'Ana'), id: 'u1');
    final user = await db.userById('u1');
    expect(user, isNotNull);
    expect(user!.name, 'Ana');
    expect(user.status, 'active');
    expect(user.createdAt, isNotNull);
    expect(user.updatedAt, isNotNull);

    // atualização avança updated_at (timestamps têm precisão de 1 s no SQLite)
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await db.upsertUser(
      UsersCompanion.insert(id: 'u1', name: 'Ana Souza', email: Value('ana@x.com')),
      id: 'u1',
    );
    final updated = await db.userById('u1');
    expect(updated!.name, 'Ana Souza');
    expect(updated.updatedAt.isAfter(user.updatedAt), isTrue);

    // email duplicado é rejeitado (chave única)
    await expectLater(
      db.upsertUser(UsersCompanion.insert(id: 'u2', name: 'Outra', email: Value('ana@x.com')), id: 'u2'),
      throwsA(anything),
    );
  });

  test('conta: dinheiro em centavos, status de arquivamento e saldo', () async {
    await db.upsertAccount(
      AccountsCompanion.insert(
        id: 'a1',
        name: 'Nubank',
        type: const Value('checking'),
        initialBalance: const Value(1234),
      ),
      id: 'a1',
    );
    final a1 = await (db.select(db.accounts)..where((t) => t.id.equals('a1'))).getSingle();
    expect(a1.initialBalance, 1234); // R$ 12,34 em centavos
    expect(a1.archived, isFalse);

    // lançamento incrementa o saldo como centavos
    await db.upsertTransaction(
      TransactionsCompanion.insert(
        id: 't1',
        accountId: 'a1',
        type: kIncome,
        amount: 1000,
        date: DateTime(2026, 10, 7),
      ),
      id: 't1',
    );
    expect(await db.accountBalance('a1'), 1234 + 1000);

    // desativar
    await db.setAccountArchived('a1', archived: true);
    final after = await (db.select(db.accounts)..where((t) => t.id.equals('a1'))).getSingle();
    expect(after.archived, isTrue);
  });

  test('conta: editar atualiza nome, tipo e saldo inicial; reativar volta para ativa', () async {
    await db.upsertAccount(
      AccountsCompanion.insert(
        id: 'a1',
        name: 'Nubank',
        type: const Value('checking'),
        initialBalance: const Value(1234),
      ),
      id: 'a1',
    );
    await db.upsertAccount(
      AccountsCompanion.insert(
        id: 'a1',
        name: 'Nubank PJ',
        type: const Value('digital'),
        icon: const Value('digital'),
        initialBalance: const Value(5000),
        archived: const Value(true),
        color: const Value(0xFF3E7BFA),
      ),
      id: 'a1',
    );
    final edited = await (db.select(db.accounts)..where((t) => t.id.equals('a1'))).getSingle();
    expect(edited.name, 'Nubank PJ');
    expect(edited.type, 'digital');
    expect(edited.initialBalance, 5000);
    expect(edited.archived, isTrue);
    expect(edited.updatedAt, isNotNull);

    // reativar
    await db.setAccountArchived('a1', archived: false);
    final active = await (db.select(db.accounts)..where((t) => t.id.equals('a1'))).getSingle();
    expect(active.archived, isFalse);
  });

  test('conta: listar ativas exclui arquivadas e excluídas (soft delete)', () async {
    await db.upsertAccount(
      AccountsCompanion.insert(id: 'c1', name: 'Carteira', type: const Value('cash'), isDefault: const Value(true)),
      id: 'c1',
    );
    await db.upsertAccount(
      AccountsCompanion.insert(id: 'n1', name: 'Nubank', type: const Value('checking')),
      id: 'n1',
    );
    await db.upsertAccount(
      AccountsCompanion.insert(id: 'p1', name: 'Poupança', type: const Value('savings')),
      id: 'p1',
    );
    await db.setAccountArchived('p1', archived: true);
    await db.softDelete('accounts', 'n1');

    expect((await db.getAccounts()).map((a) => a.id), ['c1']);

    final withArchived = await db.watchAccounts(includeArchived: true).first;
    expect(withArchived.map((a) => a.id).toSet(), {'c1', 'p1'});

    final watchActive = await db.watchAccounts().first;
    expect(watchActive.map((a) => a.id).toSet(), {'c1'});
  });

  test('conta: definir padrão mantém apenas uma conta padrão', () async {
    await db.upsertAccount(
      AccountsCompanion.insert(id: 'c1', name: 'Carteira', type: const Value('cash'), isDefault: const Value(true)),
      id: 'c1',
    );
    await db.upsertAccount(
      AccountsCompanion.insert(id: 'n1', name: 'Nubank', type: const Value('checking')),
      id: 'n1',
    );

    await db.setDefaultAccount('n1');
    final all = await (db.select(db.accounts)..where((t) => t.deletedAt.isNull())).get();
    final defaults = all.where((a) => a.isDefault).toList();
    expect(defaults, hasLength(1));
    expect(defaults.single.id, 'n1');
    expect((await db.defaultAccount())!.id, 'n1');

    // reativar padrão anterior preserva a regra
    await db.setDefaultAccount('c1');
    expect((await db.defaultAccount())!.id, 'c1');
  });

  test('conta: saldo atual considera receitas, despesas, transferências e filtro de data', () async {
    await db.upsertAccount(
      AccountsCompanion.insert(id: 'a1', name: 'Corrente', type: const Value('checking'), initialBalance: const Value(1000)),
      id: 'a1',
    );
    await db.upsertAccount(
      AccountsCompanion.insert(id: 'a2', name: 'Carteira', type: const Value('cash'), initialBalance: const Value(2000)),
      id: 'a2',
    );

    final d1 = DateTime(2026, 10, 1);
    final d2 = DateTime(2026, 10, 2);
    final d3 = DateTime(2026, 10, 3);
    final d4 = DateTime(2026, 10, 4);

    await db.upsertTransaction(TransactionsCompanion.insert(id: 't1', accountId: 'a1', type: kIncome, amount: 5000, date: d1), id: 't1');
    await db.upsertTransaction(TransactionsCompanion.insert(id: 't2', accountId: 'a1', type: kExpense, amount: 1200, date: d2), id: 't2');
    await db.upsertTransaction(
      TransactionsCompanion.insert(id: 't3', accountId: 'a1', toAccountId: Value('a2'), type: kTransfer, amount: 700, date: d3),
      id: 't3',
    );
    await db.upsertTransaction(
      TransactionsCompanion.insert(id: 't4', accountId: 'a2', toAccountId: Value('a1'), type: kTransfer, amount: 900, date: d4),
      id: 't4',
    );

    // 1000 + 5000 - 1200 - 700 (enviado) + 900 (recebido) = 5000
    expect(await db.accountBalance('a1'), 1000 + 5000 - 1200 - 700 + 900);
    // 2000 + 700 (recebido) - 900 (enviado) = 1800
    expect(await db.accountBalance('a2'), 2000 + 700 - 900);

    // filtro até o dia 2: 1000 + 5000 - 1200 = 4800
    expect(await db.accountBalance('a1', until: d2), 4800);
  });

  test('conta: tipo "conta digital" persiste e é listado', () async {
    await db.upsertAccount(
      AccountsCompanion.insert(
        id: 'd1',
        name: 'Carteira Digital',
        type: const Value('digital'),
        icon: const Value('digital'),
        initialBalance: const Value(9900),
      ),
      id: 'd1',
    );
    final row = await (db.select(db.accounts)..where((t) => t.id.equals('d1'))).getSingle();
    expect(row.type, 'digital');
    expect(row.icon, 'digital');
    expect(await db.accountBalance('d1'), 9900);
    expect((await db.getAccounts()).first.id, 'd1');
  });

  test('categoria + subcategoria: relacionamento e filtro por pai', () async {
    final cats = await db.getCategories();
    final expense = cats.firstWhere((c) => c.type == kExpense);
    final income = cats.firstWhere((c) => c.type == kIncome);

    await db.upsertSubcategory(
      SubcategoriesCompanion.insert(id: 's1', categoryId: expense.id, name: 'Mercado'),
      id: 's1',
    );
    await db.upsertSubcategory(
      SubcategoriesCompanion.insert(id: 's2', categoryId: expense.id, name: 'Farmácia'),
      id: 's2',
    );
    await db.upsertSubcategory(
      SubcategoriesCompanion.insert(id: 's3', categoryId: income.id, name: 'Projetos'),
      id: 's3',
    );

    final sub = await (db.select(db.subcategories)..where((t) => t.id.equals('s1'))).getSingle();
    expect(sub.status, 'active');
    expect(sub.categoryId, expense.id);

    final ofExpense = await db.getSubcategories(categoryId: expense.id);
    expect(ofExpense.map((s) => s.id).toSet(), {'s1', 's2'});
    expect(await db.getSubcategories(categoryId: income.id), hasLength(1));
  });

  test('lançamento: relacionamentos, status padrão e timestamps', () async {
    await db.upsertAccount(
      AccountsCompanion.insert(id: 'a1', name: 'Carteira', type: const Value('cash'), initialBalance: const Value(0)),
      id: 'a1',
    );
    final cat = (await db.getCategories()).firstWhere((c) => c.type == kExpense);
    await db.upsertSubcategory(
      SubcategoriesCompanion.insert(id: 's1', categoryId: cat.id, name: 'Mercado'),
      id: 's1',
    );

    await db.upsertTransaction(
      TransactionsCompanion.insert(
        id: 't1',
        accountId: 'a1',
        categoryId: Value(cat.id),
        subcategoryId: Value('s1'),
        type: kExpense,
        amount: 3500,
        date: DateTime(2026, 10, 7),
      ),
      id: 't1',
    );

    final tx = await (db.select(db.transactions)..where((t) => t.id.equals('t1'))).getSingle();
    expect(tx.status, 'posted'); // efetivado por padrão
    expect(tx.categoryId, cat.id);
    expect(tx.subcategoryId, 's1');
    expect(tx.amount, 3500);
    expect(tx.createdAt, isNotNull);
    expect(tx.updatedAt, isNotNull);
  });

  test('integridade referencial rejeita órfãos', () async {
    await db.customStatement('PRAGMA foreign_keys = ON');

    // lançamento sem conta válida
    await expectLater(
      db.upsertTransaction(
        TransactionsCompanion.insert(
          id: 'txBad',
          accountId: 'nao-existe',
          type: kExpense,
          amount: 1,
          date: DateTime(2026, 1, 1),
        ),
        id: 'txBad',
      ),
      throwsA(anything),
    );

    // subcategoria sem categoria válida
    await expectLater(
      db.upsertSubcategory(
        SubcategoriesCompanion.insert(id: 'sBad', categoryId: 'nao-existe', name: 'X'),
        id: 'sBad',
      ),
      throwsA(anything),
    );
  });

  test('lixeira: softDelete, restore e purge preservam corretamente', () async {
    await db.ensureDefaultAccount();
    final account = (await db.defaultAccount())!;
    await db.softDelete('accounts', account.id);
    expect(await db.getAccounts(), isEmpty);
    await db.restoreRow('accounts', account.id);
    expect(await db.getAccounts(), hasLength(1));
    await db.purgeRow('accounts', account.id);
    expect(await db.getAccounts(), isEmpty);
  });
}