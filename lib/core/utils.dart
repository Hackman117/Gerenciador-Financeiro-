import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme/app_theme.dart';

final NumberFormat _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final NumberFormat _percent = NumberFormat.percentPattern('pt_BR');
final DateFormat _dayMonth = DateFormat('dd/MM/yyyy');
final DateFormat _dayMonthShort = DateFormat('dd MMM', 'pt_BR');
final DateFormat _full = DateFormat("d 'de' MMMM 'de' y", 'pt_BR');
final DateFormat _monthYear = DateFormat('MMMM yyyy', 'pt_BR');
final DateFormat _time = DateFormat('HH:mm');

abstract final class Formats {
  static String money(int cents) => _currency.format(cents / 100);

  static String moneySigned(int cents, {required bool isIncome}) =>
      '${isIncome ? '+' : '-'}${_currency.format(cents / 100)}';

  static String compactMoney(int cents) {
    final value = cents / 100;
    if (value.abs() >= 1000000) return 'R\$ ${(value / 1000000).toStringAsFixed(1)}M';
    if (value.abs() >= 1000) return 'R\$ ${(value / 1000).toStringAsFixed(1)}k';
    return _currency.format(value);
  }

  static String percent(double value) => _percent.format(value);

  static String date(DateTime d) => _dayMonth.format(d);

  static String shortDate(DateTime d) => _dayMonthShort.format(d);

  static String fullDate(DateTime d) => _full.format(d);

  static String monthYear(DateTime d) {
    final text = _monthYear.format(d);
    return text[0].toUpperCase() + text.substring(1);
  }

  static String time(DateTime d) => _time.format(d);

  static String monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static DateTime monthKeyToDate(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  static String dateGroupLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    if (diff > 1 && diff < 7) return 'Esta semana';
    return fullDate(d);
  }
}

abstract final class CategoryIcons {
  static const Map<String, IconData> all = {
    'restaurant': Icons.restaurant_rounded,
    'groceries': Icons.local_grocery_store_rounded,
    'transport': Icons.directions_car_rounded,
    'home': Icons.home_rounded,
    'health': Icons.favorite_rounded,
    'education': Icons.school_rounded,
    'fun': Icons.sports_esports_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'salary': Icons.payments_rounded,
    'freelance': Icons.laptop_mac_rounded,
    'investment': Icons.trending_up_rounded,
    'gift': Icons.card_giftcard_rounded,
    'travel': Icons.flight_rounded,
    'pets': Icons.pets_rounded,
    'childcare': Icons.child_care_rounded,
    'bills': Icons.receipt_long_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'sports': Icons.fitness_center_rounded,
    'beauty': Icons.spa_rounded,
    'crypto': Icons.currency_bitcoin_rounded,
    'other': Icons.category_rounded,
    'savings': Icons.savings_rounded,
    'tax': Icons.account_balance_rounded,
    'cash': Icons.wallet_rounded,
  };

  static IconData byName(String name) => all[name] ?? Icons.category_rounded;

  static List<String> get names => all.keys.toList();
}

abstract final class AccountIcons {
  static IconData byType(String type) => switch (type) {
        'cash' => Icons.payments_rounded,
        'savings' => Icons.savings_rounded,
        'credit' => Icons.credit_card_rounded,
        'investment' => Icons.trending_up_rounded,
        'wallet' => Icons.account_balance_wallet_rounded,
        'digital' => Icons.smartphone_rounded,
        _ => Icons.account_balance_rounded,
      };
}

Color expenseColor(BuildContext context) => Theme.of(context).colorScheme.error;
Color incomeColor(BuildContext context) => AppColors.income;
