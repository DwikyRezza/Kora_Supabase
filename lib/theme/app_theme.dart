import 'package:flutter/material.dart';

class AppTheme {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  static bool get isDarkMode => themeNotifier.value == ThemeMode.dark;

  static void toggleTheme() {
    themeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
  }

  // ---- COLORS ----
  static Color get background => isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFF7F9FC);
  static Color get surface => isDarkMode ? const Color(0xFF131929) : const Color(0xFFFFFFFF);
  static Color get surfaceVariant => isDarkMode ? const Color(0xFF1C2438) : const Color(0xFFE2E8F0);
  static Color get cardBg => isDarkMode ? const Color(0xFF1A2035) : const Color(0xFFFFFFFF);

  static Color get neonGreen => isDarkMode ? const Color(0xFF39FF8F) : const Color(0xFF00B359);
  static Color get electricBlue => isDarkMode ? const Color(0xFF00D4FF) : const Color(0xFF0088CC);
  static Color get accentPurple => isDarkMode ? const Color(0xFF7B61FF) : const Color(0xFF6A4CFF);
  static Color get accentOrange => isDarkMode ? const Color(0xFFFF6B35) : const Color(0xFFE65A2A);
  static Color get accentRed => isDarkMode ? const Color(0xFFFF4757) : const Color(0xFFE03140);

  static Color get textPrimary => isDarkMode ? const Color(0xFFEEF2FF) : const Color(0xFF1A202C);
  static Color get textSecondary => isDarkMode ? const Color(0xFF8892A4) : const Color(0xFF4A5568);
  static Color get textMuted => isDarkMode ? const Color(0xFF4A5568) : const Color(0xFF718096);

  static Color get border => isDarkMode ? const Color(0xFF2D3748) : const Color(0xFFCBD5E0);

  // Workout Colors
  static Color get runningColor => electricBlue;
  static Color get basketballColor => accentOrange;
  static Color get weightliftingColor => accentPurple;

  // ---- GRADIENTS ----
  static LinearGradient get neonGreenGrad => LinearGradient(
    colors: isDarkMode 
      ? [const Color(0xFF39FF8F), const Color(0xFF00CC6A)]
      : [const Color(0xFF00B359), const Color(0xFF008C4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get electricBlueGrad => LinearGradient(
    colors: isDarkMode
      ? [const Color(0xFF00D4FF), const Color(0xFF0099CC)]
      : [const Color(0xFF0088CC), const Color(0xFF006699)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get purpleGrad => LinearGradient(
    colors: isDarkMode
      ? [const Color(0xFF7B61FF), const Color(0xFF5542CC)]
      : [const Color(0xFF6A4CFF), const Color(0xFF4B34B3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get orangeGrad => LinearGradient(
    colors: isDarkMode
      ? [const Color(0xFFFF6B35), const Color(0xFFCC4422)]
      : [const Color(0xFFE65A2A), const Color(0xFFB33E18)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get theme {
    return isDarkMode ? _darkTheme : _lightTheme;
  }

  static ThemeData get _darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0E1A),
      fontFamily: 'sans-serif',
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF39FF8F),
        secondary: Color(0xFF00D4FF),
        surface: Color(0xFF131929),
        error: Color(0xFFFF4757),
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Color(0xFFEEF2FF),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0E1A),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFFEEF2FF),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFFEEF2FF)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF131929),
        selectedItemColor: Color(0xFF39FF8F),
        unselectedItemColor: Color(0xFF4A5568),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A2035),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF2D3748), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C2438),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D3748)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D3748)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF39FF8F), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF8892A4)),
        hintStyle: const TextStyle(color: Color(0xFF4A5568)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF39FF8F),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2D3748), thickness: 1),
    );
  }

  static ThemeData get _lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      fontFamily: 'sans-serif',
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF00B359),
        secondary: Color(0xFF0088CC),
        surface: Color(0xFFFFFFFF),
        error: Color(0xFFE03140),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1A202C),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7F9FC),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF1A202C),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1A202C)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: Color(0xFF00B359),
        unselectedItemColor: Color(0xFF718096),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFCBD5E0), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFE2E8F0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00B359), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF4A5568)),
        hintStyle: const TextStyle(color: Color(0xFF718096)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00B359),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFCBD5E0), thickness: 1),
    );
  }
}
