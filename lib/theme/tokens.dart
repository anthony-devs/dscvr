import 'package:flutter/material.dart';

/// Design tokens for DSCVR.
///
/// The look is a warm, paper-like research desk: soft cream backgrounds,
/// a serif display face for titles, quiet sans-serif UI text, and pastel
/// material cards. Every colour used by the UI lives here so light and dark
/// mode stay in lock-step.
@immutable
class DscvrColors extends ThemeExtension<DscvrColors> {
  const DscvrColors({
    required this.background,
    required this.backgroundTint,
    required this.surface,
    required this.surfaceMuted,
    required this.chip,
    required this.selection,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.inverseInk,
    required this.danger,
    required this.success,
    required this.isDark,
  });

  final Color background;
  final Color backgroundTint;
  final Color surface;
  final Color surfaceMuted;
  final Color chip;
  final Color selection;
  final Color line;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color inverseInk;
  final Color danger;
  final Color success;
  final bool isDark;

  static const light = DscvrColors(
    background: Color(0xFFF8F3ED),
    backgroundTint: Color(0xFFF5EAE6),
    surface: Color(0xFFFFFCF8),
    surfaceMuted: Color(0xFFF1E9E0),
    chip: Color(0xFFE9DDD1),
    selection: Color(0xFFEDE3D8),
    line: Color(0xFFE5D9CD),
    ink: Color(0xFF2A2420),
    inkMuted: Color(0xFF6B625A),
    inkFaint: Color(0xFF9C9289),
    inverseInk: Color(0xFFFFFCF8),
    danger: Color(0xFFB3412E),
    success: Color(0xFF3E7D46),
    isDark: false,
  );

  static const dark = DscvrColors(
    background: Color(0xFF171513),
    backgroundTint: Color(0xFF1C1816),
    surface: Color(0xFF211E1B),
    surfaceMuted: Color(0xFF2A2623),
    chip: Color(0xFF332E2A),
    selection: Color(0xFF2E2925),
    line: Color(0xFF39332E),
    ink: Color(0xFFF1EBE4),
    inkMuted: Color(0xFFB0A69C),
    inkFaint: Color(0xFF7C7269),
    inverseInk: Color(0xFF171513),
    danger: Color(0xFFE07A66),
    success: Color(0xFF7DBE84),
    isDark: true,
  );

  @override
  DscvrColors copyWith() => this;

  @override
  DscvrColors lerp(ThemeExtension<DscvrColors>? other, double t) {
    if (other is! DscvrColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return DscvrColors(
      background: l(background, other.background),
      backgroundTint: l(backgroundTint, other.backgroundTint),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      chip: l(chip, other.chip),
      selection: l(selection, other.selection),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      inkFaint: l(inkFaint, other.inkFaint),
      inverseInk: l(inverseInk, other.inverseInk),
      danger: l(danger, other.danger),
      success: l(success, other.success),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Saturated colours used for category dots in the sidebar.
class CategoryPalette {
  CategoryPalette._();

  static const colors = <Color>[
    Color(0xFF8E44D9), // violet
    Color(0xFFF08A24), // orange
    Color(0xFF3B6FE0), // blue
    Color(0xFF8DBA2E), // lime
    Color(0xFFE0533D), // vermilion
    Color(0xFF2DA79A), // teal
    Color(0xFFD9417F), // rose
    Color(0xFF6D4C3D), // umber
    Color(0xFF5A6ACF), // indigo
    Color(0xFFC9A227), // mustard
    Color(0xFF3E8E41), // green
    Color(0xFF9B8F86), // stone
  ];

  static Color of(int index) => colors[index.abs() % colors.length];
}

/// Pastel fills for material cards, matched to a stronger border tone.
class CardPalette {
  CardPalette._();

  static const _fills = <Color>[
    Color(0xFFD5E8C8), // sage
    Color(0xFFD7C6F2), // lavender
    Color(0xFFE9EBBE), // pistachio
    Color(0xFFF0C9DC), // blush
    Color(0xFFE4D3C3), // oat
    Color(0xFFCADFF2), // sky
    Color(0xFFE3C2BB), // clay
    Color(0xFFDEDCD8), // fog
    Color(0xFFF3D6BC), // apricot
    Color(0xFFC5E8DF), // mint
  ];

  static const _borders = <Color>[
    Color(0xFFB4D19F),
    Color(0xFFBCA2E6),
    Color(0xFFD2D594),
    Color(0xFFE2A6C4),
    Color(0xFFCDB49B),
    Color(0xFFA6C5E3),
    Color(0xFFCF9F94),
    Color(0xFFC6C2BC),
    Color(0xFFE3B88F),
    Color(0xFF9FD0C2),
  ];

  static int get length => _fills.length;

  static Color fill(int index, DscvrColors c) {
    final base = _fills[index.abs() % _fills.length];
    return c.isDark ? Color.lerp(c.surface, base, 0.27)! : base;
  }

  static Color border(int index, DscvrColors c) {
    final base = _borders[index.abs() % _borders.length];
    return c.isDark ? Color.lerp(c.surface, base, 0.48)! : base;
  }

  /// Small badge background inside a card (the year pill).
  static Color badge(DscvrColors c) =>
      c.isDark ? const Color(0x33FFFFFF) : const Color(0xB3FFFFFF);
}

class Space {
  Space._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class Radii {
  Radii._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;
}

class Breakpoints {
  Breakpoints._();

  /// Below this width we use the phone layout (drawer + bottom bar).
  static const double compact = 720;

  /// At or above this width the reader shows Pinda side by side.
  static const double wide = 1100;
}

extension DscvrThemeX on BuildContext {
  DscvrColors get colors => Theme.of(this).extension<DscvrColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isCompact => MediaQuery.sizeOf(this).width < Breakpoints.compact;
  bool get isWide => MediaQuery.sizeOf(this).width >= Breakpoints.wide;
}
