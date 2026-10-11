import 'package:drift/drift.dart';
import 'package:finamind/data/database.dart';

/// Helpers de carga usados pelos testes de banco: devolvem os ids criados.
/// Valores monetários são sempre centavos (int), como no app.

Future<String> seedAccount(
  AppDatabase db, {
  String id = 'acc1',
  String name = 'Carteira',
  String type = 'checking',
  int initialBalance = 0,
  bool includeInTotal = true,
  bool archived = false,
  bool isDefault = false,
}) async {
  await db.upsertAccount(
    AccountsCompanion.insert(
      id: id,
      name: name,
      type: Value(type),
      initialBalance: Value(initialBalance),
      includeInTotal: Value(includeInTotal),
      isDefault: Value(isDefault),
      archived: Value(archived),
    ),
    id: id,
  );
  return id;
}

Future<String> seedCategory(
  AppDatabase db,
  String name, {
  String type = kExpense,
  String? id,
}) async {
  final categoryId = id ?? newId();
  await db.upsertCategory(
    CategoriesCompanion.insert(id: categoryId, name: name, type: type),
    id: categoryId,
  );
  return categoryId;
}

Future<String> seedTx(
  AppDatabase db, {
  required String accountId,
  required String type,
  required int amount,
  String? id,
  String? categoryId,
  String? toAccountId,
  String description = '',
  String notes = '',
  DateTime? date,
}) async {
  final txId = id ?? newId();
  await db.upsertTransaction(
    TransactionsCompanion.insert(
      id: txId,
      accountId: accountId,
      type: type,
      amount: amount,
      date: date ?? DateTime.now(),
      categoryId: Value(categoryId),
      toAccountId: Value(toAccountId),
      description: Value(description),
      notes: Value(notes),
    ),
    id: txId,
  );
  return txId;
}

Future<String> seedGoal(
  AppDatabase db, {
  required String name,
  required int target,
  String? id,
}) async {
  final goalId = id ?? newId();
  await db.upsertGoal(
    GoalsCompanion.insert(id: goalId, name: name, targetAmount: target),
    id: goalId,
  );
  return goalId;
}

Future<String> seedRecurring(
  AppDatabase db, {
  required String accountId,
  required String type,
  required int amount,
  required DateTime nextDue,
  String? id,
  String frequency = 'monthly',
  int interval = 1,
  DateTime? endDate,
  bool autoCreate = true,
  bool paused = false,
}) async {
  final ruleId = id ?? newId();
  await db.upsertRecurring(
    RecurringRulesCompanion.insert(
      id: ruleId,
      accountId: accountId,
      type: type,
      amount: amount,
      startDate: nextDue,
      nextDueDate: nextDue,
      frequency: Value(frequency),
      interval: Value(interval),
      endDate: Value(endDate),
      autoCreate: Value(autoCreate),
      paused: Value(paused),
    ),
    id: ruleId,
  );
  return ruleId;
}
