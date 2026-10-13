import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/common.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-goals',
        onPressed: () => showAppSheet(context, _GoalEditorSheet(goal: null)),
        child: const Icon(Icons.add_rounded),
      ),
      body: goals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) {
          final active = list.where((g) => !g.completed).toList();
          final done = list.where((g) => g.completed).toList();
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_rounded,
              title: 'Nenhuma meta',
              subtitle: 'Defina objetivos como viagem, reserva de emergência ou um novo celular.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              _GoalsSummary(goals: list),
              const SectionHeader(title: 'Em andamento'),
              for (final g in active) _GoalCard(goal: g),
              if (done.isNotEmpty) ...[
                const SectionHeader(title: 'Concluídas'),
                for (final g in done) _GoalCard(goal: g),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GoalsSummary extends StatelessWidget {
  final List<Goal> goals;

  const _GoalsSummary({required this.goals});

  @override
  Widget build(BuildContext context) {
    final saved = goals.fold<int>(0, (s, g) => s + (g.completed ? 0 : g.savedAmount));
    final target = goals.fold<int>(0, (s, g) => s + (g.completed ? 0 : g.targetAmount));
    final percent = target == 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suas metas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(label: 'Guardado', value: Formats.money(saved), icon: Icons.savings_rounded, color: AppColors.income),
              const Spacer(),
              _Stat(label: 'Faltam', value: Formats.money(target - saved), icon: Icons.flag_rounded, color: AppColors.warning),
              const Spacer(),
              _Stat(label: 'Concluídas', value: '${goals.where((g) => g.completed).length}', icon: Icons.check_circle_rounded, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: percent, minHeight: 10),
          ),
        ],
      ),
    );
  }

  static Widget _Stat({required String label, required String value, required IconData icon, required Color color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ],
      );
}

class _GoalCard extends ConsumerWidget {
  final Goal goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratio = goal.targetAmount == 0 ? 0.0 : (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0);
    final color = Color(goal.color);
    final remainingDays = goal.deadline?.difference(DateTime.now()).inDays;
    final overdue = remainingDays != null && remainingDays < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppCard(
        onTap: () => showAppSheet(
          context,
          _GoalActionsSheet(
            goal: goal,
            onEdit: () {
              Navigator.of(context).pop();
              showAppSheet(
                context,
                _GoalEditorSheet(goal: goal),
              );
            },
            onContribute: () {
              Navigator.of(context).pop();
              showAppSheet(context, _ContributionSheet(goal: goal));
            },
            onWithdraw: () {
              Navigator.of(context).pop();
              showAppSheet(context, _ContributionSheet(goal: goal, withdraw: true));
            },
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(goal.completed ? Icons.emoji_events_rounded : Icons.flag_rounded, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(goal.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                      Text(
                        '${(ratio * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontWeight: FontWeight.w800, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: ratio, minHeight: 8, color: color),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${Formats.money(goal.savedAmount)} de ${Formats.money(goal.targetAmount)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (goal.deadline != null && !goal.completed)
                        Text(
                          overdue
                              ? '${remainingDays.abs()}d em atraso'
                              : '$remainingDays dias restantes',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: overdue ? AppColors.expense : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
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

class _GoalActionsSheet extends StatelessWidget {
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onContribute;
  final VoidCallback onWithdraw;

  const _GoalActionsSheet({required this.goal, required this.onEdit, required this.onContribute, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(goal.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Guardado: ${Formats.money(goal.savedAmount)} de ${Formats.money(goal.targetAmount)}',
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onContribute,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar ao objetivo'),
          ),
          const SizedBox(height: 10),
          if (goal.savedAmount > 0)
            OutlinedButton.icon(
              onPressed: onWithdraw,
              icon: const Icon(Icons.remove_rounded),
              label: const Text('Retirar valor'),
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar meta'),
          ),
        ],
      ),
    );
  }
}

class _ContributionSheet extends ConsumerStatefulWidget {
  final Goal goal;
  final bool withdraw;

  const _ContributionSheet({required this.goal, this.withdraw = false});

  @override
  ConsumerState<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends ConsumerState<_ContributionSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.withdraw ? 'Retirar de ${widget.goal.name}' : 'Adicionar a ${widget.goal.name}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          MoneyField(label: 'Valor', controller: _amount),
          const SizedBox(height: 4),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Nota (opcional)', hintText: 'Ex.: salário, presente...')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              final amount = MoneyField.centsOf(_amount);
              if (amount <= 0) {
                showAppSnack(context, 'Informe um valor maior que zero.', error: true);
                return;
              }
              final db = ref.read(databaseProvider);
              final finalAmount = widget.withdraw ? -amount : amount;
              if (widget.withdraw && widget.goal.savedAmount + finalAmount < 0) {
                showAppSnack(context, 'Valor maior que o guardado.', error: true);
                return;
              }
              await db.addContribution(
                goalId: widget.goal.id,
                amount: finalAmount,
                note: _note.text.trim(),
              );
              if (!mounted) return;
              Navigator.of(context).pop();
              showAppSnack(context, widget.withdraw ? 'Valor retirado' : 'Valor adicionado à meta');
            },
            child: Text(widget.withdraw ? 'Retirar' : 'Adicionar'),
          ),
        ],
      ),
    );
  }
}

