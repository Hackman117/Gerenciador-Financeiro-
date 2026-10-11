import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/utils.dart';
import 'credit_models.dart';

part 'database.g.dart';

const String kIncome = 'income';
const String kExpense = 'expense';
const String kTransfer = 'transfer';

const String kAccountTypes = 'checking, savings, cash, credit, investment, wallet, digital';

const _uuid = Uuid();

String newId() => _uuid.v4();

@DataClassName('Account')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => text().withDefault(const Constant('checking'))();
  TextColumn get icon => text().withDefault(const Constant('wallet'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF0E9F6E))();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  BoolColumn get includeInTotal => boolean().withDefault(const Constant(true))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Category')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => text()();
  TextColumn get icon => text().withDefault(const Constant('other'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF64748B))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Subcategory')
class Subcategories extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get icon => text().withDefault(const Constant('tag'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF64748B))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('User')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get email => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {email},
      ];
}

@DataClassName('Tx')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get type => text()();
  IntColumn get amount => integer()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime()();
  TextColumn get recurringId => text().nullable()();
  TextColumn get subcategoryId => text().nullable().references(Subcategories, #id)();
  TextColumn get status => text().withDefault(const Constant('posted'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RecurringRule')
class RecurringRules extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get type => text()();
  IntColumn get amount => integer()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get frequency => text().withDefault(const Constant('monthly'))();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get nextDueDate => dateTime()();
  BoolColumn get autoCreate => boolean().withDefault(const Constant(true))();
  BoolColumn get paused => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Budget')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get month => text()();
  IntColumn get limitAmount => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Goal')
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get targetAmount => integer()();
  IntColumn get savedAmount => integer().withDefault(const Constant(0))();
  DateTimeColumn get deadline => dateTime().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0xFF2563EB))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GoalContribution')
class GoalContributions extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text().references(Goals, #id)();
  IntColumn get amount => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Accounts,
  Users,
  Categories,
  Subcategories,
  Transactions,
  RecurringRules,
  Budgets,
  Goals,
  GoalContributions,
  Settings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  static QueryExecutor _openConnection() =>
      driftDatabase(name: 'finamind', native: const DriftNativeOptions());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _ensureCreditTables();
          await _seedCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(users);
            await m.createTable(subcategories);
            await m.addColumn(categories, categories.status);
            await m.addColumn(transactions, transactions.subcategoryId);
            await m.addColumn(transactions, transactions.status);
          }
          await _ensureCreditTables();
        },
      );

  // ---------------------------------------------------------------- seed

  Future<void> _seedCategories() async {
    final now = DateTime.now();
    const expense = [
      ('Moradia', 'home', 0xFF2563EB),
      ('Alimentação', 'groceries', 0xFF0E9F6E),
      ('Restaurantes', 'restaurant', 0xFFEA580C),
      ('Transporte', 'transport', 0xFF7C3AED),
      ('Saúde', 'health', 0xFFE11D48),
      ('Educação', 'education', 0xFF0891B2),
      ('Lazer', 'fun', 0xFFDB2777),
      ('Compras', 'shopping', 0xFF9333EA),
      ('Assinaturas', 'subscriptions', 0xFF65A30D),
      ('Contas fixas', 'bills', 0xFFF59E0B),
      ('Outros', 'other', 0xFF64748B),
    ];
    const income = [
      ('Salário', 'salary', 0xFF16A34A),
      ('Freelance', 'freelance', 0xFF2563EB),
      ('Investimentos', 'investment', 0xFF0D9488),
      ('Outras receitas', 'other', 0xFF64748B),
    ];

    await batch((b) {
      b.insertAll(categories, [
        for (final (name, icon, color) in expense)
          CategoriesCompanion.insert(
            id: newId(),
            name: name,
            type: kExpense,
            icon: Value(icon),
            color: Value(color),
            isDefault: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        for (final (name, icon, color) in income)
          CategoriesCompanion.insert(
            id: newId(),
            name: name,
            type: kIncome,
            icon: Value(icon),
            color: Value(color),
            isDefault: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
      ]);
    });
  }

  Future<void> ensureDefaultAccount() async {
    final rows = await (select(accounts)..where((t) => t.deletedAt.isNull())).get();
    if (rows.isNotEmpty) return;
    final now = DateTime.now();
    await into(accounts).insert(
      AccountsCompanion.insert(
        id: newId(),
        name: 'Carteira',
        type: const Value('cash'),
        color: const Value(0xFF0E9F6E),
        isDefault: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  // ------------------------------------------------------------- helpers

  DateTime get _now => DateTime.now();

  Expression<bool> _inDateRange(Transactions t, DateTime? from, DateTime? to) {
    if (from != null && to != null) return t.date.isBetweenValues(from, to);
    if (from != null) return t.date.isBiggerOrEqualValue(from);
    if (to != null) return t.date.isSmallerOrEqualValue(to);
    return const Constant(true);
  }

  Future<void> softDeleteFromRemote(String table, String id, DateTime deletedAt) async {
    await customUpdate(
      'UPDATE $table SET deleted_at = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withDateTime(deletedAt),
        Variable.withDateTime(deletedAt),
        Variable.withString(id),
      ],
      updates: {allTables.firstWhere((t) => t.actualTableName == table)},
    );
  }

  Future<void> upsertAccountFromRemote(AccountsCompanion data) =>
      into(accounts).insertOnConflictUpdate(data);

  Future<void> upsertCategoryFromRemote(CategoriesCompanion data) =>
      into(categories).insertOnConflictUpdate(data);

  Future<void> upsertTransactionFromRemote(TransactionsCompanion data) =>
      into(transactions).insertOnConflictUpdate(data);

  Future<void> upsertRecurringFromRemote(RecurringRulesCompanion data) =>
      into(recurringRules).insertOnConflictUpdate(data);

  Future<void> upsertBudgetFromRemote(BudgetsCompanion data) =>
      into(budgets).insertOnConflictUpdate(data);

  Future<void> upsertGoalFromRemote(GoalsCompanion data) =>
      into(goals).insertOnConflictUpdate(data);

  Future<void> upsertContributionFromRemote(GoalContributionsCompanion data) =>
      into(goalContributions).insertOnConflictUpdate(data);

  Future<Map<String, Map<String, dynamic>>> rowsForSync(String table, {DateTime? since}) async {
    final buffer = StringBuffer('SELECT * FROM $table');
    final vars = <Variable>[];
    if (since != null) {
      buffer.write(' WHERE updated_at > ?');
      vars.add(Variable.withDateTime(since));
    }
    final result = await customSelect(
      buffer.toString(),
      variables: vars,
      readsFrom: {allTables.firstWhere((t) => t.actualTableName == table)},
    ).get();
    return {
      for (final row in result)
        row.read<String>('id'): {
          for (final column in row.data.entries) column.key: column.value,
        },
    };
  }

  // ------------------------------------------------------------ accounts

  Stream<List<Account>> watchAccounts({bool includeArchived = false}) {
    final q = select(accounts)..where((t) => t.deletedAt.isNull());
    if (!includeArchived) q.where((t) => t.archived.equals(false));
    q.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return q.watch();
  }

  Future<List<Account>> getAccounts() =>
      (select(accounts)..where((t) => t.deletedAt.isNull() & t.archived.equals(false))).get();

  Future<int> accountBalance(String accountId, {DateTime? until}) async {
    final account = await (select(accounts)..where((t) => t.id.equals(accountId))).getSingleOrNull();
    if (account == null) return 0;
    var balance = account.initialBalance;

    final inflow = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions '
      'WHERE deleted_at IS NULL AND account_id = ? AND type = ? ${until != null ? 'AND date <= ?' : ''}',
      variables: [
        Variable.withString(accountId),
        Variable.withString(kIncome),
        if (until != null) Variable.withDateTime(until),
      ],
      readsFrom: {transactions},
    ).getSingle();
    balance += inflow.read<int>('total');

    final outflow = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions '
      'WHERE deleted_at IS NULL AND account_id = ? AND type = ? ${until != null ? 'AND date <= ?' : ''}',
      variables: [
        Variable.withString(accountId),
        Variable.withString(kExpense),
        if (until != null) Variable.withDateTime(until),
      ],
      readsFrom: {transactions},
    ).getSingle();
    balance -= outflow.read<int>('total');

    final sent = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions '
      'WHERE deleted_at IS NULL AND account_id = ? AND type = ? ${until != null ? 'AND date <= ?' : ''}',
      variables: [
        Variable.withString(accountId),
        Variable.withString(kTransfer),
        if (until != null) Variable.withDateTime(until),
      ],
      readsFrom: {transactions},
    ).getSingle();
    balance -= sent.read<int>('total');

    final received = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions '
      'WHERE deleted_at IS NULL AND to_account_id = ? AND type = ? ${until != null ? 'AND date <= ?' : ''}',
      variables: [
        Variable.withString(accountId),
        Variable.withString(kTransfer),
        if (until != null) Variable.withDateTime(until),
      ],
      readsFrom: {transactions},
    ).getSingle();
    balance += received.read<int>('total');

    return balance;
  }

  Future<int> totalBalance() async {
    final list = await getAccounts();
    var total = 0;
    for (final account in list) {
      if (!account.includeInTotal) continue;
      total += await accountBalance(account.id);
    }
    return total;
  }

  /// Define a conta padrão usada em novas transações e recorrentes.
  Future<void> setDefaultAccount(String id) async {
    await transaction(() async {
      await (update(accounts)..where((t) => t.isDefault.equals(true)))
          .write(AccountsCompanion(isDefault: const Value(false), updatedAt: Value(_now)));
      await (update(accounts)..where((t) => t.id.equals(id)))
          .write(AccountsCompanion(isDefault: const Value(true), updatedAt: Value(_now)));
    });
  }

  Future<Account?> defaultAccount() async {
    return (select(accounts)
          ..where((t) => t.isDefault.equals(true) & t.deletedAt.isNull() & t.archived.equals(false)))
        .getSingleOrNull();
  }

  /// Ativa/desativa uma conta (arquivada fica oculta, mas preserva saldos/transações).
  Future<void> setAccountArchived(String id, {required bool archived}) async {
    await (update(accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(archived: Value(archived), updatedAt: Value(_now)),
    );
  }

  Future<void> upsertAccount(AccountsCompanion data, {required String id}) async {
    await into(accounts).insertOnConflictUpdate(data.copyWith(id: Value(id), updatedAt: Value(_now)));
  }

  Future<void> softDelete(String table, String id) => customUpdate(
        'UPDATE $table SET deleted_at = ?, updated_at = ? WHERE id = ?',
        variables: [Variable.withDateTime(_now), Variable.withDateTime(_now), Variable.withString(id)],
        updates: {allTables.firstWhere((t) => t.actualTableName == table)},
      );

  // -------------------------------------------------------- transactions

  Stream<List<Tx>> watchTransactions({
    DateTime? from,
    DateTime? to,
    String? type,
    String? accountId,
    String? categoryId,
    String? search,
    int limit = 500,
  }) {
    var query = select(transactions)..where((t) => t.deletedAt.isNull());
    if (from != null) query.where((t) => t.date.isBiggerOrEqualValue(from));
    if (to != null) query.where((t) => t.date.isSmallerOrEqualValue(to));
    if (type != null) query.where((t) => t.type.equals(type));
    if (accountId != null) query.where((t) => t.accountId.equals(accountId));
    if (categoryId != null) query.where((t) => t.categoryId.equals(categoryId));
    final term = search?.trim();
    if (term != null && term.isNotEmpty) {
      final like = '%$term%';
      query.where((t) => t.description.like(like) | t.notes.like(like));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.date),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);
    query.limit(limit);
    return query.watch();
  }

  Future<void> upsertTransaction(TransactionsCompanion data, {required String id}) async {
    await into(transactions)
        .insertOnConflictUpdate(data.copyWith(id: Value(id), updatedAt: Value(_now)));
  }

  // ---------------------------------------------------------------- trash

  /// Transações apagadas (soft delete), para recuperação na lixeira.
  Stream<List<Tx>> watchDeletedTransactions({int limit = 100}) {
    final query = select(transactions)
      ..where((t) => t.deletedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)])
      ..limit(limit);
    return query.watch();
  }

  /// Reverte o soft delete (deleted_at = NULL) — restaurável na lixeira.
  Future<void> restoreRow(String table, String id) => customUpdate(
        'UPDATE $table SET deleted_at = NULL, updated_at = ? WHERE id = ?',
        variables: [Variable.withDateTime(_now), Variable.withString(id)],
        updates: {allTables.firstWhere((t) => t.actualTableName == table)},
      );

  /// Exclui definitivamente uma linha (não pode ser desfeito).
  Future<void> purgeRow(String table, String id) => customUpdate(
        'DELETE FROM $table WHERE id = ?',
        variables: [Variable.withString(id)],
        updates: {allTables.firstWhere((t) => t.actualTableName == table)},
      );

  /// Descrições já usadas (para sugestão e agrupamento por loja).
  Future<List<String>> recentDescriptions(String type, {int limit = 8}) async {
    final rows = await customSelect(
      'SELECT description, MAX(date) AS last FROM transactions '
      'WHERE deleted_at IS NULL AND type = ? AND description <> ? '
      'GROUP BY description ORDER BY last DESC LIMIT ?',
      variables: [
        Variable.withString(type),
        Variable.withString(''),
        Variable.withInt(limit),
      ],
      readsFrom: {transactions},
    ).get();
    return rows.map((r) => r.read<String>('description')).toList();
  }

  Future<int> sumByType(String type, {required DateTime from, required DateTime to}) async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions '
      'WHERE deleted_at IS NULL AND type = ? AND date >= ? AND date <= ?',
      variables: [Variable.withString(type), Variable.withDateTime(from), Variable.withDateTime(to)],
      readsFrom: {transactions},
    ).getSingle();
    return result.read<int>('total');
  }

  Future<Map<String, int>> spentByCategory({required DateTime from, required DateTime to}) async {
    final result = await customSelect(
      'SELECT COALESCE(category_id, \'sem-categoria\') AS cid, COALESCE(SUM(amount), 0) AS total '
      'FROM transactions WHERE deleted_at IS NULL AND type = ? AND date >= ? AND date <= ? '
      'GROUP BY cid ORDER BY total DESC',
      variables: [Variable.withString(kExpense), Variable.withDateTime(from), Variable.withDateTime(to)],
      readsFrom: {transactions},
    ).get();
    return {for (final row in result) row.read<String>('cid'): row.read<int>('total')};
  }

  /// Maior lançamento do tipo no período (0 quando não há).
  Future<int> maxAmountByType(String type, {DateTime? from, DateTime? to}) async {
    final clauses = <String>['deleted_at IS NULL', 'type = ?'];
    final vars = <Variable<Object>>[Variable.withString(type)];
    if (from != null) {
      clauses.add('date >= ?');
      vars.add(Variable.withDateTime(from));
    }
    if (to != null) {
      clauses.add('date <= ?');
      vars.add(Variable.withDateTime(to));
    }
    final row = await customSelect(
      'SELECT COALESCE(MAX(amount), 0) AS biggest FROM transactions WHERE ${clauses.join(' AND ')}',
      variables: vars,
      readsFrom: {transactions},
    ).getSingle();
    return row.read<int>('biggest');
  }

  Future<List<({String month, int income, int expense})>> monthlySummary(int months) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    final rows = await (select(transactions)
          ..where((t) => t.deletedAt.isNull() & t.date.isBiggerOrEqualValue(start)))
        .get();
    final grouped = <String, ({int income, int expense})>{};
    for (final row in rows) {
      final key = Formats.monthKey(row.date);
      final entry = grouped.putIfAbsent(key, () => (income: 0, expense: 0));
      if (row.type == kIncome) {
        grouped[key] = (income: entry.income + row.amount, expense: entry.expense);
      } else if (row.type == kExpense) {
        grouped[key] = (income: entry.income, expense: entry.expense + row.amount);
      }
    }
    final sorted = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [
      for (final entry in sorted)
        (month: entry.key, income: entry.value.income, expense: entry.value.expense),
    ];
  }

  // --------------------------------------------------- dados para charts

  /// Gastos (ou receitas) por categoria num período, para gráfico de pizza.
  Future<List<({String categoryId, int amount})>> categoryBreakdown(
    String type, {
    DateTime? from,
    DateTime? to,
  }) async {
    final rows = await (select(transactions)
          ..where((t) => t.deletedAt.isNull() & t.type.equals(type) & _inDateRange(t, from, to)))
        .get();
    final byCategory = <String, int>{};
    for (final row in rows) {
      final key = row.categoryId ?? 'sem-categoria';
      byCategory[key] = (byCategory[key] ?? 0) + row.amount;
    }
    final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in sorted) (categoryId: e.key, amount: e.value),
    ];
  }

  /// Série temporal de receitas/gastos para os gráficos de tendência.
  /// [kind]: 'semana' | 'mes' | 'ano' | 'anos'
  Future<List<({String label, int income, int expense})>> timeSeries(String kind) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (kind) {
      'semana' => today.subtract(const Duration(days: 6)),
      'mes' => DateTime(now.year, now.month, 1),
      'ano' => DateTime(now.year - 1, now.month, 1),
      _ => DateTime(now.year - 4, 1, 1),
    };

    final rows = await (select(transactions)
          ..where((t) => t.deletedAt.isNull() & t.date.isBiggerOrEqualValue(start)))
        .get();

    String labelOf(DateTime d) => switch (kind) {
          'semana' => Formats.shortDate(d),
          'mes' => '${d.day}',
          'ano' => Formats.monthKey(d),
          _ => '${d.year}',
        };

    final keyOf = _dateKeyFor(kind);
    final buckets = <String, ({int income, int expense})>{};
    for (final row in rows) {
      final key = keyOf?.call(row.date) ?? labelOf(row.date);
      final entry = buckets.putIfAbsent(key, () => (income: 0, expense: 0));
      if (row.type == kIncome) {
        buckets[key] = (income: entry.income + row.amount, expense: entry.expense);
      } else if (row.type == kExpense) {
        buckets[key] = (income: entry.income, expense: entry.expense + row.amount);
      }
    }

    // Garante os buckets vazios do intervalo (leva o eixo X completo).
    final orderedKeys = _bucketKeys(kind, start, today, labelOf);
    return [
      for (final key in orderedKeys)
        (
          label: key,
          income: buckets[key]?.income ?? 0,
          expense: buckets[key]?.expense ?? 0,
        ),
    ];
  }

  String Function(DateTime)? _dateKeyFor(String kind) => switch (kind) {
        'semana' => (d) => Formats.shortDate(d),
        'mes' => (d) => '${d.day}',
        'ano' => (d) => Formats.monthKey(d),
        _ => (d) => '${d.year}',
      };

  List<String> _bucketKeys(String kind, DateTime start, DateTime today, String Function(DateTime) labelOf) {
    final keys = <String>[];
    switch (kind) {
      case 'semana':
        for (var i = 0; i < 7; i++) {
          keys.add(labelOf(start.add(Duration(days: i))));
        }
      case 'mes':
        final days = DateTime(today.year, today.month + 1, 0).day;
        for (var i = 1; i <= days; i++) {
          keys.add('$i');
        }
      case 'ano':
        var cursor = DateTime(start.year, start.month, 1);
        while (!cursor.isAfter(today)) {
          keys.add(labelOf(cursor));
          cursor = DateTime(cursor.year, cursor.month + 1, 1);
        }
      default:
        for (var year = start.year; year <= today.year; year++) {
          keys.add('$year');
        }
    }
    return keys;
  }

  // ----------------------------------------------------------- categories

  Stream<List<Category>> watchCategories() {
    final query = select(categories)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.type),
        (t) => OrderingTerm.asc(t.name),
      ]);
    return query.watch();
  }

  Future<List<Category>> getCategories() =>
      (select(categories)..where((t) => t.deletedAt.isNull())).get();

  Future<void> upsertCategory(CategoriesCompanion data, {required String id}) async {
    await into(categories)
        .insertOnConflictUpdate(data.copyWith(id: Value(id), updatedAt: Value(_now)));
  }

  Future<void> setCategoryActive(String id, {required bool active}) async {
    await (update(categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        status: Value(active ? 'active' : 'inactive'),
        updatedAt: Value(_now),
      ),
    );
  }

  // --------------------------------------------------------- subcategorias

  /// Subcategorias opcionais de uma categoria; [categoryId] filtra por pai.
  Stream<List<Subcategory>> watchSubcategories({String? categoryId}) {
    final query = select(subcategories)..where((t) => t.deletedAt.isNull());
    if (categoryId != null) query.where((t) => t.categoryId.equals(categoryId));
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch();
  }

  Future<List<Subcategory>> getSubcategories({String? categoryId}) {
    final query = select(subcategories)..where((t) => t.deletedAt.isNull());
    if (categoryId != null) query.where((t) => t.categoryId.equals(categoryId));
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get();
  }

  Future<void> upsertSubcategory(SubcategoriesCompanion data, {required String id}) async {
    await into(subcategories)
        .insertOnConflictUpdate(data.copyWith(id: Value(id), updatedAt: Value(_now)));
  }

  Future<void> setSubcategoryActive(String id, {required bool active}) async {
    await (update(subcategories)..where((t) => t.id.equals(id))).write(
      SubcategoriesCompanion(
        status: Value(active ? 'active' : 'inactive'),
        updatedAt: Value(_now),
      ),
    );
  }

  // ----------------------------------------------------------------- users

  Future<void> upsertUser(UsersCompanion data, {required String id}) async {
    await into(users).insertOnConflictUpdate(data.copyWith(id: Value(id), updatedAt: Value(_now)));
  }

  Future<User?> userById(String id) async =>
      (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<User>> watchUsers() {
    return (select(users)..where((t) => t.deletedAt.isNull())).watch();
  }

  // ----------------------------------------------------------- recurring

  Stream<List<RecurringRule>> watchRecurring() {
    final query = select(recurringRules)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.nextDueDate)]);
    return query.watch();
  }

  Future<void> upsertRecurring(RecurringRulesCompanion data, {required String id}) async {
    await into(recurringRules)
        .insertOnConflictUpdate(data.copyWith(id: Value(id), updatedAt: Value(_now)));
  }

  DateTime nextDueDate({
    required String frequency,
    required int interval,
    required DateTime from,
  }) {
    switch (frequency) {
      case 'daily':
        return from.add(Duration(days: interval));
      case 'weekly':
        return from.add(Duration(days: 7 * interval));
      case 'yearly':
        return DateTime(from.year + interval, from.month, from.day);
      case 'monthly':
      default:
        final year = from.year + ((from.month - 1 + interval) ~/ 12);
        final month = (from.month - 1 + interval) % 12 + 1;
        final day = from.day;
        final lastDay = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, day > lastDay ? lastDay : day);
    }
  }

  Future<List<RecurringRule>> dueRecurring({DateTime? on}) async {
    final date = on ?? _now;
    return (select(recurringRules)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.paused.equals(false) &
              t.autoCreate.equals(true) &
              t.nextDueDate.isSmallerOrEqualValue(DateTime(date.year, date.month, date.day, 23, 59)))
          ..orderBy([(t) => OrderingTerm.asc(t.nextDueDate)]))
        .get();
  }

  Future<void> advanceRecurring(String id) async {
    final rule = await (select(recurringRules)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (rule == null) return;
    final next = nextDueDate(
      frequency: rule.frequency,
      interval: rule.interval,
      from: rule.nextDueDate,
    );
    final expired = rule.endDate != null && next.isAfter(rule.endDate!);
    await (update(recurringRules)..where((t) => t.id.equals(id))).write(RecurringRulesCompanion(
      nextDueDate: Value(next),
      paused: expired ? const Value(true) : const Value.absent(),
      updatedAt: Value(_now),
    ));
  }

  /// Recorrentes ativos com vencimento nos próximos [days] dias.
  Future<List<RecurringRule>> upcomingRecurring({int days = 30}) async {
    final now = _now;
    final end = DateTime(now.year, now.month, now.day + days, 23, 59);
    return (select(recurringRules)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.paused.equals(false) &
              t.nextDueDate.isBetweenValues(now, end))
          ..orderBy([(t) => OrderingTerm.asc(t.nextDueDate)]))
        .get();
  }

  /// Soma dos próximos lançamentos recorrentes até [until] (receitas menos gastos).
  Future<int> projectedDeltaUntil({required DateTime until}) async {
    final rules = await (select(recurringRules)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.paused.equals(false) &
              t.nextDueDate.isSmallerOrEqualValue(until)))
        .get();
    var delta = 0;
    for (final rule in rules) {
      if (rule.type == kIncome) {
        delta += rule.amount;
      } else if (rule.type == kExpense) {
        delta -= rule.amount;
      }
    }
    return delta;
  }

  // -------------------------------------------------------------- budgets

  Stream<List<Budget>> watchBudgets(String month) {
    final query = select(budgets)
      ..where((t) => t.deletedAt.isNull() & t.month.equals(month))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch();
  }

  Future<void> upsertBudget(BudgetsCompanion data, {required String id}) async {
    await into(budgets)
        .insertOnConflictUpdate(data.copyWith(id: Value(id), updatedAt: Value(_now)));
  }

  // ---------------------------------------------------------------- goals

  Stream<List<Goal>> watchGoals() {
    final query = select(goals)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.completed),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.watch();
  }

  Future<void> upsertGoal(GoalsCompanion data, {required String id}) async {
    await into(goals).insertOnConflictUpdate(data.copyWith(id: Value(id), updatedAt: Value(_now)));
  }

  Stream<List<GoalContribution>> watchContributions(String goalId) {
    final query = select(goalContributions)
      ..where((t) => t.deletedAt.isNull() & t.goalId.equals(goalId))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.watch();
  }

  Future<void> addContribution({
    required String goalId,
    required int amount,
    required String note,
  }) async {
    final now = _now;
    await into(goalContributions).insert(GoalContributionsCompanion.insert(
      id: newId(),
      goalId: goalId,
      amount: amount,
      note: Value(note),
      date: Value(now),
      updatedAt: Value(now),
    ));
    await _recomputeGoal(goalId);
  }

  Future<void> removeContribution(String id) async {
    final row = await (select(goalContributions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await softDelete('goal_contributions', id);
    await _recomputeGoal(row.goalId);
  }

  Future<void> _recomputeGoal(String goalId) async {
    final total = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM goal_contributions '
      'WHERE deleted_at IS NULL AND goal_id = ?',
      variables: [Variable.withString(goalId)],
      readsFrom: {goalContributions},
    ).getSingle();
    final goal = await (select(goals)..where((t) => t.id.equals(goalId))).getSingleOrNull();
    if (goal == null) return;
    final saved = total.read<int>('total');
    await (update(goals)..where((t) => t.id.equals(goalId))).write(GoalsCompanion(
      savedAmount: Value(saved),
      completed: Value(saved >= goal.targetAmount),
      updatedAt: Value(_now),
    ));
  }

  // ------------------------------------------------------------- settings

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(key: key, value: value, updatedAt: Value(_now)),
    );
  }

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchSetting(String key) {
    final query = select(settings)..where((t) => t.key.equals(key));
    return query.watchSingleOrNull().map((row) => row?.value);
  }

  // ----------------------------------------------------- cartões de crédito

  final _creditRevision = StreamController<void>.broadcast();

  void _bumpCredit() {
    if (!_creditRevision.isClosed) _creditRevision.add(null);
  }

  Stream<T> _creditStream<T>(Future<T> Function() load) async* {
    yield await load();
    await for (final _ in _creditRevision.stream) {
      yield await load();
    }
  }

  static DateTime _monthsAhead(DateTime base, int months) =>
      DateTime(base.year, base.month + months, base.day);

  Future<void> _ensureCreditTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS credit_cards (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        account_id TEXT NOT NULL,
        credit_limit INTEGER NOT NULL DEFAULT 0,
        closing_day INTEGER NOT NULL DEFAULT 25,
        due_day INTEGER NOT NULL DEFAULT 10,
        color INTEGER NOT NULL DEFAULT 4285430624,
        active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS purchases (
        id TEXT NOT NULL PRIMARY KEY,
        credit_card_id TEXT NOT NULL,
        category_id TEXT,
        subcategory_id TEXT,
        establishment TEXT NOT NULL DEFAULT '',
        total_amount INTEGER NOT NULL DEFAULT 0,
        installment_count INTEGER NOT NULL DEFAULT 1,
        installment_amount INTEGER NOT NULL DEFAULT 0,
        purchase_date INTEGER NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        paid INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS purchase_parcels (
        id TEXT NOT NULL PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        installment_number INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        due_date INTEGER NOT NULL,
        paid INTEGER NOT NULL DEFAULT 0,
        paid_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await _ensureColumn('transactions', 'credit_card_id', 'TEXT');
    await _ensureColumn('transactions', 'purchase_id', 'TEXT');
  }

  Future<void> _ensureColumn(String table, String column, String type) async {
    final cols = await customSelect('PRAGMA table_info($table)').get();
    final exists = cols.any((r) => r.read<String>('name') == column);
    if (!exists) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  static DateTime _cardDateTime(int millis) => DateTime.fromMillisecondsSinceEpoch(millis);

  CreditCard _cardFromRow(QueryRow row) => CreditCard(
        id: row.read<String>('id'),
        name: row.read<String>('name'),
        accountId: row.read<String>('account_id'),
        creditLimit: row.read<int>('credit_limit'),
        closingDay: row.read<int>('closing_day'),
        dueDay: row.read<int>('due_day'),
        color: row.read<int>('color'),
        active: row.read<int>('active') == 1,
        createdAt: _cardDateTime(row.read<int>('created_at')),
        updatedAt: _cardDateTime(row.read<int>('updated_at')),
        deletedAt: row.readNullable<int>('deleted_at') == null
            ? null
            : _cardDateTime(row.readNullable<int>('deleted_at')!),
      );

  Purchase _purchaseFromRow(QueryRow row) => Purchase(
        id: row.read<String>('id'),
        creditCardId: row.read<String>('credit_card_id'),
        categoryId: row.readNullable<String>('category_id'),
        subcategoryId: row.readNullable<String>('subcategory_id'),
        establishment: row.read<String>('establishment'),
        totalAmount: row.read<int>('total_amount'),
        installmentCount: row.read<int>('installment_count'),
        installmentAmount: row.read<int>('installment_amount'),
        purchaseDate: _cardDateTime(row.read<int>('purchase_date')),
        description: row.read<String>('description'),
        paid: row.read<int>('paid') == 1,
        createdAt: _cardDateTime(row.read<int>('created_at')),
        updatedAt: _cardDateTime(row.read<int>('updated_at')),
        deletedAt: row.readNullable<int>('deleted_at') == null
            ? null
            : _cardDateTime(row.readNullable<int>('deleted_at')!),
      );

  PurchaseParcel _parcelFromRow(QueryRow row) => PurchaseParcel(
        id: row.read<String>('id'),
        purchaseId: row.read<String>('purchase_id'),
        installmentNumber: row.read<int>('installment_number'),
        amount: row.read<int>('amount'),
        dueDate: _cardDateTime(row.read<int>('due_date')),
        paid: row.read<int>('paid') == 1,
        paidAt: row.readNullable<int>('paid_at') == null
            ? null
            : _cardDateTime(row.readNullable<int>('paid_at')!),
        createdAt: _cardDateTime(row.read<int>('created_at')),
        updatedAt: _cardDateTime(row.read<int>('updated_at')),
      );

  Stream<List<CreditCard>> watchCreditCards({bool includeInactive = true}) => _creditStream(
        () => getCreditCards(includeInactive: includeInactive),
      );

  Future<List<CreditCard>> getCreditCards({bool includeInactive = true}) async {
    final rows = await customSelect(
      'SELECT * FROM credit_cards '
      'WHERE deleted_at IS NULL ${includeInactive ? '' : 'AND active = 1'} '
      'ORDER BY name COLLATE NOCASE ASC',
    ).get();
    return rows.map(_cardFromRow).toList();
  }

  Future<CreditCard?> getCreditCard(String id) async {
    final row = await customSelect(
      'SELECT * FROM credit_cards WHERE id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(id)],
    ).getSingleOrNull();
    return row == null ? null : _cardFromRow(row);
  }

  Future<int> creditCardUsed(String cardId) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(p.amount), 0) AS total '
      'FROM purchase_parcels p '
      'JOIN purchases pu ON pu.id = p.purchase_id '
      'WHERE p.paid = 0 AND pu.deleted_at IS NULL AND pu.credit_card_id = ?',
      variables: [Variable.withString(cardId)],
    ).getSingle();
    return row.read<int>('total');
  }

  Stream<List<CreditCardUsage>> watchCreditCardsWithUsage() => _creditStream(
        () async {
          final cards = await getCreditCards();
          final result = <CreditCardUsage>[];
          for (final card in cards) {
            result.add(CreditCardUsage(card: card, used: await creditCardUsed(card.id)));
          }
          return result;
        },
      );

  Future<void> saveCreditCard({
    String? id,
    required String name,
    required String accountId,
    required int creditLimit,
    required int closingDay,
    required int dueDay,
    int color = 4285430624,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final finalId = id ?? newId();
    final existing = id == null ? null : await getCreditCard(id);
    if (existing == null) {
      await customInsert(
        'INSERT INTO credit_cards (id, name, account_id, credit_limit, closing_day, due_day, color, active, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)',
        variables: [
          Variable.withString(finalId),
          Variable.withString(name),
          Variable.withString(accountId),
          Variable.withInt(creditLimit),
          Variable.withInt(closingDay),
          Variable.withInt(dueDay),
          Variable.withInt(color),
          Variable.withInt(now),
          Variable.withInt(now),
        ],
      );
    } else {
      await customUpdate(
        'UPDATE credit_cards SET name = ?, account_id = ?, credit_limit = ?, closing_day = ?, due_day = ?, color = ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withString(name),
          Variable.withString(accountId),
          Variable.withInt(creditLimit),
          Variable.withInt(closingDay),
          Variable.withInt(dueDay),
          Variable.withInt(color),
          Variable.withInt(now),
          Variable.withString(finalId),
        ],
      );
    }
    _bumpCredit();
  }

  Future<void> setCreditCardActive(String id, {required bool active}) async {
    await customUpdate(
      'UPDATE credit_cards SET active = ?, updated_at = ? WHERE id = ?',
      variables: [Variable.withInt(active ? 1 : 0), Variable.withInt(DateTime.now().millisecondsSinceEpoch), Variable.withString(id)],
    );
    _bumpCredit();
  }

  Future<void> deleteCreditCard(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await customUpdate(
      'UPDATE credit_cards SET deleted_at = ?, updated_at = ? WHERE id = ?',
      variables: [Variable.withInt(now), Variable.withInt(now), Variable.withString(id)],
    );
    final purchases = await customSelect(
      'SELECT id FROM purchases WHERE credit_card_id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(id)],
    ).get();
    for (final row in purchases) {
      await _softDeletePurchaseAndParcels(row.read<String>('id'), now);
    }
    _bumpCredit();
  }

  // ------------------------------------------------- compras no cartão

  Stream<List<Purchase>> watchPurchases({String? cardId}) => _creditStream(
        () => getPurchases(cardId: cardId),
      );

  Future<List<Purchase>> getPurchases({String? cardId}) async {
    final where = cardId == null ? '' : ' AND credit_card_id = ?';
    final rows = await customSelect(
      'SELECT * FROM purchases '
      'WHERE deleted_at IS NULL$where '
      'ORDER BY purchase_date DESC, created_at DESC',
      variables: [if (cardId != null) Variable.withString(cardId)],
    ).get();
    return rows.map(_purchaseFromRow).toList();
  }

  Future<Purchase?> getPurchase(String id) async {
    final row = await customSelect(
      'SELECT * FROM purchases WHERE id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(id)],
    ).getSingleOrNull();
    return row == null ? null : _purchaseFromRow(row);
  }

  Future<List<PurchaseParcel>> getParcels(String purchaseId) async {
    final rows = await customSelect(
      'SELECT * FROM purchase_parcels WHERE purchase_id = ? ORDER BY installment_number ASC',
      variables: [Variable.withString(purchaseId)],
    ).get();
    return rows.map(_parcelFromRow).toList();
  }

  /// Distribui o total em N parcelas garantindo que a soma seja o valor total.
  static List<int> splitAmount(int total, int count) {
    if (count <= 1) return [total];
    final base = total ~/ count;
    final remainder = total % count;
    return [for (var i = 0; i < count; i++) base + (i < remainder ? 1 : 0)];
  }

  Future<void> savePurchase({
    String? id,
    required String creditCardId,
    String? categoryId,
    String? subcategoryId,
    required String establishment,
    required int totalAmount,
    required int installmentCount,
    required DateTime purchaseDate,
    String description = '',
  }) async {
    final card = await getCreditCard(creditCardId);
    if (card == null) throw StateError('Cartão não encontrado.');

    final now = DateTime.now();

    if (id != null) {
      await _removePurchaseChildren(id, now);
    }

    final finalId = id ?? newId();
    final values = splitAmount(totalAmount, installmentCount);

    await customInsert(
      'INSERT INTO purchases (id, credit_card_id, category_id, subcategory_id, establishment, total_amount, installment_count, installment_amount, purchase_date, description, paid, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET credit_card_id = excluded.credit_card_id, category_id = excluded.category_id, subcategory_id = excluded.subcategory_id, establishment = excluded.establishment, '
      'total_amount = excluded.total_amount, installment_count = excluded.installment_count, installment_amount = excluded.installment_amount, purchase_date = excluded.purchase_date, '
      'description = excluded.description, paid = 0, updated_at = excluded.updated_at',
      variables: [
        Variable.withString(finalId),
        Variable.withString(creditCardId),
        categoryId == null ? const Variable(null) : Variable.withString(categoryId),
        subcategoryId == null ? const Variable(null) : Variable.withString(subcategoryId),
        Variable.withString(establishment),
        Variable.withInt(totalAmount),
        Variable.withInt(installmentCount),
        Variable.withInt(values.first),
        Variable.withInt(purchaseDate.millisecondsSinceEpoch),
        Variable.withString(description),
        Variable.withInt(now.millisecondsSinceEpoch),
        Variable.withInt(now.millisecondsSinceEpoch),
      ],
    );

    for (var i = 0; i < values.length; i++) {
      final parcelId = newId();
      final dueDate = _monthsAhead(DateTime(purchaseDate.year, purchaseDate.month, card.closingDay), i);
      await customInsert(
        'INSERT INTO purchase_parcels (id, purchase_id, installment_number, amount, due_date, paid, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, 0, ?, ?)',
        variables: [
          Variable.withString(parcelId),
          Variable.withString(finalId),
          Variable.withInt(i + 1),
          Variable.withInt(values[i]),
          Variable.withInt(dueDate.millisecondsSinceEpoch),
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withInt(now.millisecondsSinceEpoch),
        ],
      );

      final label = establishment.trim().isEmpty
          ? (description.trim().isEmpty ? 'Compra no cartão' : description.trim())
          : establishment.trim();
      final txId = newId();
      await into(transactions).insert(TransactionsCompanion.insert(
        id: txId,
        accountId: card.accountId,
        categoryId: Value(categoryId),
        type: kExpense,
        amount: values[i],
        description: Value(installmentCount > 1
            ? '$label (${i + 1}/$installmentCount)'
            : label),
        date: dueDate,
      ));
      await customUpdate(
        'UPDATE transactions SET credit_card_id = ?, purchase_id = ? WHERE id = ?',
        variables: [Variable.withString(creditCardId), Variable.withString(finalId), Variable.withString(txId)],
      );
    }

    _bumpCredit();
  }

  Future<void> _removePurchaseChildren(String purchaseId, DateTime now) async {
    await customUpdate(
      'DELETE FROM purchase_parcels WHERE purchase_id = ?',
      variables: [Variable.withString(purchaseId)],
    );
    await customUpdate(
      'UPDATE transactions SET deleted_at = ?, updated_at = ? WHERE purchase_id = ?',
      variables: [Variable.withDateTime(now), Variable.withDateTime(now), Variable.withString(purchaseId)],
    );
  }

  Future<void> _softDeletePurchaseAndParcels(String purchaseId, int nowMillis) async {
    await customUpdate(
      'UPDATE purchases SET deleted_at = ?, updated_at = ? WHERE id = ?',
      variables: [Variable.withInt(nowMillis), Variable.withInt(nowMillis), Variable.withString(purchaseId)],
    );
    await customUpdate(
      'UPDATE transactions SET deleted_at = ?, updated_at = ? WHERE purchase_id = ?',
      variables: [Variable.withDateTime(DateTime.fromMillisecondsSinceEpoch(nowMillis)), Variable.withDateTime(DateTime.fromMillisecondsSinceEpoch(nowMillis)), Variable.withString(purchaseId)],
    );
    await customUpdate(
      'UPDATE purchase_parcels SET paid = 1, paid_at = ? WHERE purchase_id = ? AND paid = 0',
      variables: [Variable.withInt(nowMillis), Variable.withString(purchaseId)],
    );
  }

  /// Cancela (soft delete) uma compra, suas parcelas e os lançamentos gerados.
  Future<void> cancelPurchase(String id) async {
    await _softDeletePurchaseAndParcels(id, DateTime.now().millisecondsSinceEpoch);
    _bumpCredit();
  }

  Future<void> setParcelPaid(String parcelId, {required bool paid}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await customUpdate(
      'UPDATE purchase_parcels SET paid = ?, paid_at = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withInt(paid ? 1 : 0),
        paid ? Variable.withInt(now) : const Variable(null),
        Variable.withInt(now),
        Variable.withString(parcelId),
      ],
    );
    final row = await customSelect(
      'SELECT purchase_id FROM purchase_parcels WHERE id = ?',
      variables: [Variable.withString(parcelId)],
    ).getSingleOrNull();
    if (row != null) {
      final purchaseId = row.read<String>('purchase_id');
      final open = await customSelect(
        'SELECT COUNT(*) AS c FROM purchase_parcels WHERE purchase_id = ? AND paid = 0',
        variables: [Variable.withString(purchaseId)],
      ).getSingle();
      await customUpdate(
        'UPDATE purchases SET paid = ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withInt(open.read<int>('c') == 0 ? 1 : 0),
          Variable.withInt(now),
          Variable.withString(purchaseId),
        ],
      );
    }
    _bumpCredit();
  }

  // ------------------------------------------------------- metas mensais

  /// Metas do mês: limite de gastos, arrecadação e poupança (centavos).
  Future<({int expense, int income, int savings})> monthlyGoals() async {
    Future<int> readInt(String key) async =>
        int.tryParse(await getSetting(key) ?? '') ?? 0;
    return (
      expense: await readInt('goal_expense'),
      income: await readInt('goal_income'),
      savings: await readInt('goal_savings'),
    );
  }

  Future<void> setMonthlyGoals({
    required int expense,
    required int income,
    required int savings,
  }) async {
    await setSetting('goal_expense', '$expense');
    await setSetting('goal_income', '$income');
    await setSetting('goal_savings', '$savings');
  }

  // -------------------------------------------------------------- backup

    Future<void> clearAllData() async {
      await delete(settings).go();
      await delete(goalContributions).go();
      await delete(goals).go();
      await delete(budgets).go();
      await delete(recurringRules).go();
      await delete(transactions).go();
      await delete(categories).go();
      await delete(accounts).go();
      await customStatement('DELETE FROM purchase_parcels');
      await customStatement('DELETE FROM purchases');
      await customStatement('DELETE FROM credit_cards');
      await _seedCategories();
      await ensureDefaultAccount();
    }
}
