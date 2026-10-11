import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';

/// Exibe a trava de PIN quando ativa e ainda não desbloqueada na sessão.
class PinLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const PinLockGate({super.key, required this.child});

  /// Estado de desbloqueio na sessão atual.
  static final _unlocked = StateProvider<bool>((ref) => false);

  @override
  ConsumerState<PinLockGate> createState() => _PinLockGateState();
}

class _PinLockGateState extends ConsumerState<PinLockGate> {
  @override
  Widget build(BuildContext context) {
    final pin = ref.watch(settingsProvider('app_pin')).valueOrNull ?? '';
    final unlocked = ref.watch(PinLockGate._unlocked);
    final hasPin = pin.isNotEmpty;

    if (!hasPin || unlocked) return widget.child;

    return _LockScreen(
      pin: pin,
      onSuccess: () {
        ref.read(PinLockGate._unlocked.notifier).state = true;
      },
    );
  }
}

class _LockScreen extends StatefulWidget {
  final String pin;
  final VoidCallback onSuccess;

  const _LockScreen({required this.pin, required this.onSuccess});

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final _buffer = <String>[];
  bool _shake = false;

  void _handleDigit(String digit) {
    setState(() {
      _buffer.add(digit);
    });
    if (_buffer.length < 4) return;

    final attempt = _buffer.join();
    if (attempt == widget.pin) {
      _buffer.clear();
      widget.onSuccess();
    } else {
      _buffer.clear();
      setState(() => _shake = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _shake = false);
      });
    }
  }

  void _removeDigit() {
    if (_buffer.isEmpty) return;
    setState(() => _buffer.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradientDark,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.savings_rounded, size: 46, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text('Bem-vindo de volta',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 6),
            Text('Digite seu PIN para desbloquear',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            AnimatedScale(
              scale: _shake ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 4; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _buffer.length ? scheme.primary : scheme.surfaceContainerHighest,
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            _Keypad(onDigit: _handleDigit, onBackspace: _removeDigit),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _Keypad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final row in rows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final digit in row)
                _key(context, digit, scheme),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 88),
            _key(context, '0', scheme),
            SizedBox(
              width: 88,
              child: IconButton(
                onPressed: onBackspace,
                icon: const Icon(Icons.backspace_outlined),
                iconSize: 26,
                padding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _key(BuildContext context, String digit, ColorScheme scheme) {
    return SizedBox(
      width: 88,
      child: TextButton(
        onPressed: () => onDigit(digit),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          digit,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
      ),
    );
  }
}