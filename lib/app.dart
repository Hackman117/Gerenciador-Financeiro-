import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/auth/account_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_screen.dart';
import 'features/editors/transaction_editor.dart';
import 'features/shell/app_shell.dart';
import 'features/settings/pin_lock_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Reconstrui o roteador quando o estado de autenticação muda, para que o
  // guard abaixo sempre reavalie as rotas protegidas (login/logout).
  final auth = ref.watch(authControllerProvider);
  return GoRouter(
    initialLocation: '/',
    navigatorKey: rootNavigatorKey,
    redirect: (context, state) => authRedirect(auth: auth, location: state.matchedLocation),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const AppShell()),
      GoRoute(path: '/entrar', builder: (_, _) => const AuthScreen()),
      GoRoute(path: '/conta', builder: (_, _) => const AccountScreen()),
      GoRoute(
        path: '/nova-transacao',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => TransactionEditorScreen(
          initialType: state.uri.queryParameters['tipo'],
        ),
      ),
      GoRoute(
        path: '/nova-transacao/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => TransactionEditorScreen(txId: state.pathParameters['id']),
      ),
    ],
  );
});

class FinaMindApp extends ConsumerWidget {
  const FinaMindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'FinaMind',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => PinLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}