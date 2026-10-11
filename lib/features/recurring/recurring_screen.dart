import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/common.dart';

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  Future<void> _createDue() async {
    final db = ref.read(databaseProvider);
    final accountId = (await db.defaultAccount())?.id;
    if (accountId == null) {
      showAppSnack(context, 'Crie uma conta primeiro.', error: true);
      return;
    }
    final due = await db.dueRecurring();
    final created = <String>[];
    for (final rule in due) {
      final categoryId = await _pickCategory(rule.type);
      if (categoryId == null) continue;
      final id = newId();
      await db.upsertTransaction(
        TransactionsCompanion.insert(
          id: id,
          accountId: rule.accountId,
          toAccountId: const Value(null),
          categoryId: Value(categoryId),
          type: rule.type,
          amount: rule.amount,
          description: Value(rule.description),
          notes: const Value(''),
          date: rule.nextDueDate,
          recurringId: Value(rule.id),
          createdAt: Value(DateTime.now()),
        ),
        id: id,
      );
      await db.advanceRecurring(rule.id);
      created.add(rule.description);
    }
    if (!mounted) return;
    showAppSnack(
      context,
      created.isEmpty ? 'Nenhuma transação vencida para gerar.' : 'Criadas: ${created.join(', ')}',
    );
  }

  Future<String?> _pickCategory(String type) async {
    final categories = await ref.read(databaseProvider).getCategories();
    final list = categories.where((c) => c.type == type).toList();
    if (list.length == 1) return list.first.id;
    if (list.isEmpty) return null;
    if (!mounted) return null;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Escolha a categoria'),
        children: [
          for (final c in list)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c.id),
              child: Row(
                children: [
                  CategoryAvatar(icon: c.icon, color: c.color, size: 28),
                  const SizedBox(width: 10),
                  Text(c.name),
                ],
              ),
            ),
        ],
      ),
    );
    return picked;
  }

  @override
  Widget build(BuildContext context) {
    final recurring = ref.watch(recurringProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorrentes'),
        actions: [
          IconButton(
            onPressed: _createDue,
            tooltip: 'Gerar vencidos agora',
            icon: const Icon(Icons.bolt_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(ref, accounts, categories, null),
        child: const Icon(Icons.add_rounded),
      ),
      body: recurring.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) {
          final due = list.where((r) => r.nextDueDate.isBefore(DateTime.now()) && !r.paused).length;
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.event_repeat_rounded,
              title: 'Sem lançamentos recorrentes',
              subtitle: 'Crie aluguéis, assinaturas ou salários que se repetem todo mês.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            itemCount: list.length + (due > 0 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (due > 0 && i == 0) {
                return AppCard(
                  color: AppColors.warning.withValues(alpha: .1),
                  onTap: _createDue,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.notification_important_rounded, color: AppColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$due lançamento(s) vencido(s). Toque para gerar agora.',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final item = i - (due > 0 ? 1 : 0);
              final rule = list[item];
              final account = accounts.where((a) => a.id == rule.accountId).firstOrNull;
              final category = categories.where((c) => c.id == rule.categoryId).firstOrNull;
              final type = rule.type;
              final color = type == kIncome ? AppColors.income : (type == kTransfer ? AppColors.transfer : AppColors.expense);
              final isDue = !rule.paused && rule.nextDueDate.isBefore(DateTime.now());

              return AppCard(
                onTap: () => _showEditor(ref, accounts, categories, rule),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CategoryAvatar(icon: category?.icon ?? 'event_repeat', color: category?.color ?? 0xFF64748B),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          rule.description.isNotEmpty ? rule.description : _frequencyLabel(rule.frequency),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                      ),
                      Text(
                        '${type == kIncome ? '+' : '-'} ${Formats.money(rule.amount)}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: color),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(AccountIcons.byType(account?.type ?? 'checking'), size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(account?.name ?? 'Sem conta', style: const TextStyle(fontSize: 11.5)),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Text(
                          _frequencyLabel(rule.frequency),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        if (rule.paused) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Pausada', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Icon(
                    isDue ? Icons.bolt_rounded : Icons.chevron_right_rounded,
                    color: isDue ? AppColors.warning : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditor(
    WidgetRef ref,
    List<Account> accounts,
    List<Category> categories,
    RecurringRule? rule,
  ) async {
    await showAppSheet(
      context,
      _RecurringEditorSheet(rule: rule),
    );
  }

  String _frequencyLabel(String frequency) => switch (frequency) {
        'daily' => 'Diário',
        'weekly' => 'Semanal',
        'monthly' => 'Mensal',
        'yearly' => 'Anual',
        _ => frequency,
      };
}

class _RecurringEditorSheet extends ConsumerStatefulWidget {
  final RecurringRule? rule;

  const _RecurringEditorSheet({this.rule});

  @override
  ConsumerState<_RecurringEditorSheet> createState() => _RecurringEditorSheetState();
}

class _RecurringEditorSheetState extends ConsumerState<_RecurringEditorSheet> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  late String _type;
  late String _frequency;
  late String? _accountId;
  late String? _categoryId;
  late DateTime _start;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _description.text = r?.description ?? '';
    if (r != null) MoneyField.format('${r.amount}', _amount);
    _type = r?.type ?? kExpense;
    _frequency = r?.frequency ?? 'monthly';
    _accountId = r?.accountId;
    _categoryId = r?.categoryId;
    _start = r?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final amount = MoneyField.centsOf(_amount);
    final accountId = _accountId;
    if (accountId == null || accountId.isEmpty) {
      showAppSnack(context, 'Escolha a conta.', error: true);
      return;
    }
    if (amount <= 0) {
      showAppSnack(context, 'Informe um valor maior que zero.', error: true);
      return;
    }
    if (_type != kTransfer && _categoryId == null) {
      showAppSnack(context, 'Escolha a categoria.', error: true);
      return;
    }
    final id = widget.rule?.id ?? newId();
    final nextDue = widget.rule?.nextDueDate ??
        db.nextDueDate(frequency: _frequency, interval: 1, from: _start);
    await db.upsertRecurring(
      RecurringRulesCompanion.insert(
        id: id,
        accountId: accountId,
        categoryId: Value(_type == kTransfer ? null : _categoryId),
        type: _type,
        amount: amount,
        description: Value(_description.text.trim()),
        frequency: Value(_frequency),
        interval: const Value(1),
        startDate: _start,
        endDate: Value(widget.rule?.endDate),
        nextDueDate: nextDue,
        autoCreate: const Value(true),
        paused: Value(widget.rule?.paused ?? false),
        createdAt: Value(DateTime.now()),
      ),
      id: id,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnack(context, widget.rule == null ? 'Recorrência criada' : 'Recorrência atualizada');
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final isEdit = widget.rule != null;

    if (_accountId == null && accounts.isNotEmpty) {
      final def = accounts.where((a) => a.isDefault).firstOrNull ?? accounts.first;
      _accountId = def.id;
    }
    final allowedCategories = categories.where((c) => c.type == _type).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Editar recorrência' : 'Nova recorrência', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            AppRoleSelector(type: _type, onChanged: (t) => setState(() => _type = t)),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Ex.: Aluguel, Academia, Salário...'),
            ),
            const SizedBox(height: 14),
            MoneyField(label: 'Valor', controller: _amount),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Conta'),
              items: [
                for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 14),
            if (_type != kTransfer) ...[
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  for (final c in allowedCategories)
                    DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          CategoryAvatar(icon: c.icon, color: c.color, size: 24),
                          const SizedBox(width: 10),
                          Text(c.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 14),
            ],
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Repetição'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Todo dia')),
                DropdownMenuItem(value: 'weekly', child: Text('Toda semana')),
                DropdownMenuItem(value: 'monthly', child: Text('Todo mês')),
                DropdownMenuItem(value: 'yearly', child: Text('Todo ano')),
              ],
              onChanged: (v) => setState(() => _frequency = v ?? 'monthly'),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: Text(isEdit ? 'Salvar' : 'Criar recorrência')),
            if (isEdit) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.rule!.paused
                          ? () async {
                              final db = ref.read(databaseProvider);
                              await (db.update(db.recurringRules)..where((t) => t.id.equals(widget.rule!.id)))
                                  .write(RecurringRulesCompanion(paused: const Value(false)));
                              if (mounted) Navigator.of(context).pop();
                            }
                          : () async {
                              final db = ref.read(databaseProvider);
                              await (db.update(db.recurringRules)..where((t) => t.id.equals(widget.rule!.id)))
                                  .write(RecurringRulesCompanion(paused: const Value(true)));
                              if (mounted) Navigator.of(context).pop();
                            },
                      child: Text(widget.rule!.paused ? 'Reativar' : 'Pausar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Excluir recorrência?',
                          message: 'As próximas cobranças serão canceladas.',
                        );
                        if (!ok || !mounted) return;
                        await ref.read(databaseProvider).softDelete('recurring_rules', widget.rule!.id);
                        if (mounted) {
                          Navigator.of(context).pop();
                          showAppSnack(context, 'Recorrência excluída');
                        }
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      child: const Text('Excluir'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}