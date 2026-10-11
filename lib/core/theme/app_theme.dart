import 'package:flutter/material.dart';

abstract final class AppColors {
  // Marca
  static const Color seed = Color(0xFF0E9F6E);
  static const Color primary = Color(0xFF0E9F6E);
  static const Color primaryStrong = Color(0xFF0B7E58);

  // Semânticas (funcionam nos 2 temas)
  static const Color income = Color(0xFF12B76A);
  static const Color expense = Color(0xFFF04438);
  static const Color transfer = Color(0xFF3E7BFA);
  static const Color warning = Color(0xFFF79009);
  static const Color info = Color(0xFF0BA5EC);

  // Superfícies (dark mode em camadas)
  static const Color darkBg = Color(0xFF0C1116);
  static const Color darkSurface = Color(0xFF141B22);
  static const Color darkSurfaceHigh = Color(0xFF1C252E);

  // Light mode
  static const Color lightBg = Color(0xFFF4F6F5);
  static const Color lightSurface = Colors.white;

  // Paleta para gráficos/categorias (distribuída e harmônica)
  static const List<Color> palette = [
    Color(0xFF0E9F6E),
    Color(0xFF3E7BFA),
    Color(0xFF9B5CF6),
    Color(0xFFF04438),
    Color(0xFFF79009),
    Color(0xFF12B76A),
    Color(0xFF0BA5EC),
    Color(0xFFA3E635),
    Color(0xFFF05176),
    Color(0xFF4F46E5),
    Color(0xFF17A2B8),
    Color(0xFFC026D3),
    Color(0xFF84CC16),
    Color(0xFFFB7185),
    Color(0xFF64748B),
  ];

  static const List<int> accountColors = [
    0xFF0E9F6E,
    0xFF3E7BFA,
    0xFF9B5CF6,
    0xFFF79009,
    0xFFF04438,
    0xFF0BA5EC,
    0xFF4F46E5,
    0xFFC026D3,
  ];

  static const List<int> categoryColors = [
    0xFF0E9F6E,
    0xFF3E7BFA,
    0xFF9B5CF6,
    0xFFF79009,
    0xFFF04438,
    0xFF0BA5EC,
    0xFF12B76A,
    0xFFFB7185,
    0xFF84CC16,
    0xFF4F46E5,
    0xFF17A2B8,
    0xFFC026D3,
    0xFF64748B,
  ];

  // Gradiente do card principal do dashboard
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0BC084), Color(0xFF0E9F6E), Color(0xFF086E4F)],
  );

  static const LinearGradient heroGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14B57E), Color(0xFF0E9F6E), Color(0xFF075E44)],
  );
}

abstract final class AppTheme {
  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
      surface: isDark ? AppColors.darkBg : AppColors.lightBg,
    );

    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceHigh = isDark ? AppColors.darkSurfaceHigh : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: .07) : Colors.black.withValues(alpha: .06);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurface),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: border),
        backgroundColor: surfaceHigh,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surfaceHigh,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        backgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: scheme.surfaceContainerHighest,
        color: scheme.primary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}