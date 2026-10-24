import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-level preferences: theme, reader text size and Pinda verbosity.
class SettingsController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _readerScale = 1.0;
  String _pindaStyle = 'detailed';
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  double get readerScale => _readerScale;
  String get pindaStyle => _pindaStyle;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final p = _prefs!;
      _themeMode = ThemeMode.values.firstWhere((m) => m.name == p.getString('themeMode'),
          orElse: () => ThemeMode.system);
      _readerScale = p.getDouble('readerScale') ?? 1.0;
      _pindaStyle = p.getString('pindaStyle') ?? 'detailed';
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
}
