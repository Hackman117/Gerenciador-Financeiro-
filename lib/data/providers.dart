import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'credit_models.dart';
import 'database.dart';

abstract final class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String appName = 'FinaMind';
  static const String syncUrl = supabaseUrl;

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Saldo de uma conta específica.
final accountBalanceProvider =
    FutureProvider.autoDispose.family<int, String>((ref, accountId) {
  return ref.watch(databaseProvider).accountBalance(accountId);
});

StreamProvider<List<Account>> accountsProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).watchAccounts();
});

/// Contas desativadas (arquivadas), para reativação.
StreamProvider<List<Account>> archivedAccountsProvider = StreamProvider((ref) {
  return ref
      .watch(databaseProvider)
      .watchAccounts(includeArchived: true)
      .map((list) => list.where((a) => a.archived).toList());
});

/// Uma conta específica (ativa ou desativada), para a visualização detalhada.
final accountByIdProvider =
    StreamProvider.autoDispose.family<Account?, String>((ref, String id) {
  return ref.watch(databaseProvider).watchAccounts(includeArchived: true).map((list) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == id) return list[i];
    }
    return null;
  });
});

StreamProvider<List<Category>> categoriesProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).watchCategories();
});

StreamProvider<List<Category>> activeCategoriesProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).watchCategories().map(
        (list) => list.where((c) => c.status != 'inactive').toList(),
      );
});

StreamProvider<List<Subcategory>> subcategoriesProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).watchSubcategories();
});

final subcategoriesByCategoryProvider =
    StreamProvider.autoDispose.family<List<Subcategory>, String>((ref, categoryId) {
  return ref.watch(databaseProvider).watchSubcategories(categoryId: categoryId).map(
        (list) => list.where((s) => s.status != 'inactive').toList(),
      );
});

/// Cartões de crédito ativos (e inativos, quando ``includeInactive`).
StreamProvider<List<CreditCard>> creditCardsProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).watchCreditCards();
});

/// Cartões com o consumo atual do limite.
StreamProvider<List<CreditCardUsage>> creditCardsUsageProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).watchCreditCardsWithUsage();
});

/// Compras no cartão (opcionalmente filtradas por um cartão).
final purchasesProvider =
    StreamProvider.autoDispose.family<List<Purchase>, String?>((ref, cardId) {
  return ref.watch(databaseProvider).watchPurchases(cardId: cardId);
});

/// Parcelas de uma compra.
final purchaseParcelsProvider =
    StreamProvider.autoDispose.family<List<PurchaseParcel>, String>((ref, purchaseId) {
  return ref.watch(databaseProvider).getParcels(purchaseId).asStream();
});

StreamProvider<List<RecurringRule>> recurringProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).watchRecurring();
});

StreamProvider<List<Goal>> goalsProvider = StreamProvider((ref) {
  return ref.watch(databaseProvider).watchGoals();
});

class DashboardData {
  final int balance;
  final int income;
  final int expense;
  final int largestExpense;
  final double dailyAverage;
  final double savingsRate;
  final List<({String categoryId, int amount})> expenses;
  final List<({String categoryId, int amount})> incomes;
  final Map<String, Category> categories;
  final List<({String label, int income, int expense})> monthly;
  final List<Tx> recent;
  final List<Account> accounts;

  const DashboardData({
    required this.balance,
    required this.income,
    required this.expense,
    required this.largestExpense,
    required this.dailyAverage,
    required this.savingsRate,
    required this.expenses,
    required this.incomes,
    required this.categories,
    required this.monthly,
    required this.recent,
    required this.accounts,
  });

  int get savings => income - expense;
}

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final db = ref.watch(databaseProvider);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0);

  final balance = await db.totalBalance();
  final income = await db.sumByType(kIncome, from: monthStart, to: monthEnd);
  final expense = await db.sumByType(kExpense, from: monthStart, to: monthEnd);

  final expensesPie = await db.categoryBreakdown(kExpense, from: monthStart, to: monthEnd);
  final incomesPie = await db.categoryBreakdown(kIncome, from: monthStart, to: monthEnd);

  final cats = await db.getCategories();
  final categories = {for (final c in cats) c.id: c};

  final monthly = await db.monthlySummary(6);
  final recent = await db.watchTransactions(from: monthStart, limit: 5).first;
  final accounts = await db.getAccounts();

  var largest = 0;
  final txThisMonth = await db.watchTransactions(from: monthStart, limit: 100000).first;
  for (final t in txThisMonth) {
    if (t.type == kExpense && t.amount > largest) largest = t.amount;
  }
  final daysElapsed = now.day;
  final dailyAvg = daysElapsed == 0 ? 0.0 : expense / daysElapsed;
  final savingsRate = income == 0 ? 0.0 : ((income - expense) / income).clamp(0.0, 1.0);

  return DashboardData(
    balance: balance,
    income: income,
    expense: expense,
    largestExpense: largest,
    dailyAverage: dailyAvg,
    savingsRate: savingsRate,
    expenses: expensesPie,
    incomes: incomesPie,
    categories: categories,
    monthly: [
      for (final m in monthly) (label: m.month, income: m.income, expense: m.expense),
    ],
    recent: recent,
    accounts: accounts,
  );
});

