import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../data/providers.dart';
import '../../data/sync.dart';
import '../../ui/common.dart';
import 'auth_controller.dart';

/// Tela protegida: exibe o usuário autenticado e permite sair da conta.
///
/// Só é alcançável quando autenticado; a rota é bloqueada pelo guard
/// [authRedirect] quando não há sessão.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!auth.isAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = auth.displayName ?? 'Usuário';
    final email = auth.profile?.email;
    final lastSync = ref.watch(settingsProvider('last_sync_at')).value;
    final syncSubtitle = lastSync != null && lastSync.isNotEmpty
        ? 'Última sincronização: ${Formats.fullDate(DateTime.parse(lastSync).toLocal())}'
        : 'Nada foi sincronizado ainda.';

    return Scaffold(
      appBar: AppBar(title: const Text('Minha conta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradientDark,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (email != null)
                        Text(
                          email,
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.verified_rounded, color: scheme.primary),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_sync_outlined, color: scheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Sincronização',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  syncSubtitle,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                const _SyncNowButton(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('account_logout'),
            onPressed: () => _confirmAndSignOut(context, ref),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair da conta'),
          ),
          const SizedBox(height: 12),
          Text(
            'Sair não apaga os dados deste dispositivo — eles continuam offline.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Sair da conta?',
      message: 'Você continuará usando o app offline. Os dados sincronizados permanecem.',
      confirmLabel: 'Sair',
    );
    if (!ok || !context.mounted) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go('/entrar');
  }
}

class _SyncNowButton extends ConsumerStatefulWidget {
  const _SyncNowButton();

  @override
  ConsumerState<_SyncNowButton> createState() => _SyncNowButtonState();
}

class _SyncNowButtonState extends ConsumerState<_SyncNowButton> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      await ref.read(syncEngineProvider).run();
      if (mounted) showAppSnack(context, 'Sincronizado com sucesso!');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _syncing ? null : _sync,
      icon: _syncing
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.sync_rounded, size: 18),
      label: Text(_syncing ? 'Sincronizando...' : 'Sincronizar agora'),
    );
  }
}