import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'sync.dart';

/// Perfil mínimo do usuário autenticado, desacoplado do SDK do Supabase.
@immutable
class AuthProfile {
  const AuthProfile({required this.id, this.email, this.name});

  final String id;
  final String? email;
  final String? name;
}

/// Resultado do cadastro: pode exigir confirmação de e-mail pelo provedor.
class AuthSignUpResult {
  const AuthSignUpResult({this.needsEmailConfirmation = false, this.profile});

  final bool needsEmailConfirmation;
  final AuthProfile? profile;
}

/// Falha de autenticação com mensagem amigável para o usuário.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Contrato da camada de autenticação usada pelo [AuthController].
///
/// Mantém o padrão de segurança já existente no projeto (Supabase), mas
/// permite que o comportamento seja simulado nos testes sem rede.
abstract interface class AuthService {
  AuthProfile? get currentUser;
  bool get isConfigured;

  /// Restaura a sessão persistida, se existir.
  Future<void> init();

  Future<AuthSignUpResult> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthProfile?> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);
}

final authServiceProvider = Provider<AuthService>(
    (ref) => SupabaseAuthService(ref.watch(supabaseServiceProvider)));

/// Implementação real usando o Supabase que já está no projeto.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._service);

  final SupabaseService _service;

  @override
  bool get isConfigured => AppConfig.hasSupabase;

  @override
  AuthProfile? get currentUser {
    final user = _service.currentUser;
    if (user == null) return null;
    return AuthProfile(id: user.id, email: user.email);
  }

  @override
  Future<void> init() => _service.init();

  @override
  Future<AuthSignUpResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!isConfigured) {
      throw const AuthFailure('Sincronização não configurada neste dispositivo.');
    }
    try {
      await _service.signUp(email: email, password: password);
    } on StateError catch (e) {
      if (e.message.contains('confirme seu e-mail')) {
        return const AuthSignUpResult(needsEmailConfirmation: true);
      }
      throw AuthFailure(e.message);
    }
    final profile = currentUser;
    if (profile == null) {
      return const AuthSignUpResult(needsEmailConfirmation: true);
    }
    return AuthSignUpResult(profile: profile);
  }

  @override
  Future<AuthProfile?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) {
      throw const AuthFailure('Sincronização não configurada neste dispositivo.');
    }
    try {
      await _service.signIn(email: email, password: password);
    } on StateError catch (e) {
      throw AuthFailure(e.message);
    }
    return currentUser;
  }

  @override
  Future<void> signOut() => _service.signOut();

  @override
  Future<void> sendPasswordReset(String email) async {
    if (!isConfigured) {
      throw const AuthFailure('Sincronização não configurada neste dispositivo.');
    }
    try {
      await _service.requestPasswordReset(email);
    } on StateError catch (e) {
      throw AuthFailure(e.message);
    }
  }
}