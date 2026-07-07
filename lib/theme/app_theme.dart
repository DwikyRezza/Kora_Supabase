import 'package:flutter/material.dart';

class AppTheme {
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.light);

  static bool get isDarkMode => themeNotifier.value == ThemeMode.dark;

  static void toggleTheme() {
    themeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
  }

  // ---- COLORS (New Palette) ----
  static Color get background =>
      isDarkMode ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF);
  static Color get surface =>
      isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5); // Card
  static Color get surfaceVariant =>
      isDarkMode ? const Color(0xFF252525) : const Color(0xFFEDEDED); // Raised

  static Color get textPrimary =>
      isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF0D0D0D);
  static Color get textSecondary =>
      isDarkMode ? const Color(0xFFC0C0C0) : const Color(0xFF6B6B6B);
  static Color get textMuted =>
      isDarkMode ? const Color(0xFF6B6B6B) : const Color(0xFFA0A0A0);

  static Color get accent => const Color(0xFFFC5003);
  static Color get accentWash =>
      isDarkMode ? const Color(0xFF3D1800) : const Color(0xFFFFF0E9);

  static Color get border =>
      isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0);

  static Color get inputFill =>
      isDarkMode ? const Color(0xFF252525) : const Color(0xFFEDEDED);
  static Color get divider => border;

  // Keeping variables for compatibility if used elsewhere, but mapping to accent
  static Color get runningColor => accent;
  static Color get basketballColor => accent;
  static Color get weightliftingColor => accent;
  static Color get neonGreen => accent;
  static Color get electricBlue => accent;
  static Color get accentPurple => accent;
  static Color get accentOrange => accent;
  static Color get accentRed => const Color(0xFFFF4757);

  static ThemeData get theme {
    return isDarkMode ? darkTheme : lightTheme;
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      fontFamily: 'sans-serif',
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFC5003),
        secondary: Color(0xFFFC5003),
        surface: Color(0xFF1A1A1A),
        error: Color(0xFFFF4757),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFFFFFFF),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D0D0D),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A1A1A),
        selectedItemColor: Color(0xFFFC5003),
        unselectedItemColor: Color(0xFF6B6B6B),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A1A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2C2C2C), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252525),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFC5003), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFFC0C0C0)),
        hintStyle: const TextStyle(color: Color(0xFF6B6B6B)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFC5003),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: Color(0xFF2C2C2C), thickness: 1),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      fontFamily: 'sans-serif',
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFFC5003),
        secondary: Color(0xFFFC5003),
        surface: Color(0xFFF5F5F5),
        error: Color(0xFFE03140),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF0D0D0D),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF0D0D0D),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFF0D0D0D)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFF5F5F5),
        selectedItemColor: Color(0xFFFC5003),
        unselectedItemColor: Color(0xFFA0A0A0),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFF5F5F5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEDEDED),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFC5003), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF6B6B6B)),
        hintStyle: const TextStyle(color: Color(0xFFA0A0A0)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFC5003),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: Color(0xFFE0E0E0), thickness: 1),
    );
  }
}

/// Global ScrollBehavior untuk mengganti efek overscroll stretch bawaan Android 12
/// menjadi efek glow melengkung (ala Instagram) dengan warna oranye Kora.
class GlowScrollBehavior extends ScrollBehavior {
  const GlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: const Color(0xFFFC5003).withOpacity(0.3),
      child: child,
    );
  }
}
