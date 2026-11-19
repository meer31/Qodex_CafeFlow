import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemePalette {
  final String key;
  final String name;
  final String subtitle;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color cardBg;
  final Color accent;
  final Color error;
  final Color warning;
  final Color info;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color sidebarBg;
  final Color sidebarActive;
  final Color statusAvailable;
  final Color statusOccupied;
  final Color statusReserved;
  final Color statusCleaning;

  const ThemePalette({
    required this.key,
    required this.name,
    required this.subtitle,
    this.isDark = false,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.cardBg,
    required this.accent,
    this.error = const Color(0xFFEF4444),
    this.warning = const Color(0xFFF59E0B),
    required this.info,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.sidebarBg,
    required this.sidebarActive,
    this.statusAvailable = const Color(0xFF10B981),
    this.statusOccupied = const Color(0xFFEF4444),
    this.statusReserved = const Color(0xFFF59E0B),
    this.statusCleaning = const Color(0xFF3B82F6),
  });
}

class AppColors {
  static Color get primary => AppTheme.currentPalette.primary;
  static Color get secondary => AppTheme.currentPalette.secondary;
  static Color get background => AppTheme.currentPalette.background;
  static Color get cardBg => AppTheme.currentPalette.cardBg;
  static Color get accent => AppTheme.currentPalette.accent;
  static Color get error => AppTheme.currentPalette.error;
  static Color get warning => AppTheme.currentPalette.warning;
  static Color get info => AppTheme.currentPalette.info;

  static Color get textPrimary => AppTheme.currentPalette.textPrimary;
  static Color get textSecondary => AppTheme.currentPalette.textSecondary;
  static Color get textMuted => AppTheme.currentPalette.textMuted;
  static Color get border => AppTheme.currentPalette.border;

  static Color get sidebarBg => AppTheme.currentPalette.sidebarBg;
  static Color get sidebarActive => AppTheme.currentPalette.sidebarActive;

  // Table Status Colors
  static Color get statusAvailable => AppTheme.currentPalette.statusAvailable;
  static Color get statusOccupied => AppTheme.currentPalette.statusOccupied;
  static Color get statusReserved => AppTheme.currentPalette.statusReserved;
  static Color get statusCleaning => AppTheme.currentPalette.statusCleaning;
}

class AppTheme {
  static const double borderRadius = 12.0;

  static const String themeClassicBlue = 'classic_blue';
  static const String themeWarmAmber = 'warm_amber';
  static const String themeMidnightDark = 'midnight_dark';
  static const String themeCharcoalRoast = 'charcoal_roast';
  static const String themeCrimsonBistro = 'crimson_bistro';

