import 'package:finamind/core/utils.dart';
import 'package:finamind/data/database.dart';
import 'package:finamind/ui/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// O intl em pt_BR separa o símbolo do número com espaço não quebrável (U+00A0).
String brl(String number) => 'R\$\u{A0}$number';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDateFormatting);

  group('dinheiro é sempre centavo (int)', () {
    test('money formata centavos como reais', () {
      expect(Formats.money(0), brl('0,00'));
      expect(Formats.money(5), brl('0,05'));
      expect(Formats.money(123456), brl('1.234,56'));
      expect(Formats.money(-123456), '-${brl('1.234,56')}');
    });

    test('moneySigned marca receita e despesa', () {
      expect(Formats.moneySigned(1000, isIncome: true), '+${brl('10,00')}');
      expect(Formats.moneySigned(1000, isIncome: false), '-${brl('10,00')}');
    });

    test('compactMoney abrevia mil e milhões', () {
      expect(Formats.compactMoney(1500000000), 'R\$ 15.0M');
      expect(Formats.compactMoney(150000), 'R\$ 1.5k');
      expect(Formats.compactMoney(9900), brl('99,00'));
    });

    test('percent formata a fração como porcentagem', () {
      expect(Formats.percent(0.4), '40%');
    });
  });

  group('MoneyField', () {
    test('format e centsOf são inversos', () {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      MoneyField.format('123456', controller);
      expect(controller.text, '1.234,56');
      expect(MoneyField.centsOf(controller), 123456);
    });

    test('o separador de milhar cai a cada três dígitos', () {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      MoneyField.format('99999', controller);
      expect(controller.text, '999,99');

      MoneyField.format('100000', controller);
      expect(controller.text, '1.000,00');

      MoneyField.format('1234567890', controller);
      expect(controller.text, '12.345.678,90');
    });

    test('os dígitos digitados são centavos, então o campo começa em R\$ 0,05', () {
      final controller = TextEditingController(text: '5');
      addTearDown(controller.dispose);
      expect(MoneyField.centsOf(controller), 5);
      expect(Formats.money(MoneyField.centsOf(controller)), brl('0,05'));
    });

    test('campo vazio ou zerado vale zero', () {
      for (final text in ['', '0', '00', ',']) {
        final controller = TextEditingController(text: text);
        addTearDown(controller.dispose);
        expect(MoneyField.centsOf(controller), 0, reason: 'texto: "$text"');
      }
    });

    test('format sem dígitos limpa o campo', () {
      final controller = TextEditingController(text: '1,23');
      addTearDown(controller.dispose);
      MoneyField.format('abc', controller);
      expect(controller.text, isEmpty);
    });
  });

  group('AppDatabase.splitAmount', () {
    test('a soma das parcelas é exatamente o total', () {
      for (final count in [1, 2, 3, 7, 12]) {
        final parts = AppDatabase.splitAmount(10000, count);
        expect(parts.length, count);
        expect(parts.fold<int>(0, (sum, p) => sum + p), 10000);
      }
    });

    test('o resto sobra nas primeiras parcelas', () {
      expect(AppDatabase.splitAmount(100, 3), [34, 33, 33]);
      expect(AppDatabase.splitAmount(10, 4), [3, 3, 2, 2]);
      expect(AppDatabase.splitAmount(120000, 1), [120000]);
    });
  });

  group('datas', () {
    test('endOfDay fecha o dia, para filtros com date <= fim', () {
      final end = endOfDay(DateTime(2026, 10, 31));
      expect(end.day, 31);
      expect(end.hour, 23);
      expect(end.isBefore(DateTime(2026, 11, 1)), isTrue);
    });

    test('monthKey e monthKeyToDate conversam', () {
      expect(Formats.monthKey(DateTime(2026, 1, 5)), '2026-01');
      expect(Formats.monthKeyToDate('2026-01'), DateTime(2026, 1));
    });

    test('dateGroupLabel agrupa por proximidade', () {
      final now = DateTime.now();
      expect(Formats.dateGroupLabel(now), 'Hoje');
      expect(Formats.dateGroupLabel(now.subtract(const Duration(days: 1))), 'Ontem');
      expect(Formats.dateGroupLabel(now.subtract(const Duration(days: 3))), 'Esta semana');

      final antiga = now.subtract(const Duration(days: 30));
      expect(Formats.dateGroupLabel(antiga), Formats.fullDate(antiga));
    });

    test('nomes de mês em português', () {
      expect(Formats.monthYear(DateTime(2026, 10, 11)), 'Outubro 2026');
      expect(Formats.fullDate(DateTime(2026, 10, 11)), '11 de outubro de 2026');
      expect(Formats.date(DateTime(2026, 10, 11)), '11/10/2026');
    });
  });

  group('ícones', () {
    test('têm fallback para nome e tipo desconhecidos', () {
      expect(CategoryIcons.byName('salary'), Icons.payments_rounded);
      expect(CategoryIcons.byName('nao_existe'), Icons.category_rounded);
      expect(AccountIcons.byType('credit'), Icons.credit_card_rounded);
      expect(AccountIcons.byType('desconhecido'), Icons.account_balance_rounded);
    });
  });
}
