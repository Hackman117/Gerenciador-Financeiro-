import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/common.dart';

String accountTypeLabel(String type) => switch (type) {
      'checking' => 'Conta corrente',
      'savings' => 'Poupança',
      'cash' => 'Dinheiro',
      'credit' => 'Cartão de crédito',
      'investment' => 'Investimento',
      'digital' => 'Conta digital',
      _ => 'Carteira',
    };

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final archived = ref.watch(archivedAccountsProvider);

    final active = accounts.value ?? const <Account>[];
    final archivedList = archived.value ?? const <Account>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Contas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context, ref, account: null),
        child: const Icon(Icons.add_rounded),
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            if (active.isEmpty && archivedList.isEmpty)
              const EmptyState(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Nenhuma conta',
                subtitle: 'Crie sua primeira conta: dinheiro, banco ou carteira.',
              ),
            for (var i = 0; i < active.length; i++)
              Padding(
                key: ValueKey('account_card_${active[i].id}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: _AccountBalanceCard(
                  account: active[i],
                  index: i,
                  onTap: () => _openDetail(context, active[i]),
                  onSetDefault: () =>
                      ref.read(databaseProvider).setDefaultAccount(active[i].id),
                ),
              ),
            if (archivedList.isNotEmpty) ...[
              const SectionHeader(title: 'Desativadas'),
              for (final account in archivedList)
                Padding(
                  key: ValueKey('account_archived_${account.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ArchivedTile(
                    account: account,
                    onTap: () => _openDetail(context, account),
                    onReactivate: () async {
                      await ref
                          .read(databaseProvider)
                          .setAccountArchived(account.id, archived: false);
                      if (context.mounted) showAppSnack(context, 'Conta reativada');
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, Account account) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountDetailScreen(account: account),
      ),
    );
  }

  Future<void> _showEditor(BuildContext context, WidgetRef ref, {Account? account}) async {
    await showAppSheet<String>(
      context,
      _AccountEditorSheet(account: account),
    );
  }
}

class AccountDetailScreen extends ConsumerWidget {
  final Account account;

