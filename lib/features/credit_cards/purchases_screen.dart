import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/credit_models.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/common.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  Future<void> _newPurchase(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final cards = await db.getCreditCards();
    if (!context.mounted) return;
    final active = cards.where((c) => c.active).toList();
    if (active.isEmpty) {
      showAppSnack(context, 'Ative um cartão antes de registrar compras.', error: true);
      return;
    }
    CreditCard? selected;
    if (active.length > 1) {
      selected = await showModalBottomSheet<CreditCard>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => _CardPickerSheet(cards: active),
      );
    } else {
      selected = active.first;
    }
    if (selected == null) return;
    final CreditCard picked = selected;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PurchaseEditorScreen(card: picked),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchasesProvider(null)).value ?? const <Purchase>[];
    final cards = ref.watch(creditCardsProvider).value ?? const <CreditCard>[];

    final grouped = <String, List<Purchase>>{};
    for (final p in purchases) {
      grouped.putIfAbsent(p.creditCardId, () => []).add(p);
    }
    final remaining = purchases.where((p) => !p.paid).fold<int>(0, (sum, p) => sum + p.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras'),
        actions: [
          if (purchases.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  Formats.money(remaining),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-purchases',
        key: const ValueKey('purchases_add'),
        onPressed: () => _newPurchase(context, ref),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Nova compra'),
      ),
      body: purchases.isEmpty
          ? const SingleChildScrollView(
              child: EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Nenhuma compra',
                subtitle: 'Cadastre compras realizadas no cartão de crédito.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                for (final card in cards.where((c) => grouped.containsKey(c.id))) ...[
                  SectionHeader(title: card.name),
                  for (final p in grouped[card.id]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PurchaseTile(
                        key: ValueKey('purchase_${p.id}'),
                        purchase: p,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PurchaseDetailScreen(purchase: p),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class PurchaseTile extends ConsumerWidget {
  final Purchase purchase;
  final VoidCallback? onTap;

  const PurchaseTile({super.key, required this.purchase, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final parcels = ref.watch(purchaseParcelsProvider(purchase.id)).value ?? const <PurchaseParcel>[];
    final nextDue = parcels.where((p) => !p.paid).map((p) => p.dueDate).toList()..sort();
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shopping_bag_outlined,
                size: 20, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(purchase.establishment,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(
                  purchase.installmentCount > 1
                      ? '${purchase.installmentCount}x de ${Formats.money(purchase.installmentAmount)}'
                      : 'À vista',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 3),
                Text(
                  nextDue.isEmpty ? 'Todas as parcelas pagas' : 'Próxima vence ${Formats.fullDate(nextDue.first)}',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formats.money(purchase.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 3),
              if (purchase.paid)
                Text('Quitada',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.income))
              else
                Text('Em aberto',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning)),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _CardPickerSheet extends StatelessWidget {
  final List<CreditCard> cards;

  const _CardPickerSheet({required this.cards});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Escolha o cartão',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final card in cards)
              ListTile(
                key: ValueKey('pick_card_${card.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(card.color).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.credit_card_rounded,
                      size: 20, color: Color(card.color)),
                ),
                title: Text(card.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).pop(card),
              ),
          ],
        ),
      ),
    );
  }
}

class PurchaseEditorScreen extends ConsumerStatefulWidget {
  final CreditCard card;
  final Purchase? purchase;

  const PurchaseEditorScreen({super.key, required this.card, this.purchase});

  @override
  ConsumerState<PurchaseEditorScreen> createState() => _PurchaseEditorScreenState();
}

class _PurchaseEditorScreenState extends ConsumerState<PurchaseEditorScreen> {
  late final TextEditingController _establishment;
  late final TextEditingController _total;
  late final TextEditingController _description;
  late DateTime _date;
  late int _installments;
  late bool _installmentMode;
  late String? _categoryId;

  @override
  void initState() {
    super.initState();
    final p = widget.purchase;
    _establishment = TextEditingController(text: p?.establishment ?? '');
    _total = TextEditingController();
    if (p != null) MoneyField.format('${p.totalAmount}', _total);
    _description = TextEditingController(text: p?.description ?? '');
    _date = p?.purchaseDate ?? DateTime.now();
    _installments = (p?.installmentCount ?? 1).clamp(1, 48);
    _installmentMode = (p?.installmentCount ?? 1) > 1;
    _categoryId = p?.categoryId;
    _total.addListener(_onTotalChanged);
  }

  void _onTotalChanged() => setState(() {});

  @override
  void dispose() {
    _total.removeListener(_onTotalChanged);
    _establishment.dispose();
    _total.dispose();
    _description.dispose();
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
    final establishment = _establishment.text.trim();
    if (establishment.isEmpty) {
      showAppSnack(context, 'Informe o estabelecimento.', error: true);
      return;
    }
    final total = MoneyField.centsOf(_total);
    if (total <= 0) {
      showAppSnack(context, 'Informe um valor maior que zero.', error: true);
      return;
    }
    final paragraphs = _installmentMode ? _installments : 1;
    await db.savePurchase(
      id: widget.purchase?.id,
      creditCardId: widget.card.id,
      categoryId: _categoryId,
      establishment: establishment,
      totalAmount: total,
      installmentCount: paragraphs,
      purchaseDate: _date,
      description: _description.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnack(context, widget.purchase == null ? 'Compra registrada' : 'Compra atualizada');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final allowedCategories = categories.where((c) => c.type == kExpense).toList();
    final total = MoneyField.centsOf(_total);
    final installments = _installmentMode ? _installments : 1;
    final values = total > 0 && installments > 0 ? AppDatabase.splitAmount(total, installments) : <int>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.purchase == null ? 'Nova compra' : 'Editar compra'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _CardBanner(name: widget.card.name, color: widget.card.color),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('purchase_editor_establishment'),
            controller: _establishment,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Estabelecimento',
              hintText: 'Ex.: Mercado, Farmácia...',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 14),
          MoneyField(
            key: const ValueKey('purchase_editor_total'),
            label: 'Valor total',
            controller: _total,
          ),
          const SizedBox(height: 6),
          Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SwitchListTile(
                key: const ValueKey('purchase_editor_installment_toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Parcelado'),
                subtitle: Text(values.isNotEmpty
                    ? '${installments}x de ${Formats.money(values.first)}'
                    : 'Informe o valor total'),
                value: _installmentMode,
                onChanged: (v) => setState(() => _installmentMode = v),
              ),
            ),
          ),
          if (_installmentMode) ...[
              const SizedBox(height: 6),
              _ParcelaStepper(
                value: _installments,
                total: total,
                onChange: (v) => setState(() => _installments = v),
              ),
              if (values.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '1ª parcela de ${Formats.money(values.first)} em ${Formats.fullDate(DateTime(_date.year, _date.month, widget.card.closingDay))}',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const ValueKey('purchase_editor_category'),
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined)),
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
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Data da compra', prefixIcon: Icon(Icons.calendar_today_rounded)),
              child: Text(Formats.fullDate(_date), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Descrição (opcional)', prefixIcon: Icon(Icons.notes_rounded)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('purchase_editor_save'),
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(widget.purchase == null ? 'Registrar compra' : 'Salvar alterações'),
          ),
        ],
      ),
    );
  }
}

