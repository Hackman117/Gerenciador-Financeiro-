import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/sync.dart';
import '../../ui/common.dart';
import '../shell/app_shell.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          _SyncSection(db: db),
          const SectionHeader(title: 'Aparência'),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6_rounded),
                title: const Text('Tema'),
                subtitle: const Text('Aparência do app'),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Escuro')),
                  ],
                  selected: {themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) async {
                    final value = s.first;
                    await db.setSetting('theme_mode', value.name);
                  },
                ),
              ),
            ],
          ),
          const SectionHeader(title: 'Segurança'),
          _SectionCard(
            children: [
              _PinTile(db: db),
            ],
          ),
          const SectionHeader(title: 'Exportar dados'),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.expense),
                title: const Text('Relatório em PDF'),
                subtitle: const Text('Gastos e gráficos de um período'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => ref.read(shellTabProvider.notifier).state = 4,
              ),
              ListTile(
                leading: const Icon(Icons.table_rows_rounded),
                title: const Text('Exportar CSV'),
                subtitle: const Text('Todas as movimentações'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _exportCsv(context, db),
              ),
            ],
          ),
          const SectionHeader(title: 'Dados'),
          _SectionCard(
            children: [
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: Theme.of(context).colorScheme.error),
                title: const Text('Apagar todos os dados'),
                subtitle: const Text('Remove contas, transações e metas deste dispositivo'),
                onTap: () => _clearData(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'FinaMind • feito com Flutter\nFunciona 100% offline, com sincronização opcional.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, AppDatabase db) async {
    final rows = await db.watchTransactions(limit: 100000).first;
    final buffer = StringBuffer('Data;Tipo;Valor;Descrição;Categoria\n');
    for (final row in rows) {
      final type = row.type == kIncome ? 'Receita' : (row.type == kTransfer ? 'Transferência' : 'Despesa');
      final value = (row.type == kExpense ? -row.amount : row.amount) / 100;
      buffer.writeln('${Formats.date(row.date)};$type;${value.toStringAsFixed(2)};${row.description};${row.categoryId}');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/finamind-export.csv');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Exportação FinaMind',
      );
      if (context.mounted) showAppSnack(context, 'CSV exportado (${rows.length} linhas)');
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'Falha ao exportar: $e', error: true);
    }
  }

  Future<void> _clearData(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Apagar todos os dados?',
      message: 'Essa ação é definitiva e não pode ser desfeita.',
      confirmLabel: 'Apagar tudo',
    );
    if (!ok) return;
    await ref.read(databaseProvider).clearAllData();
    if (context.mounted) showAppSnack(context, 'Dados removidos');
  }
}

class _PinTile extends ConsumerStatefulWidget {
  const _PinTile();

  @override
  ConsumerState<_PinTile> createState() => _PinTileState();
}

class _PinTileState extends ConsumerState<_PinTile> {
  @override
  Widget build(BuildContext context) {
    final pin = ref.watch(settingsProvider('app_pin')).valueOrNull;
    final enabled = pin != null && pin.isNotEmpty;

    return SwitchListTile(
      secondary: const Icon(Icons.lock_outline_rounded),
      title: const Text('Bloqueio por PIN'),
      subtitle: Text(enabled ? 'PIN ativo ao abrir o app' : 'Proteja seus dados com um PIN'),
      value: enabled,
      onChanged: (value) async {
        final db = ref.read(databaseProvider);
        if (value) {
          final result = await showAppSheet<String>(context, _PinSetupSheet());
          if (result != null && result.isNotEmpty) {
            await db.setSetting('app_pin', result);
            showAppSnack(context, 'PIN definido');
          }
        } else {
          final ok = await confirmDialog(
            context,
            title: 'Remover PIN?',
            message: 'O app voltará a abrir sem senha.',
          );
          if (ok) await db.setSetting('app_pin', '');
        }
      },
    );
  }
}

class _PinSetupSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends ConsumerState<_PinSetupSheet> {
  final _controller = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _confirm.dispose();
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
          const Text('Definir PIN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Use de 4 a 6 dígitos para proteger seus dados.', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'PIN', prefixIcon: Icon(Icons.pin_outlined), counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Confirmar PIN', prefixIcon: Icon(Icons.pin_outlined), counterText: ''),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              final pin = _controller.text.trim();
              if (pin.length < 4) {
                showAppSnack(context, 'PIN precisa ter pelo menos 4 dígitos.', error: true);
                return;
              }
              if (pin != _confirm.text.trim()) {
                showAppSnack(context, 'Os PINs não coincidem.', error: true);
                return;
              }
              Navigator.of(context).pop(pin);
            },
            child: const Text('Salvar PIN'),
          ),
        ],
      ),
    );
  }
}

class _SyncSection extends ConsumerStatefulWidget {
  final AppDatabase db;

  const _SyncSection({required this.db});

  @override
  ConsumerState<_SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends ConsumerState<_SyncSection> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _syncing = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastSync = ref.watch(settingsProvider('last_sync_at')).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Sincronização'),
        AppCard(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_sync_outlined, color: AppColors.primary),
                ),
                title: const Text('Nuvem opcional', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  lastSync != null && lastSync.isNotEmpty
                      ? 'Última sincronização: ${Formats.fullDate(DateTime.parse(lastSync).toLocal())}'
                      : 'Sem conta conectada. Seus dados ficam só no dispositivo.',
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true,
              ),
              const SizedBox(height: 4),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
              else ...[
                _loginForm(),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _syncing ? null : _syncNow,
                  icon: _syncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(_syncing ? 'Sincronizando...' : 'Sincronizar agora'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            AppConfig.hasSupabase
                ? 'Para ativar, configure SUPABASE_URL e SUPABASE_ANON_KEY (ver README).'
                : 'Funciona 100% offline. Ative a nuvem no build para sincronizar entre dispositivos.',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _loginForm() {
    // Alta densidade, escondida se já há sessão ativa.
    return Column(
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline_rounded), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.lock_outline_rounded), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submit('login'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                child: const Text('Entrar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _submit('signup'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                child: const Text('Criar conta'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  VoidCallback _submit(String mode) {
    return () async {
      final email = _email.text.trim();
      final password = _password.text;
      if (email.isEmpty || password.length < 6) {
        showAppSnack(context, 'Informe e-mail e senha (mín. 6 caracteres).', error: true);
        return;
      }
      setState(() => _loading = true);
      try {
        final sync = ref.read(syncEngineProvider);
        if (mode == 'login') {
          await sync.service.signIn(email: email, password: password);
        } else {
          await sync.service.signUp(email: email, password: password);
          showAppSnack(context, 'Conta criada! Você pode entrar agora.');
          return;
        }
        await sync.run();
        if (mounted) showAppSnack(context, 'Conectado! Dados sincronizados.');
      } catch (e) {
        if (mounted) showAppSnack(context, e.toString(), error: true);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    };
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final sync = ref.read(syncEngineProvider);
      await sync.run();
      if (mounted) showAppSnack(context, 'Sincronizado com sucesso!');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}