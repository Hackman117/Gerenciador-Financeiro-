import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column, Table;

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/common.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  String get _monthKey => Formats.monthKey(_month);

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(budgetsForMonthProvider(_monthKey));
    final categories = ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
    final monthEnd = endOfDay(DateTime(_month.year, _month.month + 1, 0));
    final spentByCategory = ref.watch(spentByCategoryProvider((
      _month,
      monthEnd,
    ))).asData?.value ?? const <String, int>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Orçamentos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(null),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    Formats.monthYear(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: budgets.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (list) {
                final expenseCats = categories.where((c) => c.type == kExpense).toList();
                final budgetByCategory = {for (final b in list) b.categoryId: b};

                if (expenseCats.isEmpty) {
                  return const EmptyState(icon: Icons.pie_chart_rounded, title: 'Sem categorias', subtitle: 'Crie categorias para definir orçamentos.');
                }

                final totalLimit = list.fold<int>(0, (s, b) => s + b.limitAmount);
                final totalSpent = list.fold<int>(
                  0,
                  (s, b) => s + (spentByCategory[b.categoryId] ?? 0),
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _MonthSummary(
                      totalLimit: totalLimit,
                      totalSpent: totalSpent,
                      count: list.length,
                    ),
                    SectionHeader(
                      title: 'Limites por categoria',
                      trailing: TextButton.icon(
                        onPressed: _nop,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Adicionar'),
                      ),
                    ),
                    for (final cat in expenseCats)
                      _BudgetCard(
                        category: cat,
                        budget: budgetByCategory[cat.id],
                        spent: spentByCategory[cat.id] ?? 0,
                        onTap: () => _showEditor(budgetByCategory[cat.id]),
                        onAdd: () => _showEditor(null, preCategoryId: cat.id),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _nop() {}

  Future<void> _showEditor(Budget? budget, {String? preCategoryId}) async {
    final result = await showAppSheet<BudgetResult>(
      context,
      _BudgetEditorSheet(budget: budget, preCategoryId: preCategoryId),
    );
    if (result == null || !mounted) return;
    final db = ref.read(databaseProvider);
    final id = budget?.id ?? newId();
    await db.upsertBudget(
      BudgetsCompanion.insert(
        id: id,
        categoryId: result.categoryId,
        month: _monthKey,
        limitAmount: result.amount,
        createdAt: Value(DateTime.now()),
      ),
      id: id,
    );
    showAppSnack(context, result.amount == 0 ? 'Orçamento removido' : 'Orçamento salvo');
  }
}

class _MonthSummary extends StatelessWidget {
  final int totalLimit;
  final int totalSpent;
  final int count;

  const _MonthSummary({required this.totalLimit, required this.totalSpent, required this.count});

  @override
  Widget build(BuildContext context) {
    final percent = totalLimit == 0 ? 0.0 : (totalSpent / totalLimit).clamp(0.0, 1.0);
    final over = totalSpent > totalLimit;
    final color = over ? AppColors.expense : AppColors.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumo do mês', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Orçado', value: Formats.money(totalLimit)),
              const Spacer(),
              _Stat(label: 'Gasto', value: Formats.money(totalSpent), color: over ? AppColors.expense : null),
              const Spacer(),
              _Stat(label: 'Sobra', value: Formats.money(totalLimit - totalSpent), color: over ? AppColors.expense : AppColors.income),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                over ? 'Atenção: você ultrapassou o orçamento!' : '${(percent * 100).toStringAsFixed(0)}% do orçamento usado',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
              ),
              const Spacer(),
              Text('$count categoria(s)', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _Stat({required String label, required String value, Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      );
}

class _BudgetCard extends StatelessWidget {
  final Category category;
  final Budget? budget;
  final int spent;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _BudgetCard({required this.category, required this.budget, required this.spent, required this.onTap, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (budget == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: AppCard(
          onTap: onAdd,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CategoryAvatar(icon: category.icon, color: category.color, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700))),
              const Icon(Icons.add_circle_outline_rounded),
            ],
          ),
        ),
      );
    }

    final limit = budget!.limitAmount;
    final ratio = limit == 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final over = spent > limit;
    final color = over ? AppColors.expense : (ratio >= .8 ? AppColors.warning : AppColors.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CategoryAvatar(icon: category.icon, color: category.color, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                      Text(
                        '${Formats.money(spent)} / ${Formats.money(limit)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      color: color,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    over ? 'Excedeu o limite' : '${Formats.money(limit - spent)} restantes',
                    style: TextStyle(fontSize: 11, color: over ? AppColors.expense : Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetResult {
  final String categoryId;
  final int amount;

  const BudgetResult(this.categoryId, this.amount);
}

class _BudgetEditorSheet extends ConsumerStatefulWidget {
  final Budget? budget;
  final String? preCategoryId;

  const _BudgetEditorSheet({this.budget, this.preCategoryId});

  @override
  ConsumerState<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends ConsumerState<_BudgetEditorSheet> {
  final _amount = TextEditingController();
  late String? _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.budget?.categoryId ?? widget.preCategoryId;
    if (widget.budget != null) {
      MoneyField.format('${widget.budget!.limitAmount}', _amount);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
    final expenseCats = categories.where((c) => c.type == kExpense).toList();
    final isEdit = widget.budget != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEdit ? 'Editar orçamento' : 'Novo orçamento', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              for (final c in expenseCats)
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
          MoneyField(label: 'Limite mensal', controller: _amount),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              final amountText = _amount.text.replaceAll(RegExp(r'[^\d,\.]'), '').replaceAll('.', '').replaceAll(',', '.');
              final amount = _amount.text.isEmpty ? 0 : (double.parse(amountText).toInt() * 100);
              final categoryId = _categoryId;
              if (categoryId == null) {
                showAppSnack(context, 'Escolha a categoria.', error: true);
                return;
              }
              if (amount == 0) {
                showAppSnack(context, 'Limite inválido. Informe um valor maior que zero.', error: true);
                return;
              }
              Navigator.of(context).pop(BudgetResult(categoryId, amount));
            },
            child: Text(isEdit ? 'Salvar' : 'Criar orçamento'),
          ),
          if (isEdit) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop(BudgetResult(widget.budget!.categoryId, 0));
              },
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Remover orçamento'),
            ),
          ],
        ],
      ),
    );
  }
}