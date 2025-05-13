import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  final String _isDarkModeKey = 'darkMode';
  final String _isDarkModeKeyPrefix = 'darkMode_';
  String? _userId;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider();

  void toggleTheme(bool isOn) {
    _isDarkMode = isOn;
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    if (_userId != null && _userId!.isNotEmpty) {
      await prefs.setBool('$_isDarkModeKeyPrefix$_userId', _isDarkMode);
    } else {
      await prefs.setBool(_isDarkModeKey, _isDarkMode);
    }
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    if (_userId != null && _userId!.isNotEmpty) {
      final userSetting = prefs.getBool('$_isDarkModeKeyPrefix$_userId');
      if (userSetting != null) {
        _isDarkMode = userSetting;
      } else {
        _isDarkMode = prefs.getBool(_isDarkModeKey) ?? false;
      }
    } else {
      _isDarkMode = prefs.getBool(_isDarkModeKey) ?? false;
    }

    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();

    if (_userId != null) {
      await prefs.remove('$_isDarkModeKeyPrefix$_userId');
    }

    await prefs.remove(_isDarkModeKey);
    _isDarkMode = false;
    notifyListeners();
  }

  void resetTheme(){
    _isDarkMode = false;
    notifyListeners();
  }

  Future<void> updateUserId(String? newUserId) async {
    _userId = newUserId;
    await loadFromPrefs(); 
  }
}