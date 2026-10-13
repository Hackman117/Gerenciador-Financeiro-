import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/credit_models.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/common.dart';
import 'purchases_screen.dart';

String creditCardTypeLabel(String type) => switch (type) {
      'credit' => 'Cartão de crédito',
      _ => 'Cartão de crédito',
    };

class CreditCardsScreen extends ConsumerWidget {
  const CreditCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(creditCardsUsageProvider);
    final cards = usage.value ?? const <CreditCardUsage>[];
    final active = cards.where((u) => u.card.active).toList();
    final inactive = cards.where((u) => !u.card.active).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartões de crédito'),
        actions: [
          IconButton(
            key: const ValueKey('credit_cards_purchases'),
            tooltip: 'Compras',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PurchasesScreen()),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-cards',
        key: const ValueKey('credit_cards_add'),
        onPressed: () => _showEditor(context, ref, card: null),
        child: const Icon(Icons.add_rounded),
      ),
      body: usage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            if (cards.isEmpty)
              const EmptyState(
                icon: Icons.credit_card_rounded,
                title: 'Nenhum cartão',
                subtitle: 'Cadastre seu cartão de crédito para acompanhar limite e compras.',
              ),
            for (final usageItem in active)
              Padding(
                key: ValueKey('credit_card_${usageItem.card.id}'),
                padding: const EdgeInsets.only(bottom: 10),
                child: _CreditCardTile(
                  usage: usageItem,
                  onTap: () => _openDetail(context, usageItem.card),
                ),
              ),
            if (inactive.isNotEmpty) ...[
              const SectionHeader(title: 'Desativados'),
              for (final usageItem in inactive)
                Padding(
                  key: ValueKey('credit_card_inactive_${usageItem.card.id}'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CreditCardTile(
                    usage: usageItem,
                    onTap: () => _openDetail(context, usageItem.card),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, CreditCard card) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreditCardDetailScreen(card: card),
      ),
    );
  }

  Future<void> _showEditor(BuildContext context, WidgetRef ref, {CreditCard? card}) async {
    await showAppSheet<String>(context, CreditCardEditorSheet(card: card));
  }
}

class CreditCardDetailScreen extends ConsumerWidget {
  final CreditCard card;