/// Comparativo do mês atual com o anterior (para os insights do dashboard).
final monthCompareProvider = FutureProvider<({int income, int expense, int prevIncome, int prevExpense})>(
  (ref) async {
    final db = ref.watch(databaseProvider);
    final now = DateTime.now();
    final thisStart = DateTime(now.year, now.month, 1);
    final thisEnd = DateTime(now.year, now.month + 1, 0);
    final prevStart = DateTime(now.year, now.month - 1, 1);
    final prevEnd = DateTime(now.year, now.month, 0);

    final income = await db.sumByType(kIncome, from: thisStart, to: thisEnd);
    final expense = await db.sumByType(kExpense, from: thisStart, to: thisEnd);
    final prevIncome = await db.sumByType(kIncome, from: prevStart, to: prevEnd);
    final prevExpense = await db.sumByType(kExpense, from: prevStart, to: prevEnd);

    return (income: income, expense: expense, prevIncome: prevIncome, prevExpense: prevExpense);
  },
);

/// Série temporal para o gráfico de tendência (semana/mês/ano/anos).
final timeSeriesProvider = FutureProvider.autoDispose
    .family<List<({String label, int income, int expense})>, String>((ref, kind) {
  return ref.watch(databaseProvider).timeSeries(kind);
});

/// Série de poupança (receitas - gastos) mês a mês, para o gráfico de tendência.
final savingsSeriesProvider = FutureProvider<List<({String label, int savings})>>((ref) async {
  final monthly = await ref.watch(databaseProvider).monthlySummary(12);
  return [
    for (final m in monthly) (label: m.month, savings: m.income - m.expense),
  ];
});

/// Transações filtradas para a tela de transações.
final transactionsForFiltersProvider = StreamProvider.autoDispose
    .family<List<Tx>, ({String? type, String? search, DateTime? from, DateTime? to})>(
        (ref, filters) {
  final stream = ref
      .watch(databaseProvider)
      .watchTransactions(from: filters.from, to: filters.to, type: filters.type);
  final search = filters.search?.trim().toLowerCase();
  if (search == null || search.isEmpty) return stream;
  return stream.map((list) => list
      .where((t) =>
          t.description.toLowerCase().contains(search) || t.notes.toLowerCase().contains(search))
      .toList());
});

/// Transações apagadas (lixeira).
final trashProvider = StreamProvider<List<Tx>>((ref) {
  return ref.watch(databaseProvider).watchDeletedTransactions();
});

/// Recorrentes com vencimento nos próximos 30 dias.
final upcomingRecurringProvider = FutureProvider<List<RecurringRule>>((ref) {
  return ref.watch(databaseProvider).upcomingRecurring(days: 30);
});

/// Projeção de saldo até o fim do mês (saldo atual + próximos lançamentos recorrentes).
final projectionProvider = FutureProvider<({int balance, int delta})>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final balance = await db.totalBalance();
  final delta = await db.projectedDeltaUntil(until: DateTime(now.year, now.month + 1, 0));
  return (balance: balance, delta: delta);
});

/// Orçamentos de um mês (chave "YYYY-MM").
final budgetsForMonthProvider =
    StreamProvider.autoDispose.family<List<Budget>, String>((ref, month) {
  return ref.watch(databaseProvider).watchBudgets(month);
});

/// Gastos por categoria num intervalo (para acompanhar orçamentos).
final spentByCategoryProvider = FutureProvider.autoDispose
    .family<Map<String, int>, (DateTime, DateTime)>((ref, range) {
  final (from, to) = range;
  return ref.watch(databaseProvider).spentByCategory(from: from, to: to);
});

/// Descrições recentes para sugestão no editor de transações.
final recentDescriptionsProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, type) {
  return ref.watch(databaseProvider).recentDescriptions(type);
});

/// Lê uma chave de configuração (tema, PIN, sync...).
final settingsProvider = StreamProvider.autoDispose.family<String?, String>((ref, key) {
  return ref.watch(databaseProvider).watchSetting(key);
});

/// Tema atual escolhido pelo usuário.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(settingsProvider('theme_mode')).value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});