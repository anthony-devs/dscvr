import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fonts offered for easier reading. Atkinson Hyperlegible was designed for
/// low-vision readers; Lexend was designed to reduce visual stress and help
/// readers with dyslexia keep their place.
enum ReadingFont {
  standard('Standard', 'Inter and Source Serif'),
  hyperlegible('Atkinson Hyperlegible', 'Clear letter shapes for low vision'),
  lexend('Lexend', 'Wider spacing, easier for dyslexia');

  const ReadingFont(this.label, this.blurb);
  final String label;
  final String blurb;
}

/// Device-level preferences: theme, accessibility, reader and Pinda options.
/// Stored on this device only, so a shared or borrowed device can be set up
/// differently without changing the account.
class SettingsController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _readerScale = 1.0;
  String _pindaStyle = 'detailed';
  double _textScale = 1.0;
  ReadingFont _font = ReadingFont.standard;
  double _lineSpacing = 1.0;
  bool _highContrast = false;
  bool _reduceMotion = false;
  bool _lowData = false;
  double _speechRate = 1.0;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  double get readerScale => _readerScale;
  String get pindaStyle => _pindaStyle;

  /// Multiplies the system text size across the whole app (0.9 to 1.6).
  double get textScale => _textScale;
  ReadingFont get font => _font;

  /// Extra space between lines of body text (1.0 to 1.5).
  double get lineSpacing => _lineSpacing;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;

  /// Smaller result pages, no decorative images, nothing loads until asked.
  bool get lowData => _lowData;

  /// Read-aloud speed: 0.5 (slow) to 2.0 (fast), 1.0 is normal.
  double get speechRate => _speechRate;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final p = _prefs!;
      _themeMode = ThemeMode.values.firstWhere((m) => m.name == p.getString('themeMode'),
          orElse: () => ThemeMode.system);
      _readerScale = p.getDouble('readerScale') ?? 1.0;
      _pindaStyle = p.getString('pindaStyle') ?? 'detailed';
      _textScale = (p.getDouble('a11y.textScale') ?? 1.0).clamp(0.9, 1.6);
      _font = ReadingFont.values.firstWhere((f) => f.name == p.getString('a11y.font'), orElse: () => ReadingFont.standard);
      _lineSpacing = (p.getDouble('a11y.lineSpacing') ?? 1.0).clamp(1.0, 1.5);
      _highContrast = p.getBool('a11y.highContrast') ?? false;
      _reduceMotion = p.getBool('a11y.reduceMotion') ?? false;
      _lowData = p.getBool('lowData') ?? false;
      _speechRate = (p.getDouble('a11y.speechRate') ?? 1.0).clamp(0.5, 2.0);
    } catch (_) {
      // Storage unavailable (private browsing); keep defaults.
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs?.setString('themeMode', mode.name);
    notifyListeners();
  }

  void setReaderScale(double scale) {
    _readerScale = scale.clamp(0.85, 1.4);
    _prefs?.setDouble('readerScale', _readerScale);
    notifyListeners();
  }

  void setPindaStyle(String style) {
    _pindaStyle = style;
    _prefs?.setString('pindaStyle', style);
    notifyListeners();
  }

  void setTextScale(double v) {
    _textScale = v.clamp(0.9, 1.6);
    _prefs?.setDouble('a11y.textScale', _textScale);
    notifyListeners();
  }

  void setFont(ReadingFont f) {
    _font = f;
    _prefs?.setString('a11y.font', f.name);
    notifyListeners();
  }

  void setLineSpacing(double v) {
    _lineSpacing = v.clamp(1.0, 1.5);
    _prefs?.setDouble('a11y.lineSpacing', _lineSpacing);
    notifyListeners();
  }

  void setHighContrast(bool v) {
    _highContrast = v;
    _prefs?.setBool('a11y.highContrast', v);
    notifyListeners();
  }

  void setReduceMotion(bool v) {
    _reduceMotion = v;
    _prefs?.setBool('a11y.reduceMotion', v);
    notifyListeners();
  }

  void setLowData(bool v) {
    _lowData = v;
    _prefs?.setBool('lowData', v);
    notifyListeners();
  }

  void setSpeechRate(double v) {
    _speechRate = v.clamp(0.5, 2.0);
    _prefs?.setDouble('a11y.speechRate', _speechRate);
    notifyListeners();
  }

  void resetAccessibility() {
    _textScale = 1.0;
    _font = ReadingFont.standard;
    _lineSpacing = 1.0;
    _highContrast = false;
    _reduceMotion = false;
    for (final k in ['a11y.textScale', 'a11y.font', 'a11y.lineSpacing', 'a11y.highContrast', 'a11y.reduceMotion']) {
      _prefs?.remove(k);
    }
    notifyListeners();
  }
}
