import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/common.dart';

class TransactionEditorScreen extends ConsumerStatefulWidget {
  final String? txId;

  /// Tipo já selecionado ao criar: 'receita', 'despesa' (padrão) ou 'transferencia'.
  final String? initialType;

  const TransactionEditorScreen({super.key, this.txId, this.initialType});

  @override
  ConsumerState<TransactionEditorScreen> createState() => _TransactionEditorScreenState();
}

class _TransactionEditorScreenState extends ConsumerState<TransactionEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  late String _typeKey;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _loadedFromDb = false;

  @override
  void initState() {
    super.initState();
    _typeKey = switch (widget.initialType) {
      'receita' => kIncome,
      'transferencia' => kTransfer,
      _ => kExpense,
    };
    _loadIfEditing();
  }

  Future<void> _loadIfEditing() async {
    if (widget.txId == null) return;
    final db = ref.read(databaseProvider);
    final tx = await (db.watchTransactions(limit: 2000).first
        .then((list) => list.where((t) => t.id == widget.txId).firstOrNull));
    if (tx == null || !mounted) return;

    _amountController.text = '';
    MoneyField.format((tx.amount).toString(), _amountController);
    _descriptionController.text = tx.description;
    _notesController.text = tx.notes;
    _accountId = tx.accountId;
    _toAccountId = tx.toAccountId;
    _categoryId = tx.categoryId;
    _date = tx.date;
    _setType(tx.type);
    setState(() => _loadedFromDb = true);
  }

  void _setType(String type) {
    _typeKey = type;
    if (type != kTransfer) _toAccountId = null;
    if (type == kTransfer) _categoryId = null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    if (!_formKey.currentState!.validate()) return;

    final amount = MoneyField.centsOf(_amountController);
    if (amount <= 0) {
      showAppSnack(context, 'Informe um valor maior que zero.', error: true);
      return;
    }
    final accountId = _accountId;
    if (accountId == null || accountId.isEmpty) {
      showAppSnack(context, 'Escolha uma conta.', error: true);
      return;
    }
    if (_typeKey == kTransfer && (_toAccountId == null || _toAccountId == accountId)) {
      showAppSnack(context, 'Escolha uma conta de destino diferente.', error: true);
      return;
    }
    if (_typeKey != kTransfer && _categoryId == null) {
      showAppSnack(context, 'Escolha uma categoria.', error: true);
      return;
    }

    final id = _loadedFromDb && widget.txId != null ? widget.txId! : newId();
    await db.upsertTransaction(
      TransactionsCompanion.insert(
        id: id,
        accountId: accountId,
        toAccountId: Value(_toAccountId),
        categoryId: Value(_typeKey == kTransfer ? null : _categoryId),
        type: _typeKey,
        amount: amount,
        description: Value(_descriptionController.text.trim()),
        notes: Value(_notesController.text.trim()),
        date: _date,
        createdAt: Value(DateTime.now()),
      ),
      id: id,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnack(context, _loadedFromDb ? 'Transação atualizada' : 'Transação adicionada');
  }

  Future<void> _delete() async {
    if (widget.txId == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Excluir transação?',
      message: 'Essa ação não pode ser desfeita.',
    );
    if (!ok || widget.txId == null) return;
    await ref.read(databaseProvider).softDelete('transactions', widget.txId!);
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnack(context, 'Transação excluída');
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    if (widget.txId != null && !_loadedFromDb) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Pilota a conta padrão (padrão do mês).
    if (_accountId == null && accounts.isNotEmpty) {
      final def = accounts.where((a) => a.isDefault).firstOrNull ?? accounts.first;
      _accountId = def.id;
    }

    final allowedCategories = categories.where((c) => c.type == _typeKey).toList();
    if (_categoryId != null &&
        _typeKey != kTransfer &&
        !allowedCategories.any((c) => c.id == _categoryId)) {
      _categoryId = allowedCategories.firstOrNull?.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_loadedFromDb ? 'Editar transação' : 'Nova transação'),
        actions: [
          if (_loadedFromDb)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              color: Theme.of(context).colorScheme.error,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            AppRoleSelector(type: _typeKey, onChanged: (t) => setState(() => _setType(t))),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _AmountSummary(type: _typeKey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MoneyField(
              label: 'Valor',
              controller: _amountController,
              margin: const EdgeInsets.only(bottom: 14),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex.: Supermercado, salário...',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Conta', prefixIcon: Icon(Icons.account_balance_wallet_rounded)),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: Row(
                      children: [
                        Icon(AccountIcons.byType(a.type), size: 18),
                        const SizedBox(width: 8),
                        Text(a.name),
                        if (a.isDefault) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                        ],
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            if (_typeKey == kTransfer) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _toAccountId,
                decoration: const InputDecoration(labelText: 'Conta de destino', prefixIcon: Icon(Icons.arrow_forward_rounded)),
                items: [
                  for (final a in accounts.where((a) => a.id != _accountId))
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _toAccountId = v),
              ),
            ] else ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: InputDecoration(
                  labelText: _typeKey == kIncome ? 'Categoria (receita)' : 'Categoria',
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
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
            ],
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Data', prefixIcon: Icon(Icons.calendar_today_rounded)),
                child: Text(Formats.fullDate(_date), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Observações (opcional)', prefixIcon: Icon(Icons.notes_rounded)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(_loadedFromDb ? 'Salvar alterações' : 'Adicionar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  final String type;

  const _AmountSummary({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type == kIncome
        ? AppColors.income
        : type == kTransfer
            ? AppColors.transfer
            : AppColors.expense;
    final label = type == kIncome
        ? 'Registrando receita'
        : type == kTransfer
            ? 'Registrando transferência'
            : 'Registrando despesa';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(
            type == kIncome
                ? Icons.arrow_upward_rounded
                : type == kTransfer
                    ? Icons.swap_horiz_rounded
                    : Icons.arrow_downward_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }
}