import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/utils.dart';
import '../data/database.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: card,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: .6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CategoryAvatar extends StatelessWidget {
  final String icon;
  final int color;
  final double size;

  const CategoryAvatar({super.key, required this.icon, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final base = Color(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: base.withValues(alpha: .14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        CategoryIcons.byName(icon),
        size: size * .5,
        color: base,
      ),
    );
  }
}

class MoneyText extends StatelessWidget {
  final int cents;
  final bool signed;
  final bool income;
  final double fontSize;

  const MoneyText({super.key, required this.cents, this.signed = false, this.income = true, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = cents == 0
        ? scheme.onSurfaceVariant
        : signed
            ? (income ? incomeColor(context) : expenseColor(context))
            : scheme.onSurface;
    return Text(
      signed ? Formats.moneySigned(cents, isIncome: income) : Formats.money(cents),
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: color),
    );
  }
}

class AppRoleSelector extends StatelessWidget {
  final String type;
  final ValueChanged<String> onChanged;

  const AppRoleSelector({super.key, required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIncome = type == kIncome;
    final isTransfer = type == kTransfer;
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: kExpense, label: Text('Despesa'), icon: Icon(Icons.remove)),
        ButtonSegment(value: kIncome, label: Text('Receita'), icon: Icon(Icons.add)),
        ButtonSegment(value: kTransfer, label: Text('Transferência'), icon: Icon(Icons.swap_horiz)),
      ],
      selected: {type},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: isTransfer
            ? AppColors.transfer
            : isIncome && isTransfer == false
                ? AppColors.income
                : scheme.error,
        selectedForegroundColor: Colors.white,
      ),
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Excluir',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
}

Future<T?> showAppSheet<T>(BuildContext context, Widget child, {bool isScrollControlled = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: child,
    ),
  );
}

class MoneyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final int? maxValue;
  final EdgeInsetsGeometry margin;

  const MoneyField({
    super.key,
    required this.label,
    required this.controller,
    this.enabled = true,
    this.maxValue,
    this.margin = EdgeInsets.zero,
  });

  /// Formata "123456" em "1.234,56".
  static void format(String text, TextEditingController controller) {
    var digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      controller.clear();
      return;
    }
    digits = digits.padLeft(3, '0');
    final cents = int.parse(digits);
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');

    final buffer = StringBuffer();
    final reaisStr = reais.toString();
    for (var i = 0; i < reaisStr.length; i++) {
      final digitsRight = reaisStr.length - i;
      if (i > 0 && digitsRight % 3 == 0) buffer.write('.');
      buffer.write(reaisStr[i]);
    }
    buffer.write(',$centavos');

    final selection =
        controller.selection.isValid ? controller.selection.baseOffset - controller.text.length : 0;
    controller.text = buffer.toString();
    final target = buffer.length + selection;
    controller.selection = TextSelection.collapsed(offset: target.clamp(0, buffer.length));
  }

  /// Converte o texto de um campo monetário (ex.: "1.234,56") em centavos.
  static int centsOf(TextEditingController controller) {
    final digits = controller.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty || digits == '0') return 0;
    return int.parse(digits.padLeft(3, '0'));
  }

  int get valueInCents => centsOf(controller);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
        onChanged: (value) => format(value, controller),
        decoration: InputDecoration(labelText: label, prefixText: 'R\$ '),
      ),
    );
  }
}