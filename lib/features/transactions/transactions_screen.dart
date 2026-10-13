import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/common.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String? _type;
  String? _search;
  DateTimeRange? _range;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range ?? DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final transactions = ref.watch(
      transactionsForFiltersProvider((
        type: _type,
        search: _search,
        from: range?.start,
        to: range == null ? null : endOfDay(range.end),
      )),
    );
    final categories = ref.watch(categoriesProvider).asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transações'),
        actions: [
          if (_range != null)
            IconButton(
              tooltip: 'Limpar período',
              onPressed: () => setState(() => _range = null),
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          _FiltersBar(
            type: _type,
            search: _search,
            range: _range,
            onTypeChanged: (t) => setState(() => _type = t),
            onSearchChanged: (s) => setState(() => _search = s.isEmpty ? null : s),
            onRangeTap: _pickRange,
          ),
          Expanded(
            child: transactions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (list) {
                if (list.isEmpty) {
                  final filtered = _type != null || _search != null || _range != null;
                  return EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: filtered ? 'Nada encontrado' : 'Sem transações',
                    subtitle: filtered
                        ? 'Nenhum lançamento corresponde aos filtros atuais.'
                        : 'Toque em + para registrar um gasto ou receita — '
                            'ou carregue dados de exemplo para ver o app cheio.',
                    action: filtered ? null : const LoadDemoButton(),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final tx = list[i];
                    final category = categories.where((c) => c.id == tx.categoryId).firstOrNull;
                    return _TransactionTile(tx: tx, category: category);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final String? type;
  final String? search;
  final DateTimeRange? range;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRangeTap;

  const _FiltersBar({
    required this.type,
    required this.search,
    required this.range,
    required this.onTypeChanged,
    required this.onSearchChanged,
    required this.onRangeTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Buscar transação...',
                    prefixIcon: Icon(Icons.search_rounded),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRangeTap,
                style: IconButton.styleFrom(
                  backgroundColor: range != null ? scheme.primaryContainer : scheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.date_range_rounded),
                tooltip: range == null ? 'Filtrar por período' : rangeText(range!),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todas'),
                  selected: type == null,
                  onSelected: (_) => onTypeChanged(null),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  avatar: const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.expense),
                  label: const Text('Despesas'),
                  selected: type == kExpense,
                  onSelected: (_) => onTypeChanged(type == kExpense ? null : kExpense),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  avatar: const Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.income),
                  label: const Text('Receitas'),
                  selected: type == kIncome,
                  onSelected: (_) => onTypeChanged(type == kIncome ? null : kIncome),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  avatar: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.transfer),
                  label: const Text('Transferências'),
                  selected: type == kTransfer,
                  onSelected: (_) => onTypeChanged(type == kTransfer ? null : kTransfer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String rangeText(DateTimeRange r) => '${Formats.date(r.start)} a ${Formats.date(r.end)}';
}

class _TransactionTile extends ConsumerWidget {
  final Tx tx;
  final Category? category;

  const _TransactionTile({required this.tx, this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = tx.type == kIncome;
    final isTransfer = tx.type == kTransfer;
    final color = isTransfer ? AppColors.transfer : (isIncome ? AppColors.income : AppColors.expense);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () => context.push('/nova-transacao/${tx.id}'),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CategoryAvatar(icon: category?.icon ?? 'other', color: category?.color ?? 0xFF94A3B8),
        title: Text(
          tx.description.isNotEmpty ? tx.description : (category?.name ?? 'Sem categoria'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
        subtitle: Text(
          '${Formats.date(tx.date)}${isTransfer ? ' • Transferência' : ' • ${category?.name ?? ''}'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'} ${Formats.money(tx.amount)}',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color),
        ),
      ),
    );
  }
}