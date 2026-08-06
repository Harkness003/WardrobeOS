import 'package:flutter/material.dart';
import '../diagnostics/diagnostic_service.dart';

class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get darkMode => _themeMode == ThemeMode.dark;
  bool get developerMode => DiagnosticService.instance.enabled;

  void setDarkMode(bool enabled) {
    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setDeveloperMode(bool enabled) {
    DiagnosticService.instance.setEnabled(enabled);
    notifyListeners();
  }
}