  const CreditCardDetailScreen({super.key, required this.card});

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final current = ref.read(databaseProvider);
    final fresh = await current.getCreditCard(card.id);
    if (fresh == null) return;
    if (!context.mounted) return;
    final result = await showAppSheet<String>(
      context,
      CreditCardEditorSheet(card: fresh),
    );
    if (!context.mounted) return;
    if (result == 'deleted') {
      Navigator.of(context).pop('deleted');
    }
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final current = await db.getCreditCard(card.id);
    if (current == null) return;
    await db.setCreditCardActive(card.id, active: !current.active);
    if (context.mounted) {
      showAppSnack(
        context,
        current.active ? 'Cartão desativado' : 'Cartão ativado',
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir cartão?'),
        content: Text('As compras vinculadas também serão removidas (${card.name}).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).deleteCreditCard(card.id);
    if (context.mounted) {
      Navigator.of(context).pop('deleted');
      showAppSnack(context, 'Cartão excluído');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final usage = ref.watch(creditCardsUsageProvider).value ?? const <CreditCardUsage>[];
    final item = usage.where((u) => u.card.id == card.id).firstOrNull;
    final c = item?.card ?? card;
    final color = Color(c.color);
    final used = item?.used ?? 0;
    final available = item?.available ?? c.creditLimit;
    final account = ref.watch(accountByIdProvider(c.accountId)).value;

    return Scaffold(
      key: const ValueKey('credit_card_detail'),
      appBar: AppBar(
        title: const Text('Cartão'),
        actions: [
          IconButton(
            key: const ValueKey('credit_card_detail_edit'),
            tooltip: 'Editar',
            onPressed: () => _edit(context, ref),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: const ValueKey('credit_card_detail_delete'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.credit_card_rounded, size: 26, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(
                            account?.name ?? 'Conta não encontrada',
                            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (c.active)
                      _CardChip(label: 'Ativo', color: AppColors.income)
                    else
                      _CardChip(label: 'Inativo', color: scheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _LimitStat(label: 'Limite', value: Formats.money(c.creditLimit)),
                    ),
                    Expanded(
                      child: _LimitStat(
                        label: 'Limite disponível',
                        value: Formats.money(available),
                        color: available < c.creditLimit * 0.2 ? AppColors.expense : AppColors.income,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    key: const ValueKey('credit_card_detail_limit_progress'),
                    value: c.creditLimit <= 0 ? 0 : (used / c.creditLimit).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${Formats.money(used)} utilizado',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
                  leading: const Icon(Icons.event_repeat_outlined),
                  title: const Text('Dia de fechamento'),
                  trailing: Text('Dia ${c.closingDay}'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Dia de vencimento'),
                  trailing: Text('Dia ${c.dueDay}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (c.active)
            FilledButton.tonalIcon(
              key: const ValueKey('credit_card_detail_new_purchase'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PurchaseEditorScreen(card: c),
                  ),
                );
              },
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Nova compra'),
            )
          else
            FilledButton.tonalIcon(
              onPressed: () => _toggleActive(context, ref),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Ativar cartão'),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('credit_card_detail_deactivate'),
            onPressed: c.active ? () => _toggleActive(context, ref) : null,
            icon: c.active
                ? const Icon(Icons.pause_circle_outline_rounded)
                : const Icon(Icons.play_circle_outline_rounded),
            label: Text(c.active ? 'Desativar cartão' : 'Reativar cartão'),
          ),
          const SizedBox(height: 24),
          SectionHeader(title: 'Compras deste cartão'),
          Consumer(
            builder: (context, ref, _) {
              final purchases = ref.watch(purchasesProvider(card.id)).value ?? const <Purchase>[];
              if (purchases.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('Nenhuma compra registrada.')),
                );
              }
              return Column(
                children: [
                  for (final purchase in purchases)
                    PurchaseTile(
                      purchase: purchase,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PurchaseDetailScreen(purchase: purchase),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class CreditCardEditorSheet extends ConsumerStatefulWidget {
  final CreditCard? card;

  const CreditCardEditorSheet({super.key, this.card});

  @override
  ConsumerState<CreditCardEditorSheet> createState() => _CreditCardEditorSheetState();
}

class _CreditCardEditorSheetState extends ConsumerState<CreditCardEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _limit;
  late int _closingDay;
  late int _dueDay;
  late int _color;
  late String? _accountId;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    _name = TextEditingController(text: c?.name ?? '');
    _limit = TextEditingController();
    _closingDay = c?.closingDay ?? 25;
    _dueDay = c?.dueDay ?? 10;
    _color = c?.color ?? AppColors.accountColors.first;
    _accountId = c?.accountId;
    if (c != null) MoneyField.format('${c.creditLimit}', _limit);
  }

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnack(context, 'Dê um nome para o cartão.', error: true);
      return;
    }
    final limit = MoneyField.centsOf(_limit);
    if (limit <= 0) {
      showAppSnack(context, 'Informe um limite válido.', error: true);
      return;
    }

    var accountId = _accountId;
    if (accountId == null || accountId.isEmpty) {
      final accounts = await db.getAccounts();
      final creditAccount = accounts.where((a) => a.type == 'credit').firstOrNull;
      if (creditAccount != null) {
        accountId = creditAccount.id;
      } else {
        final defaultAccount = accounts.firstOrNull;
        if (defaultAccount != null) accountId = defaultAccount.id;
      }
    }
    if (accountId == null) {
      if (!mounted) return;
      showAppSnack(context, 'Crie uma conta antes de cadastrar o cartão.', error: true);
      return;
    }

    await db.saveCreditCard(
      id: widget.card?.id,
      name: name,
      accountId: accountId,
      creditLimit: limit,
      closingDay: _closingDay,
      dueDay: _dueDay,
      color: _color,
    );
    if (!mounted) return;
    Navigator.of(context).pop('saved');
    showAppSnack(context, widget.card == null ? 'Cartão criado' : 'Cartão atualizado');
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.card == null ? 'Novo cartão' : 'Editar cartão',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
TextField(
            key: const ValueKey('credit_card_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome do cartão'),
          ),
          const SizedBox(height: 14),
          MoneyField(
            key: const ValueKey('credit_card_limit'),
            label: 'Limite',
            controller: _limit,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<Account>(
            key: const ValueKey('credit_card_account'),
            initialValue: _accountId == null ? null : accounts.where((a) => a.id == _accountId).firstOrNull,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Conta vinculada'),
            items: [
              for (final account in accounts)
                DropdownMenuItem<Account>(value: account, child: Text(account.name)),
            ],
            onChanged: (account) => setState(() => _accountId = account?.id),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _DayStepper(label: 'Fechamento', value: _closingDay, onChanged: (v) => setState(() => _closingDay = v))),
              const SizedBox(width: 14),
              Expanded(child: _DayStepper(label: 'Vencimento', value: _dueDay, onChanged: (v) => setState(() => _dueDay = v))),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('credit_card_editor_save'),
              onPressed: _save,
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }
}

class PurchasesShortcut extends StatelessWidget {
  final CreditCard? card;
  final VoidCallback? onEdit;

  const PurchasesShortcut({super.key, this.card, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('Nova compra'),
        ),
      ),
    );
  }
}

class _CreditCardTile extends ConsumerWidget {
  final CreditCardUsage usage;
  final VoidCallback onTap;

  const _CreditCardTile({required this.usage, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final card = usage.card;
    final color = Color(card.color);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  card.active ? Icons.credit_card_rounded : Icons.credit_card_off_rounded,
                  size: 22,
                  color: card.active ? color : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('Fecha dia ${card.closingDay} • Vence dia ${card.dueDay}',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final isActive = ref.watch(creditCardsUsageProvider).value
                          ?.any((u) => u.card.id == card.id && u.card.active) ??
                      card.active;
                  return Switch(
                    key: ValueKey('credit_card_toggle_${card.id}'),
                    value: isActive,
                    onChanged: (v) =>
                        ref.read(databaseProvider).setCreditCardActive(card.id, active: v),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Limite', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    Text(Formats.money(card.creditLimit),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Disponível',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    Text(Formats.money(usage.available),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: usage.available <= 0 ? AppColors.expense : AppColors.income)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: usage.ratio,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: usage.ratio > 0.8 ? AppColors.expense : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  final String label;
  final Color color;

  const _CardChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _LimitStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _LimitStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: color ?? scheme.onSurface)),
      ],
    );
  }
}

class _DayStepper extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _DayStepper({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton.outlined(
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_rounded, size: 18),
            ),
            Expanded(
              child: Center(
                child: Text('$value',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
            IconButton.outlined(
              onPressed: value < 31 ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}