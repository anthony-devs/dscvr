import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds the light and dark [ThemeData] from [DscvrColors].
///
/// Type pairing: Source Serif 4 for display and titles (the academic,
/// paper-like voice) and Inter for interface text.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(DscvrColors.light, Brightness.light);
  static ThemeData dark() => _build(DscvrColors.dark, Brightness.dark);

  static TextStyle serif({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) =>
      GoogleFonts.sourceSerif4(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
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
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle mono({double? fontSize, Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: fontSize, color: color);

  static ThemeData _build(DscvrColors c, Brightness brightness) {
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
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: [c],
    );

    TextStyle s(double size, FontWeight w, Color color, {double h = 1.4}) =>
        GoogleFonts.inter(
            fontSize: size, fontWeight: w, color: color, height: h);
    TextStyle sf(double size, FontWeight w, {double h = 1.2}) =>
        GoogleFonts.sourceSerif4(
            fontSize: size,
            fontWeight: w,
            color: c.ink,
            height: h,
            letterSpacing: -0.2);

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
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: s(14, FontWeight.w400, c.inkFaint),
        labelStyle: s(13, FontWeight.w500, c.inkMuted),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: c.ink, width: 1.2)),
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
