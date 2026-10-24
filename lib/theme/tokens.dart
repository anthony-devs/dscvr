import 'package:flutter/material.dart';

/// Design tokens for DSCVR.
///
/// The look is a cool, modern research studio: clean slate-grey backgrounds,
/// a serif display face for titles, quiet sans-serif UI text, and jewel-toned
/// pastel material cards. Every colour used by the UI lives here so light and
/// dark mode stay in lock-step.
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

  // Cool-paper palette: modern slate-tinged whites, distinct from UNMS's
  // warm cream. Still inviting but reads as its own product.
  static const light = DscvrColors(
    background: Color(0xFFF3F4F6),   // cool dove grey
    backgroundTint: Color(0xFFECEDF2), // subtle lilac tint
    surface: Color(0xFFFCFCFD),       // near-white with cool cast
    surfaceMuted: Color(0xFFE8E9EE),  // muted lavender-grey
    chip: Color(0xFFDCDDE4),          // soft steel
    selection: Color(0xFFE2E4ED),     // pale periwinkle
    line: Color(0xFFD4D6DF),          // cool divider
    ink: Color(0xFF1D1F2B),           // deep navy-charcoal
    inkMuted: Color(0xFF5C5F72),      // slate prose
    inkFaint: Color(0xFF9295A4),      // quiet grey
    inverseInk: Color(0xFFFCFCFD),
    danger: Color(0xFFC4392C),        // warm red
    success: Color(0xFF2D7D46),
    isDark: false,
  );

  static const dark = DscvrColors(
    background: Color(0xFF131418),    // deep space
    backgroundTint: Color(0xFF18191F),
    surface: Color(0xFF1E1F26),       // raised charcoal-blue
    surfaceMuted: Color(0xFF272830),
    chip: Color(0xFF30323C),
    selection: Color(0xFF2A2C36),
    line: Color(0xFF363845),
    ink: Color(0xFFEBECF2),           // cool off-white
    inkMuted: Color(0xFFA4A7B8),
    inkFaint: Color(0xFF6E7188),
    inverseInk: Color(0xFF131418),
    danger: Color(0xFFE8786A),
    success: Color(0xFF6FC07E),
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
    Color(0xFF6C5CE7), // iris
    Color(0xFFE67E22), // tangerine
    Color(0xFF2E86DE), // cerulean
    Color(0xFF6AB04C), // fern
    Color(0xFFEB4D4B), // coral
    Color(0xFF00B894), // jade
    Color(0xFFE84393), // magenta
    Color(0xFF846B5B), // walnut
    Color(0xFF4A69BD), // sapphire
    Color(0xFFD4A017), // amber
    Color(0xFF2C8E4E), // emerald
    Color(0xFF8395A7), // pewter
  ];

  static Color of(int index) => colors[index.abs() % colors.length];
}

/// Pastel fills for material cards, matched to a stronger border tone.
class CardPalette {
  CardPalette._();

  static const _fills = <Color>[
    Color(0xFFD0E4ED), // glacier
    Color(0xFFDAD0F4), // wisteria
    Color(0xFFCEE8D2), // spearmint
    Color(0xFFF2CEDF), // peony
    Color(0xFFE8DDD0), // linen
    Color(0xFFC9DBF3), // cornflower
    Color(0xFFEBD2C4), // terracotta
    Color(0xFFD8D9E4), // moonstone
    Color(0xFFF0DABC), // honeycomb
    Color(0xFFC8E4E2), // seafoam
  ];

  static const _borders = <Color>[
    Color(0xFFABCBDC),
    Color(0xFFBDB0EA),
    Color(0xFFADD4B3),
    Color(0xFFE5A9C8),
    Color(0xFFD1BDA8),
    Color(0xFFA3BFE5),
    Color(0xFFD8B3A0),
    Color(0xFFBFC0CE),
    Color(0xFFE0BE92),
    Color(0xFFA2CDC9),
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