class PurchaseDetailScreen extends ConsumerWidget {
  final Purchase purchase;

  const PurchaseDetailScreen({super.key, required this.purchase});

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancelar compra?',
      message: 'A compra e as parcelas restantes serão removidas.',
    );
    if (!ok) return;
    await ref.read(databaseProvider).cancelPurchase(purchase.id);
    if (context.mounted) {
      Navigator.of(context).pop();
      showAppSnack(context, 'Compra cancelada');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final parcels = ref.watch(purchaseParcelsProvider(purchase.id)).value ?? const <PurchaseParcel>[];
    final card = ref.watch(creditCardsProvider).value?.where((c) => c.id == purchase.creditCardId).firstOrNull;
    final category = ref.watch(categoriesProvider).value?.where((c) => c.id == purchase.categoryId).firstOrNull;
    final paidCount = parcels.where((p) => p.paid).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compra'),
        actions: [
          if (card != null)
            IconButton(
              key: const ValueKey('purchase_detail_edit'),
              tooltip: 'Editar',
              onPressed: () async {
                await Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => PurchaseEditorScreen(card: card, purchase: purchase),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            key: const ValueKey('purchase_detail_cancel'),
            tooltip: 'Cancelar',
            onPressed: () => _cancel(context, ref),
            icon: const Icon(Icons.remove_shopping_cart_outlined),
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
                    Expanded(
                      child: Text(purchase.establishment,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    ),
                    if (purchase.paid)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Quitada',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.income)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailRow(icon: Icons.receipt_long_outlined, label: 'Total', value: Formats.money(purchase.totalAmount)),
                _DetailRow(icon: Icons.view_module_outlined, label: 'Parcelas', value: '${purchase.installmentCount}x de ${Formats.money(purchase.installmentAmount)}'),
                _DetailRow(icon: Icons.calendar_today_outlined, label: 'Data da compra', value: Formats.fullDate(purchase.purchaseDate)),
                if (card != null)
                  _DetailRow(icon: Icons.credit_card_outlined, label: 'Cartão', value: card.name),
                if (category != null)
                  _DetailRow(icon: Icons.category_outlined, label: 'Categoria', value: category.name),
                if (purchase.description.isNotEmpty)
                  _DetailRow(icon: Icons.notes_rounded, label: 'Descrição', value: purchase.description),
              ],
            ),
          ),
          SectionHeader(
            title: 'Parcelas',
            trailing: Text(
              paidCount == parcels.length && parcels.isNotEmpty ? 'Quitada' : '$paidCount/${parcels.length} pagas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
            ),
          ),
          if (parcels.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Nenhuma parcela.')),
            ),
          for (final parcel in parcels)
            AppCard(
              key: ValueKey('parcel_${parcel.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Checkbox(
                    key: ValueKey('parcel_check_${parcel.installmentNumber}'),
                    value: parcel.paid,
                    onChanged: (v) =>
                        ref.read(databaseProvider).setParcelPaid(parcel.id, paid: v ?? false),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Parcela ${parcel.installmentNumber}/${purchase.installmentCount}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('Vence ${Formats.fullDate(parcel.dueDate)}',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text(
                    Formats.money(parcel.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      decoration: parcel.paid ? TextDecoration.lineThrough : null,
                      color: parcel.paid ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _cancel(context, ref),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar compra'),
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
          ),
        ],
      ),
    );
  }
}

class _CardBanner extends StatelessWidget {
  final String name;
  final int color;

  const _CardBanner({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final base = Color(color);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [base.withValues(alpha: .9), base.withValues(alpha: .6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.credit_card_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _ParcelaStepper extends StatelessWidget {
  final int value;
  final int total;
  final ValueChanged<int> onChange;

  const _ParcelaStepper({required this.value, required this.total, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parcela = total > 0 ? AppDatabase.splitAmount(total, value).firstOrNull ?? 0 : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.view_module_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nº de parcelas',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  '$value vez${value > 1 ? 'es' : ''} de ${Formats.money(parcela)}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton.outlined(
            onPressed: value > 1 ? () => onChange(value - 1) : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          Text('$value',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          IconButton.outlined(
            onPressed: value < 48 ? () => onChange(value + 1) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}