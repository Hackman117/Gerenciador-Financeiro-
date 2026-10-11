import 'package:finamind/data/auth_service.dart';

/// Implementação fake do [AuthService] para testes offline.
///
/// Sem rede e sem Supabase: simula cadastro/login bem-sucedidos,
/// e-mails já registrados, credenciais inválidas e confirmação de e-mail.
class FakeAuthService implements AuthService {
  FakeAuthService({this.confirmEmail = false});

  /// Simula o provedor exigindo confirmação de e-mail após o cadastro.
  bool confirmEmail;

  /// E-mails já cadastrados no "provedor".
  final Set<String> registered = {};

  /// Sessão ativa no "provedor".
  AuthProfile? session;

  /// Senha válida para todos os e-mails cadastrados.
  String validPassword = 'senha123';

  /// Simula um e-mail previamente cadastrado (pré-condição de login).
  void enroll(String email) => registered.add(email);

  @override
  AuthProfile? get currentUser => session;

  @override
  bool get isConfigured => true;

  @override
  Future<void> init() async {}

  @override
  Future<AuthSignUpResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (registered.contains(email)) {
      throw AuthFailure('E-mail já cadastrado. Faça login.');
    }
    if (confirmEmail) {
      return const AuthSignUpResult(needsEmailConfirmation: true);
    }
    registered.add(email);
    session = AuthProfile(id: 'id-$email', email: email, name: name.trim().isEmpty ? null : name);
    return AuthSignUpResult(profile: session);
  }

  @override
  Future<AuthProfile?> signIn({
    required String email,
    required String password,
  }) async {
    if (!registered.contains(email) || password != validPassword) {
      throw AuthFailure('E-mail ou senha inválidos.');
    }
    session = AuthProfile(id: 'id-$email', email: email);
    return session;
  }

  @override
  Future<void> signOut() async {
    session = null;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}
}