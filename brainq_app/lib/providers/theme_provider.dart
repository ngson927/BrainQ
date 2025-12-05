import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import '../models/deck_theme.dart';
import '../screens/quiz/deck_screen.dart';
import '../services/api_service.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get currentTheme => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // =======================
  // DECK THEMES
  // =======================

  List<DeckTheme> _availableThemes = [];
  DeckTheme? _activeDeckTheme;

  List<DeckTheme> get availableThemes => _availableThemes;
  DeckTheme? get activeDeckTheme => _activeDeckTheme;

  String? _token;

  ThemeProvider() {
    _loadTheme();
  }

  void setAuthToken(String token) {
    _token = token;
    fetchAvailableThemes();
  }

  // =======================
  // APP THEME
  // =======================
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> resetToLight() async {
  _isDarkMode = false;
  notifyListeners();
}
  // =======================
  // DECK THEME HANDLING
  // =======================

  Future<void> fetchAvailableThemes() async {
    if (_token == null) return;

    try {
      final res = await ApiService.getAvailableThemes(token: _token!);

      if (res.statusCode != 200) {
        debugPrint("❌ Failed to fetch themes: ${res.body}");
        return;
      }

      final List data = jsonDecode(res.body);

      _availableThemes = data
          .whereType<Map<String, dynamic>>()
          .map((e) => DeckTheme.fromJson(e))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Theme fetch error: $e");
    }
  }

  void setActiveDeckTheme(DeckTheme theme) {
    _activeDeckTheme = theme;
    notifyListeners();
  }

  DeckTheme? getThemeById(int? id) {
    if (id == null || _availableThemes.isEmpty) return null;

    return _availableThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => _availableThemes.first,
    );
  }
  
  Color adaptDeckColor(String? hexColor, {required Color fallback}) {
    if (hexColor == null) return fallback;

    try {
      final color = HexColor(hexColor);
      if (_isDarkMode && color.computeLuminance() > 0.8) {
        return Colors.grey[800]!;
      }
      return color;
    } catch (_) {
      return fallback;
    }
  }

  Map<String, Color> getDeckThemeColors(DeckTheme theme) {
    return {
      "cardColor": adaptDeckColor(theme.cardColor, fallback: Colors.white),
      "textColor": adaptDeckColor(theme.textColor, fallback: Colors.black),
      "backgroundColor": adaptDeckColor(theme.backgroundColor, fallback: Colors.grey[200]!),
    };
  }

}

