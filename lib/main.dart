import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Os formatos de data em pt_BR (dd/MM, 'Outubro 2026') aparecem ja no primeiro
  /// frame do panorama; sem carregar os simbolos o DateFormat lanca no boot.
  await initializeDateFormatting('pt_BR');

  final db = AppDatabase();
  await db.ensureDefaultAccount();

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const FinaMindApp(),
    ),
  );
}