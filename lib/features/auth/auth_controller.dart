import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_service.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Os estados possíveis da autenticação.
enum AuthStatus {
  /// Sessão ainda não verificada (ex.: inicialização do app).
  unknown,

  /// Operação de rede em andamento (login/cadastro).
  authenticating,

  /// Nenhuma conta conectada (fluxo offline padrão).
  unauthenticated,

  /// Conta conectada com sucesso.
  authenticated,

  /// Cadastro criado, mas o e-mail ainda não foi confirmado.
  needsEmailConfirmation,
}

/// Estado imutável da autenticação, consumido pelas telas e pelas rotas.
@immutable
class AuthState {
  const AuthState._({
    required this.status,
    this.profile,
    this.localUser,
    this.error,
    this.pendingEmail,
  });

  factory AuthState.unknown() =>
      AuthState._(status: AuthStatus.unknown);

  factory AuthState.authenticating() =>
      AuthState._(status: AuthStatus.authenticating);

  factory AuthState.unauthenticated([String? error]) =>
      AuthState._(status: AuthStatus.unauthenticated, error: error);

  factory AuthState.emailConfirmation(String email) =>
      AuthState._(status: AuthStatus.needsEmailConfirmation, pendingEmail: email);

  factory AuthState.authenticated(AuthProfile profile, {User? localUser}) =>
      AuthState._(status: AuthStatus.authenticated, profile: profile, localUser: localUser);

  final AuthStatus status;

  /// Identidade remota (Supabase).
  final AuthProfile? profile;

  /// Cópia local na tabela [Users] (módulo de banco de dados).
  final User? localUser;

  /// Mensagem de erro tratada (ex.: "E-mail ou senha inválidos.").
  final String? error;

  /// E-mail usado no cadastro que ainda aguarda confirmação.
  final String? pendingEmail;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  String? get displayName =>
      localUser?.name ?? profile?.name ?? profile?.email?.split('@').first;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Orquestra cadastro, login, logout e restauração de sessão.
///
/// Persiste o usuário autenticado na tabela `users` local (mesmo padrão de
/// persistência do projeto) para uso offline e para a sincronização.
class AuthController extends Notifier<AuthState> {
  AppDatabase get _db => ref.read(databaseProvider);
  AuthService get _service => ref.read(authServiceProvider);

  @override
  AuthState build() {
    _restoreSession();
    return AuthState.unknown();
  }

  /// Restaura a sessão salva pelo provedor (sem rede obrigatória).
  Future<void> _restoreSession() async {
    try {
      await _service.init();
      final profile = _service.currentUser;
      if (profile == null) {
        state = AuthState.unauthenticated();
        return;
      }
      await _saveLocalProfile(profile);
      state = AuthState.authenticated(profile, localUser: await _db.userById(profile.id));
    } catch (_) {
      state = AuthState.unauthenticated();
    }
  }

  /// Cadastra uma nova conta. Retorna `true` quando o usuário fica autenticado.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = AuthState.authenticating();
    try {
      final result = await _service.signUp(name: name, email: email, password: password);
      if (result.needsEmailConfirmation) {
        state = AuthState.emailConfirmation(email);
        return false;
      }
      final profile = result.profile;
      if (profile == null) {
        state = AuthState.unauthenticated('Não foi possível concluir o cadastro.');
        return false;
      }
      await _saveLocalProfile(profile, preferredName: name);
      state = AuthState.authenticated(profile, localUser: await _db.userById(profile.id));
      return true;
    } on AuthFailure catch (e) {
      state = AuthState.unauthenticated(e.message);
      return false;
    } catch (_) {
      state = AuthState.unauthenticated('Não foi possível concluir o cadastro.');
      return false;
    }
  }

  /// Entra com uma conta existente. Retorna `true` quando autenticado.
  Future<bool> signIn({required String email, required String password}) async {
    state = AuthState.authenticating();
    try {
      final profile = await _service.signIn(email: email, password: password);
      if (profile == null) {
        state = AuthState.unauthenticated('E-mail ou senha inválidos.');
        return false;
      }
      await _saveLocalProfile(profile);
      state = AuthState.authenticated(profile, localUser: await _db.userById(profile.id));
      return true;
    } on AuthFailure catch (e) {
      state = AuthState.unauthenticated(e.message);
      return false;
    } catch (_) {
      state = AuthState.unauthenticated('Não foi possível entrar. Tente novamente.');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _service.signOut();
    } finally {
      state = AuthState.unauthenticated();
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _service.sendPasswordReset(email);

  void clearError() {
    if (state.error != null && state.status == AuthStatus.unauthenticated) {
      state = AuthState.unauthenticated();
    }
  }

  /// Mantém a tabela de usuários local sincronizada com a identidade remota.
  Future<void> _saveLocalProfile(AuthProfile profile, {String? preferredName}) async {
    final existing = await _db.userById(profile.id);
    final typedName = preferredName?.trim() ?? '';
    final remoteName = profile.name?.trim() ?? '';
    String name;
    if (typedName.isNotEmpty) {
      name = typedName;
    } else if (existing != null && existing.name.isNotEmpty) {
      name = existing.name;
    } else if (remoteName.isNotEmpty) {
      name = remoteName;
    } else {
      name = profile.email?.split('@').first ?? 'Usuário';
    }
    await _db.upsertUser(
      UsersCompanion.insert(
        id: profile.id,
        name: name,
        email: profile.email == null ? const Value.absent() : Value(profile.email),
      ),
      id: profile.id,
    );
  }
}

/// Regras de proteção de rotas (autorização).
///
/// - `/conta` é protegida: sem sessão, redireciona para `/entrar`.
/// - `/entrar` fica bloqueada para quem já está autenticado.
/// - Estados de carregamento (`unknown`/`authenticating`) não redirecionam
///   para evitar "piscar" a tela de login durante a restauração da sessão.
String? authRedirect({required AuthState auth, required String location}) {
  if (location == '/entrar' && auth.isAuthenticated) return '/conta';
  if (location == '/conta') {
    if (auth.isAuthenticated) return null;
    if (auth.status == AuthStatus.unknown || auth.status == AuthStatus.authenticating) {
      return null;
    }
    return '/entrar';
  }
  return null;
}