import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../ui/common.dart';
import 'auth_controller.dart';

/// Tela de entrada: login e cadastro, com tratamento de erros amigável.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUpMode = false;
  String? _formError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _formError = null);

    final email = _email.text.trim();
    final password = _password.text;
    if (!_isValidEmail(email)) {
      setState(() => _formError = 'Informe um e-mail válido.');
      return;
    }
    if (password.length < 6) {
      setState(() => _formError = 'A senha precisa ter pelo menos 6 caracteres.');
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    if (_signUpMode) {
      await controller.signUp(name: _name.text.trim(), email: email, password: password);
    } else {
      await controller.signIn(email: email, password: password);
    }
    if (!mounted) return;
    if (ref.read(authControllerProvider).isAuthenticated && mounted) {
      context.go('/conta');
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _formError = 'Informe seu e-mail para recuperar a senha.');
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
      if (mounted) showAppSnack(context, 'Enviamos um link de recuperação para seu e-mail.');
    } catch (_) {
      if (mounted) showAppSnack(context, 'Não foi possível enviar a recuperação.', error: true);
    }
  }

  static bool _isValidEmail(String value) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final busy = auth.status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradientDark,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.savings_rounded, size: 38, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    auth.isAuthenticated ? 'Bem-vindo de volta' : 'FinaMind',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _signUpMode
                        ? 'Crie sua conta para sincronizar entre dispositivos.'
                        : 'Entre para sincronizar seus dados na nuvem.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Entrar')),
                      ButtonSegment(value: true, label: Text('Criar conta')),
                    ],
                    selected: {_signUpMode},
                    showSelectedIcon: false,
                    onSelectionChanged: busy
                        ? null
                        : (s) {
                            setState(() {
                              _signUpMode = s.first;
                              _formError = null;
                            });
                          },
                  ),
                  const SizedBox(height: 20),
                  if (auth.status == AuthStatus.needsEmailConfirmation)
                    Container(
                      key: const ValueKey('auth_confirm'),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Conta criada! Confirme o e-mail enviado para '
                        '${auth.pendingEmail ?? 'sua caixa de entrada'} antes de entrar.',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  if (_signUpMode) ...[
                    TextField(
                      key: const ValueKey('auth_name'),
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome (opcional)',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    key: const ValueKey('auth_email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey('auth_password'),
                    controller: _password,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: busy ? null : (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  if (_formError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        key: const ValueKey('auth_form_error'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formError!,
                          style: TextStyle(fontSize: 13, color: scheme.onErrorContainer),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: auth.error != null && !busy
                            ? Container(
                                key: const ValueKey('auth_server_error'),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  auth.error!,
                                  style: TextStyle(fontSize: 13, color: scheme.onErrorContainer),
                                ),
                              )
                            : const SizedBox(key: ValueKey('auth_no_error'), height: 0),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('auth_submit'),
                    onPressed: busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Text(_signUpMode ? 'Criar minha conta' : 'Entrar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy ? null : _resetPassword,
                    child: const Text('Esqueci minha senha'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}