import 'package:drift/drift.dart';

import '../core/utils.dart';
import 'database.dart';

/// Modo demonstração: preenche o app com uma vida financeira completa
/// (6 meses de lançamentos, orçamentos, metas, recorrentes e cartão) para
/// mostrar como cada tela funciona sem precisar cadastrar nada.
///
/// Carregar o demo substitui todo o conteúdo atual e por isso a UI sempre
/// confirma antes; [clear] volta o app ao estado limpo (contas e categorias
/// padrão recriadas).
abstract final class DemoData {
  static const settingKey = 'demo_active';

  static Future<bool> isLoaded(AppDatabase db) async =>
      (await db.getSetting(settingKey)) == 'true';

  static Future<void> load(AppDatabase db) async {
    await db.clearAllData();
    /// O clearAllData recria a conta padrão; o demo traz as contas dele.
    await db.delete(db.accounts).go();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final categories = {for (final c in await db.getCategories()) c.name: c.id};

    final checking = newId();
    final wallet = newId();
    final savings = newId();
    final cardAccount = newId();
    final oldAccount = newId();

    await db.batch((b) {
      b.insertAll(db.accounts, [
        AccountsCompanion.insert(
          id: checking,
          name: 'Conta corrente',
          type: const Value('checking'),
          color: const Value(0xFF2563EB),
          initialBalance: const Value(320000),
          isDefault: const Value(true),
        ),
        AccountsCompanion.insert(
          id: wallet,
          name: 'Carteira',
          type: const Value('cash'),
          color: const Value(0xFF0E9F6E),
          initialBalance: const Value(50000),
        ),
        AccountsCompanion.insert(
          id: savings,
          name: 'Poupança',
          type: const Value('savings'),
          color: const Value(0xFF0D9488),
          initialBalance: const Value(1500000),
        ),
        AccountsCompanion.insert(
          id: cardAccount,
          name: 'Cartão de crédito',
          type: const Value('credit'),
          color: const Value(0xFF7C3AED),
        ),
        AccountsCompanion.insert(
          id: oldAccount,
          name: 'Conta antiga',
          type: const Value('checking'),
          color: const Value(0xFF64748B),
          archived: const Value(true),
        ),
      ]);
    });

    Future<void> tx({
      required String accountId,
      required String type,
      required int amount,
      required DateTime date,
      String? category,
      String? toAccountId,
      String description = '',
      String notes = '',
    }) async {
      final id = newId();
      await db.upsertTransaction(
        TransactionsCompanion.insert(
          id: id,
          accountId: accountId,
          type: type,
          amount: amount,
          date: date,
          categoryId: Value(category == null ? null : categories[category]),
          toAccountId: Value(toAccountId),
          description: Value(description),
          notes: Value(notes),
        ),
        id: id,
      );
    }

    for (var back = 5; back >= 0; back--) {
      final month = DateTime(now.year, now.month - back, 1);
      final drift = 1 + (back % 3) * 0.06;
      DateTime day(int value) {
        final candidate = DateTime(month.year, month.month, value, 12);
        return candidate.isAfter(now) ? DateTime(today.year, today.month, today.day, 12) : candidate;
      }

      int scaled(int cents) => (cents * drift).round();

      await tx(
        accountId: checking,
        type: kIncome,
        amount: scaled(485000),
        date: day(5),
        category: 'Salário',
        description: 'Salário mensal',
      );
      await tx(
        accountId: checking,
        type: kExpense,
        amount: 145000,
        date: day(6),
        category: 'Moradia',
        description: 'Aluguel',
      );
      await tx(
        accountId: checking,
        type: kExpense,
        amount: scaled(61240),
        date: day(3),
        category: 'Alimentação',
        description: 'Supermercado do mês',
      );
      await tx(
        accountId: wallet,
        type: kExpense,
        amount: scaled(38990),
        date: day(18),
        category: 'Alimentação',
        description: 'Feira livre',
      );
      await tx(
        accountId: checking,
        type: kExpense,
        amount: scaled(32890),
        date: day(12),
        category: 'Contas fixas',
        description: 'Luz, água e internet',
      );
      await tx(
        accountId: checking,
        type: kExpense,
        amount: 5590,
        date: day(8),
        category: 'Assinaturas',
        description: 'Streaming',
      );
      await tx(
        accountId: wallet,
        type: kExpense,
        amount: scaled(24000),
        date: day(10),
        category: 'Transporte',
        description: 'Combustível',
      );
      await tx(
        accountId: wallet,
        type: kExpense,
        amount: scaled(18600),
        date: day(14),
        category: 'Restaurantes',
        description: 'Almoço fora',
      );
      await tx(
        accountId: checking,
        type: kExpense,
        amount: scaled(12000),
        date: day(20),
        category: 'Lazer',
        description: 'Cinema',
      );
      await tx(
        accountId: checking,
        type: kExpense,
        amount: 8990,
        date: day(22),
        category: 'Saúde',
        description: 'Farmácia',
      );
      await tx(
        accountId: checking,
        type: kIncome,
        amount: scaled(65000),
        date: day(24),
        category: 'Freelance',
        description: 'Projeto extra',
      );
      await tx(
        accountId: checking,
        type: kTransfer,
        amount: 70000,
        date: day(7),
        toAccountId: savings,
        description: 'Transferência para a poupança',
      );
    }

    final monthKey = Formats.monthKey(now);
    await db.batch((b) {
      b.insertAll(db.budgets, [
        for (final (name, limit) in const [
          ('Alimentação', 120000),
          ('Transporte', 40000),
          ('Lazer', 25000),
          ('Contas fixas', 45000),
          ('Restaurantes', 20000),
        ])
          BudgetsCompanion.insert(
            id: newId(),
            categoryId: categories[name]!,
            month: monthKey,
            limitAmount: limit,
          ),
      ]);
    });

    Future<void> goal({
      required String name,
      required int target,
      required List<int> contributions,
      int color = 0xFF2563EB,
      DateTime? deadline,
    }) async {
      final id = newId();
      await db.upsertGoal(
        GoalsCompanion.insert(
          id: id,
          name: name,
          targetAmount: target,
          color: Value(color),
          deadline: Value(deadline),
        ),
        id: id,
      );
      for (final value in contributions) {
        await db.addContribution(goalId: id, amount: value, note: 'Depósito mensal');
      }
    }

    await goal(
      name: 'Reserva de emergência',
      target: 2000000,
      contributions: const [250000, 250000, 300000],
      deadline: DateTime(now.year + 1, 6, 30),
    );
    await goal(
      name: 'Viagem para o Nordeste',
      target: 800000,
      contributions: const [160000, 160000],
      color: 0xFF0D9488,
      deadline: DateTime(now.year + 1, 1, 15),
    );
    await goal(
      name: 'Notebook novo',
      target: 450000,
      contributions: const [450000],
      color: 0xFF9333EA,
    );

    Future<void> recurring({
      required String description,
      required String type,
      required int amount,
      required int dueInDays,
      String? category,
      String frequency = 'monthly',
      bool paused = false,
      bool autoCreate = true,
    }) async {
      final id = newId();
      final due = today.add(Duration(days: dueInDays));
      await db.upsertRecurring(
        RecurringRulesCompanion.insert(
          id: id,
          accountId: checking,
          type: type,
          amount: amount,
          startDate: due,
          nextDueDate: due,
          categoryId: Value(category == null ? null : categories[category]),
          description: Value(description),
          frequency: Value(frequency),
          paused: Value(paused),
          autoCreate: Value(autoCreate),
        ),
        id: id,
      );
    }

    await recurring(description: 'Salário', type: kIncome, amount: 485000, dueInDays: 2, category: 'Salário');
    await recurring(description: 'Aluguel', type: kExpense, amount: 145000, dueInDays: 4, category: 'Moradia');
    await recurring(
      description: 'Internet fibra',
      type: kExpense,
      amount: 9990,
      dueInDays: 7,
      category: 'Contas fixas',
    );
    await recurring(
      description: 'Streaming',
      type: kExpense,
      amount: 5590,
      dueInDays: 11,
      category: 'Assinaturas',
      autoCreate: false,
    );
    await recurring(
      description: 'Academia',
      type: kExpense,
      amount: 12900,
      dueInDays: 16,
      category: 'Saúde',
      paused: true,
    );

    final card = newId();
    await db.saveCreditCard(
      id: card,
      name: 'Cartão Nubank',
      accountId: cardAccount,
      creditLimit: 500000,
      closingDay: 20,
      dueDay: 28,
      color: 0xFF7C3AED,
    );
    await db.savePurchase(
      id: newId(),
      creditCardId: card,
      categoryId: categories['Compras'],
      establishment: 'Notebook Dell',
      totalAmount: 450000,
      installmentCount: 10,
      purchaseDate: DateTime(now.year, now.month - 4, 4),
    );
    await db.savePurchase(
      id: newId(),
      creditCardId: card,
      categoryId: categories['Alimentação'],
      establishment: 'Supermercado Extra',
      totalAmount: 38000,
      installmentCount: 3,
      purchaseDate: DateTime(now.year, now.month - 1, 9),
    );
    await db.savePurchase(
      id: newId(),
      creditCardId: card,
      categoryId: categories['Saúde'],
      establishment: 'Drogaria São Paulo',
      totalAmount: 8990,
      installmentCount: 1,
      purchaseDate: DateTime(now.year, now.month - 1, 13),
    );

    await db.setMonthlyGoals(expense: 350000, income: 550000, savings: 150000);
    await db.setSetting(settingKey, 'true');
  }

  /// Volta o app ao estado inicial: sem lançamentos, com as categorias padrão
  /// e uma conta Carteira.
  static Future<void> clear(AppDatabase db) async {
    await db.clearAllData();
    await db.setSetting(settingKey, 'false');
  }
}
