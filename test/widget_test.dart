import 'package:drift/native.dart';
import 'package:finamind/data/auth_service.dart';
import 'package:finamind/data/database.dart';
import 'package:finamind/data/providers.dart';
import 'package:finamind/features/auth/account_screen.dart';
import 'package:finamind/features/auth/auth_controller.dart';
import 'package:finamind/features/auth/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_auth_service.dart';

/// Espelha as rotas e o guard do app.dart para testar a proteção das rotas.
final testRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  return GoRouter(
    initialLocation: '/conta',
    redirect: (context, state) => authRedirect(auth: auth, location: state.matchedLocation),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Center(child: Text('Início')))),
      GoRoute(path: '/entrar', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/conta', builder: (_, __) => const AccountScreen()),
    ],
  );
});

class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(routerConfig: ref.watch(testRouterProvider));
  }
}

void main() {
  late AppDatabase db;
  late FakeAuthService fake;
  late ProviderContainer container;

  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    db = await binding.runAsync(() async => AppDatabase.forTesting(NativeDatabase.memory())) ??
        AppDatabase.forTesting(NativeDatabase.memory());
    fake = FakeAuthService();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(() async {
      container.dispose();
      // O Drift roda em zona real; fecha o banco fora do FakeAsync do teste.
      await binding.runAsync(db.close);
    });
  });

  /// Avança o relógio de forma limitada (evita loops infinitos de frames).
  Future<void> settle(WidgetTester tester, [int steps = 20]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Usa apenas a tela informada (evita depender do resto do app).
  Future<void> pumpApp(WidgetTester tester) async {
    container.read(authControllerProvider.notifier);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const _TestApp()));
    await settle(tester);
  }

  /// Deixa o Drift (execução em zona real) concluir fora do FakeAsync.
  Future<void> flushAsync(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
  }

  Future<void> enter(WidgetTester tester, Key key, String text) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.enterText(find.byKey(key), text);
  }

  Finder submitButton(String label) => find.widgetWithText(FilledButton, label);

  testWidgets('usuário não autenticado tem acesso negado à rota protegida', (tester) async {
    await pumpApp(tester);

    expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(AccountScreen), findsNothing);
  });

  testWidgets('rota protegida /conta redireciona para o login', (tester) async {
    await pumpApp(tester);

    expect(find.byKey(const ValueKey('auth_email')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth_submit')), findsOneWidget);
    expect(find.byType(AccountScreen), findsNothing);
  });

  testWidgets('rota protegida /conta é liberada para usuário autenticado', (tester) async {
    fake.session = const AuthProfile(id: 'id-a@b.com', email: 'a@b.com');
    await pumpApp(tester);

    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('Minha conta'), findsOneWidget);
    expect(find.text('a@b.com'), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('cadastro válido autentica e mostra a conta', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(SegmentedButton<bool>, 'Criar conta'));
    await tester.pump();
    await enter(tester, const ValueKey('auth_name'), 'Ana Teste');
    await enter(tester, const ValueKey('auth_email'), 'ana@exemplo.com');
    await enter(tester, const ValueKey('auth_password'), 'senha123');
    await tester.ensureVisible(submitButton('Criar minha conta'));
    await tester.tap(submitButton('Criar minha conta'));
    await flushAsync(tester);

    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('Ana Teste'), findsOneWidget);

    final local = await db.userById('id-ana@exemplo.com');
    expect(local, isNotNull);
    expect(local!.email, 'ana@exemplo.com');
  });

  testWidgets('cadastro inválido mostra erro tratado e não autentica', (tester) async {
    fake.enroll('ana@exemplo.com');
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(SegmentedButton<bool>, 'Criar conta'));
    await tester.pump();
    await enter(tester, const ValueKey('auth_name'), 'Ana');
    await enter(tester, const ValueKey('auth_email'), 'ana@exemplo.com');
    await enter(tester, const ValueKey('auth_password'), 'senha123');
    await tester.ensureVisible(submitButton('Criar minha conta'));
    await tester.tap(submitButton('Criar minha conta'));
    await settle(tester);

    expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    expect(find.byKey(const ValueKey('auth_server_error')), findsOneWidget);
    expect(find.textContaining('já cadastrado'), findsOneWidget);
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('login válido autentica e mostra a conta', (tester) async {
    fake.enroll('ana@exemplo.com');
    await pumpApp(tester);

    await enter(tester, const ValueKey('auth_email'), 'ana@exemplo.com');
    await enter(tester, const ValueKey('auth_password'), 'senha123');
    await tester.ensureVisible(submitButton('Entrar'));
    await tester.tap(submitButton('Entrar'));
    await flushAsync(tester);

    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('ana@exemplo.com'), findsOneWidget);

    final local = await db.userById('id-ana@exemplo.com');
    expect(local, isNotNull);
    expect(local!.name, 'ana');
  });

  testWidgets('login inválido mostra erro tratado e não autentica', (tester) async {
    await pumpApp(tester);

    await enter(tester, const ValueKey('auth_email'), 'nao@existe.com');
    await enter(tester, const ValueKey('auth_password'), 'errada123');
    await tester.ensureVisible(submitButton('Entrar'));
    await tester.tap(submitButton('Entrar'));
    await settle(tester);

    expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    expect(find.byKey(const ValueKey('auth_server_error')), findsOneWidget);
    expect(find.textContaining('inválidos'), findsOneWidget);
    expect(find.byType(AccountScreen), findsNothing);
  });

  testWidgets('sair da conta retorna para o login', (tester) async {
    fake.session = const AuthProfile(id: 'id-a@b.com', email: 'a@b.com');
    await pumpApp(tester);
    await flushAsync(tester);
    expect(find.byType(AccountScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account_logout')));
    await settle(tester);
    await tester.tap(find.text('Sair'));
    await flushAsync(tester);

    expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(AccountScreen), findsNothing);
  });
}