import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_theme.dart';
import 'database.dart' hide User;
import 'providers.dart';

final supabaseServiceProvider = Provider<SupabaseService>(
    (ref) => SupabaseService(ref.watch(databaseProvider)));

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine(
      db: ref.watch(databaseProvider),
      service: ref.watch(supabaseServiceProvider),
    ));

/// Tabelas sincronizáveis na ordem em que devem ser aplicadas (FKey primeiro).
const List<String> syncTables = [
  'accounts',
  'categories',
  'transactions',
  'recurring_rules',
  'budgets',
  'goals',
  'goal_contributions',
];

class SupabaseService {
  final AppDatabase db;

  static bool _initialized = false;

  SupabaseService(this.db) {
    if (AppConfig.hasSupabase && !_initialized) {
      try {
        Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );
        _initialized = true;
      } catch (_) {}
    }
  }

  SupabaseClient? get _client => AppConfig.hasSupabase ? Supabase.instance.client : null;

  User? get currentUser => _client?.auth.currentUser;

  Future<void> init() async {
    if (!AppConfig.hasSupabase) return;
    try {
      await _client?.auth.getSession();
    } catch (_) {}
  }

  Future<void> signUp({required String email, required String password}) async {
    final c = _client;
    if (c == null) throw StateError('Sincronização não configurada');
    try {
      await c.auth.signUp(email: email, password: password);
      if (c.auth.currentUser == null) {
        throw StateError(
          'Conta criada, mas confirme seu e-mail antes de entrar. '
          'Se preferir, cadastre-se com uma senha e prossiga.',
        );
      }
    } on AuthException catch (e) {
      throw StateError(_friendlyAuthError(e));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final c = _client;
    if (c == null) throw StateError('Sincronização não configurada');
    try {
      await c.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw StateError(_friendlyAuthError(e));
    }
  }

  Future<void> signOut() => _client?.auth.signOut() ?? Future.value();

  Future<void> requestPasswordReset(String email) async {
    final c = _client;
    if (c == null) throw StateError('Sincronização não configurada');
    await c.auth.resetPasswordForEmail(email);
  }

  String _friendlyAuthError(AuthException e) {
    final message = e.message.toLowerCase();
    if (kDebugMode) return e.message;
    if (message.contains('invalid login credentials') ||
        message.contains('invalid email or password')) {
      return 'E-mail ou senha inválidos.';
    }
    if (message.contains('already registered') || message.contains('already been registered')) {
      return 'Este e-mail já está cadastrado. Faça login.';
    }
    if (message.contains('email not confirmed')) return 'Confirme seu e-mail antes de entrar.';
    if (message.contains('password')) return 'A senha deve ter pelo menos 6 caracteres.';
    return 'Não foi possível concluir. Tente novamente.';
  }

  /// Sobe apenas as linhas locais modificadas desde a última sincronização.
  Future<void> pushSince(DateTime since) async {
    final client = _client;
    if (client == null) return;
    final user = client.auth.currentUser;
    if (user == null) return;

    for (final table in syncTables) {
      final rows = await db.rowsForSync(table, since: since);
      if (rows.isEmpty) continue;
      final payload = rows.values.map((row) => {
            'id': row['id'],
            'user_id': user.id,
            for (final entry in row.entries)
              if (entry.key != 'id') entry.key: entry.value,
          }).toList();
      await client.from(table).upsert(payload, onConflict: 'id');
    }
  }

  /// Baixa as linhas remotas alteradas e aplica localmente (last-write-wins).
  Future<void> pullSince(DateTime since) async {
    final client = _client;
    if (client == null) return;

    for (final table in syncTables) {
      final response = await client
          .from(table)
          .select('*')
          .or('updated_at.gt.${since.toUtc().toIso8601String()}');
      final rows = _normalizeList(response);
      for (final row in rows) {
        await _applyRemote(table, row);
      }
    }
  }

  List<Map<String, dynamic>> _normalizeList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<Map<String, dynamic>>();
    if (value is Map) return [value.cast<String, dynamic>()];
    return [];
  }

  Future<void> _applyRemote(String table, Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final deletedAt = _maybeDate(row['deleted_at']);
    if (deletedAt != null) {
      await db.softDeleteFromRemote(table, id, deletedAt);
      return;
    }

    switch (table) {
      case 'accounts':
        await db.upsertAccountFromRemote(AccountsCompanion(
          id: Value(id),
          name: Value(row['name'] as String? ?? 'Conta'),
          type: Value(row['type'] as String? ?? 'checking'),
          icon: Value(row['icon'] as String? ?? 'wallet'),
          color: Value(row['color'] as int? ?? AppColors.seed.toARGB32()),
          initialBalance: Value(row['initial_balance'] as int? ?? 0),
          includeInTotal: Value(row['include_in_total'] as bool? ?? true),
          isDefault: Value(row['is_default'] as bool? ?? false),
          archived: Value(row['archived'] as bool? ?? false),
          createdAt: Value(_dateOrNow(row['created_at'])),
          updatedAt: Value(_dateOrNow(row['updated_at'])),
          deletedAt: Value(_maybeDate(row['deleted_at'])),
        ));
      case 'categories':
        await db.upsertCategoryFromRemote(CategoriesCompanion(
          id: Value(id),
          name: Value(row['name'] as String? ?? 'Categoria'),
          type: Value(row['type'] as String? ?? kExpense),
          icon: Value(row['icon'] as String? ?? 'other'),
          color: Value(row['color'] as int? ?? 0xFF64748B),
          isDefault: Value(row['is_default'] as bool? ?? false),
          status: Value(row['status'] as String? ?? 'active'),
          createdAt: Value(_dateOrNow(row['created_at'])),
          updatedAt: Value(_dateOrNow(row['updated_at'])),
          deletedAt: Value(_maybeDate(row['deleted_at'])),
        ));
      case 'transactions':
        await db.upsertTransactionFromRemote(TransactionsCompanion(
          id: Value(id),
          accountId: Value(row['account_id'] as String? ?? ''),
          toAccountId: Value(row['to_account_id'] as String?),
          categoryId: Value(row['category_id'] as String?),
          subcategoryId: Value(row['subcategory_id'] as String?),
          type: Value(row['type'] as String? ?? kExpense),
          amount: Value(row['amount'] as int? ?? 0),
          description: Value(row['description'] as String? ?? ''),
          notes: Value(row['notes'] as String? ?? ''),
          date: Value(_dateOrNow(row['date'])),
          recurringId: Value(row['recurring_id'] as String?),
          status: Value(row['status'] as String? ?? 'posted'),
          createdAt: Value(_dateOrNow(row['created_at'])),
          updatedAt: Value(_dateOrNow(row['updated_at'])),
          deletedAt: Value(_maybeDate(row['deleted_at'])),
        ));
      case 'recurring_rules':
        await db.upsertRecurringFromRemote(RecurringRulesCompanion(
          id: Value(id),
          accountId: Value(row['account_id'] as String? ?? ''),
          categoryId: Value(row['category_id'] as String?),
          type: Value(row['type'] as String? ?? kExpense),
          amount: Value(row['amount'] as int? ?? 0),
          description: Value(row['description'] as String? ?? ''),
          frequency: Value(row['frequency'] as String? ?? 'monthly'),
          interval: Value(row['interval'] as int? ?? 1),
          startDate: Value(_dateOrNow(row['start_date'])),
          endDate: Value(_maybeDate(row['end_date'])),
          nextDueDate: Value(_dateOrNow(row['next_due_date'])),
          autoCreate: Value(row['auto_create'] as bool? ?? true),
          paused: Value(row['paused'] as bool? ?? false),
          createdAt: Value(_dateOrNow(row['created_at'])),
          updatedAt: Value(_dateOrNow(row['updated_at'])),
          deletedAt: Value(_maybeDate(row['deleted_at'])),
        ));
      case 'budgets':
        await db.upsertBudgetFromRemote(BudgetsCompanion(
          id: Value(id),
          categoryId: Value(row['category_id'] as String? ?? ''),
          month: Value(row['month'] as String? ?? ''),
          limitAmount: Value(row['limit_amount'] as int? ?? 0),
          createdAt: Value(_dateOrNow(row['created_at'])),
          updatedAt: Value(_dateOrNow(row['updated_at'])),
          deletedAt: Value(_maybeDate(row['deleted_at'])),
        ));
      case 'goals':
        await db.upsertGoalFromRemote(GoalsCompanion(
          id: Value(id),
          name: Value(row['name'] as String? ?? 'Meta'),
          targetAmount: Value(row['target_amount'] as int? ?? 0),
          savedAmount: Value(row['saved_amount'] as int? ?? 0),
          deadline: Value(_maybeDate(row['deadline'])),
          color: Value(row['color'] as int? ?? 0xFF2563EB),
          completed: Value(row['completed'] as bool? ?? false),
          createdAt: Value(_dateOrNow(row['created_at'])),
          updatedAt: Value(_dateOrNow(row['updated_at'])),
          deletedAt: Value(_maybeDate(row['deleted_at'])),
        ));
      case 'goal_contributions':
        await db.upsertContributionFromRemote(GoalContributionsCompanion(
          id: Value(id),
          goalId: Value(row['goal_id'] as String? ?? ''),
          amount: Value(row['amount'] as int? ?? 0),
          note: Value(row['note'] as String? ?? ''),
          date: Value(_dateOrNow(row['date'])),
          updatedAt: Value(_dateOrNow(row['updated_at'])),
          deletedAt: Value(_maybeDate(row['deleted_at'])),
        ));
    }
  }

  DateTime? _maybeDate(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    return parsed.toLocal();
  }

  DateTime _dateOrNow(dynamic value) =>
      _maybeDate(value) ?? DateTime.now();
}

class SyncEngine {
  final AppDatabase db;
  final SupabaseService service;

  SyncEngine({required this.db, required this.service});

  bool get isConfigured => AppConfig.hasSupabase;
  bool get isLoggedIn => service.currentUser != null;

  Future<DateTime?> lastSyncAt() async {
    final raw = await db.getSetting('last_sync_at');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> run() async {
    if (!isConfigured) throw StateError('Sincronização não configurada.');
    if (!isLoggedIn) throw StateError('Entre com sua conta para sincronizar.');

    final before = await lastSyncAt();
    final since = before ?? DateTime.fromMillisecondsSinceEpoch(0);

    // Empurra o que mudou localmente e puxa o que mudou na nuvem.
    await service.pushSince(since);
    await service.pullSince(since);
    await service.pushSince(since);

    await db.setSetting('last_sync_at', DateTime.now().toUtc().toIso8601String());
  }

  Future<void> resetLocalSyncMarker() => db.setSetting('last_sync_at', '');
}

/// Carrega a sessão do Supabase uma única vez.
Future<void> initializeSync(AppDatabase db) async {
  final service = SupabaseService(db);
  await service.init();
}