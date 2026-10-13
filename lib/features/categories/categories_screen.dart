import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/common.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-categories',
        onPressed: () => _showEditor(context, ref, category: null),
        child: const Icon(Icons.add_rounded),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(icon: Icons.category_rounded, title: 'Sem categorias', subtitle: 'Crie categorias para organizar seus gastos.');
          }
          final expenses = list.where((c) => c.type == kExpense).toList();
          final incomes = list.where((c) => c.type == kIncome).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              const SectionHeader(title: 'Despesas'),
              for (final c in expenses) _CategoryCard(category: c, onTap: () => _showEditor(context, ref, category: c)),
              const SectionHeader(title: 'Receitas'),
              for (final c in incomes) _CategoryCard(category: c, onTap: () => _showEditor(context, ref, category: c)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditor(BuildContext context, WidgetRef ref, {Category? category}) async {
    await showAppSheet(context, _CategoryEditorSheet(category: category));
  }
}

class _CategoryCard extends ConsumerWidget {
  final Category category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CategoryAvatar(icon: category.icon, color: category.color),
          title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          subtitle: Text(_typeLabel(category.type), style: const TextStyle(fontSize: 11.5)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  category.status != 'inactive' ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  color: category.status != 'inactive'
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                tooltip: category.status != 'inactive' ? 'Desativar' : 'Ativar',
                onPressed: () async {
                  final db = ref.watch(databaseProvider);
                  await db.setCategoryActive(category.id, active: category.status == 'inactive');
                  if (context.mounted) {
                    showAppSnack(context, category.status == 'inactive' ? 'Categoria ativada' : 'Categoria desativada');
                  }
                },
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  static String _typeLabel(String type) => type == kIncome ? 'Receita' : 'Despesa';
}

class _CategoryEditorSheet extends ConsumerStatefulWidget {
  final Category? category;

  const _CategoryEditorSheet({this.category});

  @override
  ConsumerState<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<_CategoryEditorSheet> {
  late final TextEditingController _name;
  late String _type;
  late String _icon;
  late int _color;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _name = TextEditingController(text: c?.name ?? '');
    _type = c?.type ?? kExpense;
    _icon = c?.icon ?? 'other';
    _color = c?.color ?? AppColors.categoryColors[0];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnack(context, 'Dê um nome para a categoria.', error: true);
      return;
    }
    final id = widget.category?.id ?? newId();
    await db.upsertCategory(
      CategoriesCompanion.insert(
        id: id,
        name: name,
        type: _type,
        icon: Value(_icon),
        color: Value(_color),
        isDefault: const Value(false),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
      id: id,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnack(context, widget.category == null ? 'Categoria criada' : 'Categoria atualizada');
  }
  Future<void> _delete() async {
    final c = widget.category;
    if (c == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Excluir categoria?',
      message: 'As transações continuarão, mas sem esta categoria.',
    );
    if (!ok) return;
    await ref.read(databaseProvider).softDelete('categories', c.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnack(context, 'Categoria excluída');
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isEdit ? 'Editar categoria' : 'Nova categoria',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (isEdit)
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Theme.of(context).colorScheme.error,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Academia, Salário, Feira...')),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: kExpense, label: Text('Despesa')),
                ButtonSegment(value: kIncome, label: Text('Receita')),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            Text('Ícone', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in CategoryIcons.names)
                  GestureDetector(
                    onTap: () => setState(() => _icon = name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _icon == name
                            ? Color(_color)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        CategoryIcons.byName(name),
                        color: _icon == name ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Cor', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in AppColors.categoryColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: _color == color
                            ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: Text(isEdit ? 'Salvar' : 'Criar categoria')),
            if (isEdit) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final db = ref.read(databaseProvider);
                  final active = (widget.category?.status ?? 'active') != 'inactive';
                  await db.setCategoryActive(widget.category!.id, active: !active);
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(!active ? 'Categoria ativada' : 'Categoria desativada')),
                  );
                },
                child: Text((widget.category?.status ?? 'active') != 'inactive' ? 'Desativar categoria' : 'Ativar categoria'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}