  const AccountDetailScreen({super.key, required this.account});

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showAppSheet<String>(
      context,
      _AccountEditorSheet(account: account),
    );
    if (!context.mounted) return;
    if (result == 'deleted' || result == 'archived' || result == 'unarchived') {
      Navigator.of(context).pop();
    }
  }

  Future<void> _toggleArchived(BuildContext context, WidgetRef ref) async {
    final a = account;
    if (!a.archived && a.isDefault) {
      showAppSnack(context, 'Defina outra conta como padrão antes de desativar.', error: true);
      return;
    }
    await ref.read(databaseProvider).setAccountArchived(a.id, archived: !a.archived);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    showAppSnack(context, a.archived ? 'Conta reativada' : 'Conta desativada');
  }

  Future<void> _setDefault(BuildContext context, WidgetRef ref) async {
    await ref.read(databaseProvider).setDefaultAccount(account.id);
    if (context.mounted) showAppSnack(context, 'Conta definida como padrão das transações');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Excluir conta?',
      message: 'As transações dessa conta serão arquivadas. Você pode recuperá-las depois.',
      confirmLabel: 'Excluir',
    );
    if (!ok) return;
    final db = ref.read(databaseProvider);
    await db.softDelete('accounts', account.id);
    if (account.isDefault) {
      final others = await db.getAccounts();
      if (others.isNotEmpty) await db.setDefaultAccount(others.first.id);
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    showAppSnack(context, 'Conta excluída');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final current = ref.watch(accountByIdProvider(account.id)).value ?? account;
    final balance = ref.watch(accountBalanceProvider(account.id)).value ?? current.initialBalance;
    final color = Color(current.color);

    return Scaffold(
      key: const ValueKey('account_detail'),
      appBar: AppBar(
        title: const Text('Conta'),
        actions: [
          IconButton(
            key: const ValueKey('account_detail_edit'),
            tooltip: 'Editar',
            onPressed: () => _edit(context, ref),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: const ValueKey('account_detail_delete'),
            tooltip: 'Excluir',
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
            color: scheme.error,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(AccountIcons.byType(current.type), size: 26, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(current.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(accountTypeLabel(current.type),
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    if (current.archived)
                      _Chip(label: 'Desativada', color: scheme.onSurfaceVariant)
                    else
                      _Chip(label: 'Ativa', color: AppColors.income),
                    if (current.isDefault)
                      const _Chip(label: 'Padrão', color: AppColors.warning),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo atual',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(Formats.money(balance),
                    key: const ValueKey('account_detail_balance'),
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const Divider(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(label: 'Saldo inicial', value: Formats.money(current.initialBalance)),
                    ),
                    Expanded(
                      child: _Stat(label: 'Variação', value: Formats.money(balance - current.initialBalance)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_tree_outlined),
                  title: const Text('Tipo'),
                  trailing: Text(accountTypeLabel(current.type)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Criada em'),
                  trailing: Text(Formats.fullDate(current.createdAt)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            key: const ValueKey('account_detail_edit_button'),
            onPressed: () => _edit(context, ref),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar conta'),
          ),
          if (!current.archived && !current.isDefault) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _setDefault(context, ref),
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text('Definir como padrão'),
            ),
          ],
          if (!current.archived) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('account_detail_deactivate'),
              onPressed: () => _toggleArchived(context, ref),
              icon: const Icon(Icons.pause_circle_outline_rounded),
              label: const Text('Desativar conta'),
            ),
          ] else ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('account_detail_reactivate'),
              onPressed: () => _toggleArchived(context, ref),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Reativar conta'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _AccountBalanceCard extends ConsumerWidget {
  final Account account;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;

  const _AccountBalanceCard({
    required this.account,
    required this.index,
    required this.onTap,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(AppColors.accountColors[index % AppColors.accountColors.length]);
    final balance = ref.watch(accountBalanceProvider(account.id)).value ?? 0;
    final isDefault = account.isDefault;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(AccountIcons.byType(account.type), size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(account.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                      const Text('Padrão',
                          style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
                Text(
                  accountTypeLabel(account.type),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formats.money(balance),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (!isDefault)
                InkWell(
                  onTap: onSetDefault,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('Definir como padrão',
                        style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                  ),
                )
              else
                const SizedBox(height: 2),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArchivedTile extends ConsumerWidget {
  final Account account;
  final VoidCallback onTap;
  final VoidCallback onReactivate;

  const _ArchivedTile({
    required this.account,
    required this.onTap,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final balance = ref.watch(accountBalanceProvider(account.id)).value ?? 0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 22, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                Text(
                  'Desativada • ${Formats.money(balance)}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onReactivate,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Reativar'),
          ),
        ],
      ),
    );
  }
}

class _AccountEditorSheet extends ConsumerStatefulWidget {
  final Account? account;

  const _AccountEditorSheet({this.account});

  @override
  ConsumerState<_AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends ConsumerState<_AccountEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _initial;
  late String _type;
  late int _color;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _initial = TextEditingController();
    _type = a?.type ?? 'checking';
    _color = a?.color ?? AppColors.accountColors.first;
    if (a != null) {
      MoneyField.format('${a.initialBalance}', _initial);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnack(context, 'Dê um nome para a conta.', error: true);
      return;
    }
    final isDefault = widget.account?.isDefault ?? false;
    final isArchived = widget.account?.archived ?? false;
    final id = widget.account?.id ?? newId();
    await db.upsertAccount(
      AccountsCompanion.insert(
        id: id,
        name: name,
        type: Value(_type),
        icon: Value(_typeIcon()),
        color: Value(_color),
        initialBalance: Value(MoneyField.centsOf(_initial)),
        includeInTotal: const Value(true),
        isDefault: Value(isDefault),
        archived: Value(isArchived),
        createdAt: Value(DateTime.now()),
      ),
      id: id,
    );
    if (!mounted) return;
    Navigator.of(context).pop('saved');
    showAppSnack(context, widget.account == null ? 'Conta criada' : 'Conta atualizada');
  }

  String _typeIcon() => switch (_type) {
        'cash' => 'wallet',
        'credit' => 'credit',
        'investment' => 'investment',
        'savings' => 'savings',
        'digital' => 'digital',
        _ => 'bank',
      };

  Future<void> _toggleArchived() async {
    final a = widget.account;
    if (a == null) return;
    if (!a.archived && a.isDefault) {
      showAppSnack(context, 'Defina outra conta como padrão antes de desativar.', error: true);
      return;
    }
    await ref.read(databaseProvider).setAccountArchived(a.id, archived: !a.archived);
    if (!mounted) return;
    Navigator.of(context).pop(a.archived ? 'unarchived' : 'archived');
    showAppSnack(context, a.archived ? 'Conta reativada' : 'Conta desativada');
  }

  Future<void> _delete() async {
    final a = widget.account;
    if (a == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Excluir conta?',
      message: 'As transações dessa conta serão arquivadas. Você pode recuperá-las depois.',
      confirmLabel: 'Excluir',
    );
    if (!ok) return;
    final db = ref.read(databaseProvider);
    await db.softDelete('accounts', a.id);
    if (a.isDefault) {
      final others = await db.getAccounts();
      if (others.isNotEmpty) await db.setDefaultAccount(others.first.id);
    }
    if (!mounted) return;
    Navigator.of(context).pop('deleted');
    showAppSnack(context, 'Conta excluída');
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;
    final isArchived = widget.account?.archived ?? false;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isEdit ? 'Editar conta' : 'Nova conta',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (isEdit)
                IconButton(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: scheme.error,
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('account_name'),
            controller: _name,
            autofocus: !isEdit,
            decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Nubank, Carteira, Poupança...'),
          ),
          const SizedBox(height: 14),
          MoneyField(
            key: const ValueKey('account_initial'),
            label: 'Saldo inicial',
            controller: _initial,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const ValueKey('account_type'),
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(value: 'checking', child: Text('Conta corrente')),
              DropdownMenuItem(value: 'savings', child: Text('Poupança')),
              DropdownMenuItem(value: 'cash', child: Text('Dinheiro')),
              DropdownMenuItem(value: 'credit', child: Text('Cartão de crédito')),
              DropdownMenuItem(value: 'investment', child: Text('Investimento')),
              DropdownMenuItem(value: 'digital', child: Text('Conta digital')),
              DropdownMenuItem(value: 'wallet', child: Text('Carteira')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'checking'),
          ),
          const SizedBox(height: 14),
          Text('Cor', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in AppColors.accountColors)
                GestureDetector(
                  onTap: () => setState(() => _color = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: _color == color
                          ? Border.all(color: scheme.onSurface, width: 3)
                          : null,
                    ),
                    child: _color == color
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: Text(isEdit ? 'Salvar' : 'Criar conta')),
          if (isEdit && isArchived) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _toggleArchived,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Reativar conta'),
            ),
          ] else if (isEdit && !widget.account!.isDefault) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(databaseProvider).setDefaultAccount(widget.account!.id);
                if (context.mounted) {
                  Navigator.of(context).pop('saved');
                  showAppSnack(context, 'Conta definida como padrão das transações');
                }
              },
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text('Definir como padrão'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _toggleArchived,
              icon: const Icon(Icons.pause_circle_outline_rounded),
              label: const Text('Desativar conta'),
            ),
          ] else if (widget.account?.isDefault ?? false) ...[
            const SizedBox(height: 10),
            const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
                  SizedBox(width: 6),
                  Text('Conta padrão definida',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}