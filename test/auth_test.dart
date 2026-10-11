import 'package:drift/native.dart';
import 'package:finamind/data/auth_service.dart';
import 'package:finamind/data/database.dart';
import 'package:finamind/data/providers.dart';
import 'package:finamind/features/auth/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_service.dart';

void main() {
  late AppDatabase db;
  late FakeAuthService fake;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fake = FakeAuthService();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(() async {
      await db.close();
      container.dispose();
    });
    // Deixa a restauração de sessão terminar antes de cada caso de teste.
    container.read(authControllerProvider.notifier);
    await pumpEventQueue();
  });

  AuthController controller() => container.read(authControllerProvider.notifier);
  AuthState state() => container.read(authControllerProvider);

  group('cadastro', () {
    test('válido -> usuário autenticado e persistido localmente', () async {
      final ok = await controller().signUp(
        name: 'Ana Souza',
        email: 'ana@exemplo.com',
        password: 'senha123',
      );

      expect(ok, isTrue);
      final auth = state();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.profile?.id, 'id-ana@exemplo.com');
      expect(auth.profile?.email, 'ana@exemplo.com');

      final local = await db.userById('id-ana@exemplo.com');
      expect(local, isNotNull);
      expect(local!.name, 'Ana Souza');
      expect(local.email, 'ana@exemplo.com');
      expect(local.status, 'active');
    });

    test('inválido (e-mail já cadastrado) -> erro tratado, sem autenticar', () async {
      fake.enroll('ana@exemplo.com');

      final ok = await controller().signUp(
        name: 'Ana',
        email: 'ana@exemplo.com',
        password: 'senha123',
      );

      expect(ok, isFalse);
      final auth = state();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.error, contains('já cadastrado'));
      expect(await db.userById('id-ana@exemplo.com'), isNull);
    });

    test('e-mail ainda não confirmado -> estado de confirmação (não autentica)', () async {
      fake.confirmEmail = true;

      final ok = await controller().signUp(
        name: 'Ana',
        email: 'ana@exemplo.com',
        password: 'senha123',
      );

      expect(ok, isFalse);
      final auth = state();
      expect(auth.status, AuthStatus.needsEmailConfirmation);
      expect(auth.pendingEmail, 'ana@exemplo.com');
      expect(auth.isAuthenticated, isFalse);
    });
  });

  group('login', () {
    test('válido -> usuário autenticado e persistido localmente', () async {
      fake.enroll('ana@exemplo.com');

      final ok = await controller().signIn(email: 'ana@exemplo.com', password: 'senha123');

      expect(ok, isTrue);
      final auth = state();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.profile?.id, 'id-ana@exemplo.com');

      final local = await db.userById('id-ana@exemplo.com');
      expect(local, isNotNull);
      expect(local!.email, 'ana@exemplo.com');
      // Sem nome informado, usa a parte local do e-mail como nome padrão.
      expect(local.name, 'ana');
    });

    test('inválido -> erro tratado, usuário continua desautenticado', () async {
      final ok = await controller().signIn(email: 'nao@existe.com', password: 'errada');

      expect(ok, isFalse);
      final auth = state();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.error, contains('inválidos'));
      expect(await db.userById('id-nao@existe.com'), isNull);
    });
  });

  group('sessão', () {
    test('restaura sessão existente ao iniciar', () async {
      fake.enroll('ana@exemplo.com');
      await controller().signIn(email: 'ana@exemplo.com', password: 'senha123');
      expect(state().isAuthenticated, isTrue);

      // Simula reabrir o app: novo container com a mesma sessão remota.
      final second = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(second.dispose);
      second.read(authControllerProvider.notifier);
      await pumpEventQueue();

      final restored = second.read(authControllerProvider);
      expect(restored.isAuthenticated, isTrue);
      expect(restored.profile?.email, 'ana@exemplo.com');
    });

    test('sem sessão remota -> usuário não autenticado', () {
      expect(state().isAuthenticated, isFalse);
      expect(state().status, AuthStatus.unauthenticated);
    });

    test('logout encerra a sessão e mantém os dados locais', () async {
      fake.enroll('ana@exemplo.com');
      await controller().signIn(email: 'ana@exemplo.com', password: 'senha123');
      expect(state().isAuthenticated, isTrue);

      await controller().signOut();

      expect(state().isAuthenticated, isFalse);
      expect(state().status, AuthStatus.unauthenticated);
      expect(fake.session, isNull);
      // O perfil local permanece (offline-first).
      expect(await db.userById('id-ana@exemplo.com'), isNotNull);
    });
  });

  group('autorização de rotas', () {
    test('rota protegida /conta bloqueia usuário não autenticado', () {
      expect(
        authRedirect(auth: AuthState.unauthenticated(), location: '/conta'),
        '/entrar',
      );
    });

    test('rota protegida /conta libera usuário autenticado', () {
      final auth = AuthState.authenticated(AuthProfile(id: 'u1', email: 'a@b.com'));
      expect(authRedirect(auth: auth, location: '/conta'), isNull);
    });

    test('/entrar é bloqueado quando já está autenticado', () {
      final auth = AuthState.authenticated(AuthProfile(id: 'u1', email: 'a@b.com'));
      expect(authRedirect(auth: auth, location: '/entrar'), '/conta');
    });

    test('estados de carregamento não redirecionam (evita piscar o login)', () {
      expect(authRedirect(auth: AuthState.unknown(), location: '/conta'), isNull);
      expect(authRedirect(auth: AuthState.authenticating(), location: '/conta'), isNull);
    });
  });
}