  static const ThemePalette classicBlue = ThemePalette(
    key: themeClassicBlue,
    name: 'Classic Sapphire (Light)',
    subtitle: 'Crisp corporate royal blue with clean white workspace',
    isDark: false,
    primary: Color(0xFF2563EB),
    secondary: Color(0xFF1E293B),
    background: Color(0xFFF8FAFC),
    cardBg: Colors.white,
    accent: Color(0xFF10B981),
    error: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF3B82F6),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    sidebarBg: Color(0xFF0F172A),
    sidebarActive: Color(0xFF1E293B),
  );

  static const ThemePalette warmAmber = ThemePalette(
    key: themeWarmAmber,
    name: 'Warm Amber / Espresso (Light)',
    subtitle: 'Rich roasted caramel, golden bronze & deep espresso tones',
    isDark: false,
    primary: Color(0xFFD97706),
    secondary: Color(0xFF292524),
    background: Color(0xFFFAF7F2),
    cardBg: Colors.white,
    accent: Color(0xFF059669),
    error: Color(0xFFDC2626),
    warning: Color(0xFFF59E0B),
    info: Color(0xFFD97706),
    textPrimary: Color(0xFF1C1917),
    textSecondary: Color(0xFF78716C),
    textMuted: Color(0xFFA8A29E),
    border: Color(0xFFE7E5E4),
    sidebarBg: Color(0xFF1C1917),
    sidebarActive: Color(0xFF292524),
  );

  static const ThemePalette midnightDark = ThemePalette(
    key: themeMidnightDark,
    name: 'Midnight Gold & White (Dark)',
    subtitle: 'Slightly dark black with warm golden yellow accents & crisp white typography',
    isDark: true,
    primary: Color(0xFFE5A910),
    secondary: Color(0xFFF3F4F6),
    background: Color(0xFF141416),
    cardBg: Color(0xFF202227),
    accent: Color(0xFFD49704),
    error: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    info: Color(0xFFE5A910),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD8DADC),
    textMuted: Color(0xFF9CA3AF),
    border: Color(0xFF2E3138),
    sidebarBg: Color(0xFF0F1012),
    sidebarActive: Color(0xFF262830),
  );

  static const ThemePalette charcoalRoast = ThemePalette(
    key: themeCharcoalRoast,
    name: 'Charcoal Roast & Honey (Dark)',
    subtitle: 'Deep espresso roast charcoal with warm caramel honey & toasted bronze glow',
    isDark: true,
    primary: Color(0xFFF59E0B),
    secondary: Color(0xFFFDE68A),
    background: Color(0xFF120E0C),
    cardBg: Color(0xFF1F1814),
    accent: Color(0xFF10B981),
    error: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    info: Color(0xFFF59E0B),
    textPrimary: Color(0xFFFFF8F0),
    textSecondary: Color(0xFFD4C3B5),
    textMuted: Color(0xFF9E8878),
    border: Color(0xFF3A2B23),
    sidebarBg: Color(0xFF0C0908),
    sidebarActive: Color(0xFF291E18),
  );

  static const ThemePalette crimsonBistro = ThemePalette(
    key: themeCrimsonBistro,
    name: 'Crimson Bistro & Grill (Dark)',
    subtitle: 'Fine-dining dark mahogany & wine obsidian with vibrant ruby crimson accents',
    isDark: true,
    primary: Color(0xFFF43F5E),
    secondary: Color(0xFFFECDD3),
    background: Color(0xFF140A0E),
    cardBg: Color(0xFF231118),
    accent: Color(0xFFFB923C),
    error: Color(0xFFF43F5E),
    warning: Color(0xFFFBBF24),
    info: Color(0xFFF43F5E),
    textPrimary: Color(0xFFFFF1F2),
    textSecondary: Color(0xFFE2B7C1),
    textMuted: Color(0xFF9E6E7C),
    border: Color(0xFF3E1D28),
    sidebarBg: Color(0xFF0E0609),
    sidebarActive: Color(0xFF2B1019),
  );

  static const List<ThemePalette> availableThemes = [
    classicBlue,
    warmAmber,
    midnightDark,
    charcoalRoast,
    crimsonBistro,
  ];

  static ThemePalette currentPalette = classicBlue;

  static void setPalette(String key) {
    switch (key) {
      case themeWarmAmber:
        currentPalette = warmAmber;
        break;
      case themeMidnightDark:
        currentPalette = midnightDark;
        break;
      case themeCharcoalRoast:
        currentPalette = charcoalRoast;
        break;
      case themeCrimsonBistro:
        currentPalette = crimsonBistro;
        break;
      case themeClassicBlue:
      default:
        currentPalette = classicBlue;
        break;
    }
  }

  static ThemeData get lightTheme => getThemeData(currentPalette.key);

  static ThemeData getThemeData(String themeKey) {
    setPalette(themeKey);
    final palette = currentPalette;
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: palette.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: palette.background,
      primaryColor: palette.primary,
      cardColor: palette.cardBg,
      canvasColor: palette.cardBg,
      colorScheme: ColorScheme(
        brightness: palette.isDark ? Brightness.dark : Brightness.light,
        primary: palette.primary,
        onPrimary: palette.isDark ? const Color(0xFF0F172A) : Colors.white,
        secondary: palette.secondary,
        onSecondary: Colors.white,
        surface: palette.cardBg,
        onSurface: palette.textPrimary,
        error: palette.error,
        onError: Colors.white,
        tertiary: palette.accent,
      ),
      textTheme: baseTextTheme.copyWith(
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: palette.textPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: palette.textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: palette.border, width: 1),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: palette.textPrimary,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: palette.textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.cardBg,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.cardBg,
        surfaceTintColor: Colors.transparent,
        textStyle: GoogleFonts.inter(color: palette.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: palette.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.isDark ? const Color(0xFF0F172A) : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.isDark ? palette.cardBg : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: palette.primary, width: 2),
        ),
        hintStyle: TextStyle(color: palette.textMuted),
        labelStyle: TextStyle(color: palette.textSecondary),
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: palette.textPrimary,
          fontSize: 13,
        ),
        dataTextStyle: GoogleFonts.inter(
          color: palette.textPrimary,
          fontSize: 13,
        ),
        headingRowColor: WidgetStateProperty.all(palette.cardBg),
        dataRowColor: WidgetStateProperty.all(palette.cardBg),
        dividerThickness: 1,
        decoration: BoxDecoration(
          color: palette.cardBg,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.isDark ? palette.cardBg : const Color(0xFFF1F5F9),
        disabledColor: palette.border,
        selectedColor: palette.primary,
        secondarySelectedColor: palette.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 12,
        ),
        secondaryLabelStyle: TextStyle(
          color: palette.isDark ? const Color(0xFF0F172A) : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
