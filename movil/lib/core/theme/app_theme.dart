import 'package:flutter/material.dart';

/// Tokens de color semánticos que cambian según el modo (claro / oscuro).
/// Se leen con `context.nx.card`, `context.nx.muted`, etc.
@immutable
class NexoColors extends ThemeExtension<NexoColors> {
  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color text;
  final Color muted;
  final Color positive;
  final Color negative;
  final Color warning;
  final Color onAccent;

  const NexoColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.onAccent,
  });

  static const dark = NexoColors(
    background: Color(0xFF0B1320),
    surface: Color(0xFF152238),
    card: Color(0xFF1C2C47),
    border: Color(0xFF2B3F63),
    text: Color(0xFFF1F5F9),
    muted: Color(0xFF94A3B8),
    positive: Color(0xFF10B981),
    negative: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    onAccent: Colors.white,
  );

  // Valores del sistema de diseño (DESIGN.md). Verde y rojo oscurecidos para
  // cumplir contraste AA sobre fondo claro.
  static const light = NexoColors(
    background: Color(0xFFF8F9FF),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFD3E4FE),
    text: Color(0xFF0B1C30),
    muted: Color(0xFF53627A),
    positive: Color(0xFF047857),
    negative: Color(0xFFB91C1C),
    warning: Color(0xFFB45309),
    onAccent: Colors.white,
  );

  @override
  NexoColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? text,
    Color? muted,
    Color? positive,
    Color? negative,
    Color? warning,
    Color? onAccent,
  }) {
    return NexoColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      border: border ?? this.border,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      warning: warning ?? this.warning,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  NexoColors lerp(ThemeExtension<NexoColors>? other, double t) {
    if (other is! NexoColors) return this;
    return NexoColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension NexoThemeContext on BuildContext {
  NexoColors get nx => Theme.of(this).extension<NexoColors>() ?? NexoColors.dark;
}

class AppTheme {
  // Colores de marca (NexoFin AI Design System)
  static const Color emeraldPrimary = Color(0xFF005F49);
  static const Color emeraldLight = Color(0xFF10B981);
  static const Color indigoAI = Color(0xFF4E45D5);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningAmber = Color(0xFFF59E0B);

  static ThemeData get darkTheme => _build(Brightness.dark, NexoColors.dark);
  static ThemeData get lightTheme => _build(Brightness.light, NexoColors.light);

  static ThemeData _build(Brightness brightness, NexoColors c) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? emeraldLight : emeraldPrimary;
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      extensions: [c],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: indigoAI,
        onSecondary: Colors.white,
        surface: c.surface,
        onSurface: c.text,
        error: c.negative,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: c.text),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF16233B) : const Color(0xFFEFF4FF),
        labelStyle: TextStyle(color: c.muted),
        hintStyle: TextStyle(color: c.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(c.border),
        enabledBorder: border(c.border),
        focusedBorder: border(primary, 2),
        errorBorder: border(c.negative),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emeraldPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: primary,
        unselectedItemColor: c.muted,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
    );
  }
}
