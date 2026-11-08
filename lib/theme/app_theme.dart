import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds the light and dark [ThemeData] from [DscvrColors].
///
/// Type pairing: Source Serif 4 for display and titles (the academic,
/// paper-like voice) and Inter for interface text.
class AppTheme {
  AppTheme._();

  static ThemeData light({bool highContrast = false, bool reduceMotion = false}) =>
      _build(highContrast ? DscvrColors.lightHighContrast : DscvrColors.light, Brightness.light, reduceMotion);
  static ThemeData dark({bool highContrast = false, bool reduceMotion = false}) =>
      _build(highContrast ? DscvrColors.darkHighContrast : DscvrColors.dark, Brightness.dark, reduceMotion);

  /// Reading font chosen in Settings > Accessibility. Set by the app root
  /// before building, so every text style picks it up.
  static String fontChoice = 'standard';

  /// Extra line spacing for body text (paragraphs set height >= 1.4).
  static double lineScale = 1.0;

  static double? _h(double? height) => height != null && height >= 1.4 ? height * lineScale : height;

  static TextStyle _accessible({double? fontSize, FontWeight? fontWeight, Color? color, double? height,
          double? letterSpacing, FontStyle? fontStyle}) =>
      switch (fontChoice) {
        'hyperlegible' => GoogleFonts.atkinsonHyperlegible(fontSize: fontSize, fontWeight: fontWeight, color: color,
            height: _h(height), letterSpacing: letterSpacing, fontStyle: fontStyle),
        _ => GoogleFonts.lexend(fontSize: fontSize, fontWeight: fontWeight, color: color, height: _h(height),
            letterSpacing: letterSpacing, fontStyle: fontStyle),
      };

  static TextStyle serif({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) =>
      fontChoice != 'standard'
          ? _accessible(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height,
              letterSpacing: letterSpacing, fontStyle: fontStyle)
          : GoogleFonts.sourceSerif4(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: _h(height),
              letterSpacing: letterSpacing,
              fontStyle: fontStyle,
            );

  static TextStyle sans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      fontChoice != 'standard'
          ? _accessible(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, letterSpacing: letterSpacing)
          : GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: _h(height),
              letterSpacing: letterSpacing,
            );

  static TextStyle mono({double? fontSize, Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: fontSize, color: color);

  static ThemeData _build(DscvrColors c, Brightness brightness, [bool reduceMotion = false]) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.inverseInk,
      secondary: c.inkMuted,
      onSecondary: c.inverseInk,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.ink,
      surfaceContainerHighest: c.surfaceMuted,
      surfaceContainerHigh: c.surfaceMuted,
      surfaceContainer: c.surface,
      surfaceContainerLow: c.background,
      surfaceContainerLowest: c.background,
      outline: c.line,
      outlineVariant: c.line,
      onSurfaceVariant: c.inkMuted,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      // No Material ripples anywhere: interactions use spring presses.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: c.selection.withValues(alpha: 0.6),
      focusColor: c.selection,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      pageTransitionsTheme: reduceMotion
          ? PageTransitionsTheme(builders: {
              for (final p in TargetPlatform.values) p: const _NoTransition(),
            })
          : const PageTransitionsTheme(builders: {
        // Native-feeling slide with swipe-back on phones and tablets.
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        // Quiet fade-through on desktop and web.
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      }),
      extensions: [c],
    );

    // Through sans()/serif() so the reading-font setting reaches theme text too.
    TextStyle s(double size, FontWeight w, Color color, {double h = 1.4}) =>
        sans(fontSize: size, fontWeight: w, color: color, height: h);
    TextStyle sf(double size, FontWeight w, {double h = 1.2}) =>
        serif(fontSize: size, fontWeight: w, color: c.ink, height: h, letterSpacing: fontChoice == 'standard' ? -0.2 : 0);

    final text = TextTheme(
      displayLarge: sf(44, FontWeight.w600, h: 1.1),
      displayMedium: sf(36, FontWeight.w600, h: 1.12),
      displaySmall: sf(30, FontWeight.w600, h: 1.15),
      headlineLarge: sf(28, FontWeight.w600),
      headlineMedium: sf(24, FontWeight.w600),
      headlineSmall: sf(20, FontWeight.w600),
      titleLarge: sf(18, FontWeight.w600, h: 1.25),
      titleMedium: s(15, FontWeight.w600, c.ink),
      titleSmall: s(13.5, FontWeight.w600, c.ink),
      bodyLarge: s(15.5, FontWeight.w400, c.ink, h: 1.6),
      bodyMedium: s(14, FontWeight.w400, c.ink, h: 1.5),
      bodySmall: s(12.5, FontWeight.w400, c.inkMuted, h: 1.45),
      labelLarge: s(14, FontWeight.w500, c.ink),
      labelMedium: s(12.5, FontWeight.w500, c.inkMuted),
      labelSmall: s(11, FontWeight.w500, c.inkFaint, h: 1.3),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: c.line),
    );

    return base.copyWith(
      textTheme: text,
      iconTheme: IconThemeData(color: c.inkMuted, size: 20),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: s(15, FontWeight.w600, c.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        hintStyle: s(14, FontWeight.w400, c.inkFaint),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: s(13, FontWeight.w500, c.inkMuted),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: c.inkMuted, width: 1.4)),
        errorBorder:
            inputBorder.copyWith(borderSide: BorderSide(color: c.danger)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.inverseInk,
          textStyle: s(14, FontWeight.w600, c.inverseInk),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.line),
          textStyle: s(14, FontWeight.w500, c.ink),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          textStyle: s(14, FontWeight.w500, c.ink),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.sm)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.inkMuted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.xl)),
        titleTextStyle: sf(22, FontWeight.w600),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.line,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: s(14, FontWeight.w400, c.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: c.line),
        ),
        elevation: 6,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: s(14, FontWeight.w500, c.inverseInk),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        textStyle: s(12, FontWeight.w500, c.inverseInk),
        waitDuration: const Duration(milliseconds: 400),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.ink,
        linearTrackColor: c.line,
        circularTrackColor: c.line,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.inverseInk : c.inkFaint),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.ink : c.surfaceMuted),
        trackOutlineColor: WidgetStateProperty.all(c.line),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.ink,
        selectionColor: c.ink.withValues(alpha: 0.18),
        selectionHandleColor: c.ink,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(c.inkFaint.withValues(alpha: 0.4)),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(6),
      ),
    );
  }
}


/// Page changes without movement, for the reduce-motion setting.
class _NoTransition extends PageTransitionsBuilder {
  const _NoTransition();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      child;
}