class _GoalEditorSheet extends ConsumerStatefulWidget {
  final Goal? goal;

  const _GoalEditorSheet({this.goal});

  @override
  ConsumerState<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends ConsumerState<_GoalEditorSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  late int _color;
  late DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _name.text = g?.name ?? '';
    if (g != null) MoneyField.format('${g.targetAmount}', _target);
    _color = g?.color ?? AppColors.categoryColors[1];
    _deadline = g?.deadline;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.goal != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Editar meta' : 'Nova meta', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Viagem, Reserva de emergência...')),
            const SizedBox(height: 14),
            MoneyField(label: 'Meta (valor total)', controller: _target),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final existing = _deadline;
                final initial = existing == null || existing.isBefore(now) ? now : existing;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: now,
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Prazo (opcional)', prefixIcon: Icon(Icons.event_rounded)),
                child: Text(
                  _deadline == null ? 'Escolher data' : Formats.fullDate(_deadline!),
                  style: TextStyle(fontWeight: FontWeight.w600, color: _deadline == null ? Colors.grey : null),
                ),
              ),
            ),
            const SizedBox(height: 14),
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
                        border: _color == color ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3) : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                final name = _name.text.trim();
                final target = MoneyField.centsOf(_target);
                if (name.isEmpty) {
                  showAppSnack(context, 'Dê um nome para a meta.', error: true);
                  return;
                }
                if (target <= 0) {
                  showAppSnack(context, 'Defina um valor maior que zero.', error: true);
                  return;
                }
                final db = ref.read(databaseProvider);
                final id = widget.goal?.id ?? newId();
                await db.upsertGoal(
                  GoalsCompanion.insert(
                    id: id,
                    name: name,
                    targetAmount: target,
                    savedAmount: Value(widget.goal?.savedAmount ?? 0),
                    deadline: Value(_deadline),
                    color: Value(_color),
                    completed: Value(widget.goal?.completed ?? false),
                    createdAt: Value(DateTime.now()),
                  ),
                  id: id,
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                showAppSnack(context, isEdit ? 'Meta atualizada' : 'Meta criada');
              },
              child: Text(isEdit ? 'Salvar' : 'Criar meta'),
            ),
            if (isEdit) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  final ok = await confirmDialog(context, title: 'Excluir meta?', message: 'Essa ação não pode ser desfeita.');
                  if (!ok || !mounted) return;
                  await ref.read(databaseProvider).softDelete('goals', widget.goal!.id);
                  if (mounted) {
                    Navigator.of(context).pop();
                    showAppSnack(context, 'Meta excluída');
                  }
                },
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Excluir meta'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}