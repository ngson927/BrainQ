import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/deck_provider.dart';

class AuthProvider extends ChangeNotifier {
  String? _username;
  String? _email;
  String? _token;
  String? _userId; // <-- store logged-in user's ID

  String? get username => _username;
  String? get email => _email;
  String? get token => _token;
  String? get userId => _userId;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// ---- LOGIN ----
  /// Optional: inject DeckProvider to fetch user's decks immediately after login
  Future<void> login(
    String username, {
    required String token,
    required String userId,
    required String email, // <-- make it required now
    DeckProvider? deckProvider,
  }) async {
    _username = username;
    _email = email;
    _token = token;
    _userId = userId;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _username!);
    await prefs.setString('email', _email!);
    await prefs.setString('token', _token!);
    await prefs.setString('userId', _userId!);

    if (deckProvider != null) {
      deckProvider.setAuth(token: _token!, userId: _userId!);
      await deckProvider.fetchDecks();
    }
  }


  /// ---- LOGOUT ----
  Future<void> logout({DeckProvider? deckProvider}) async {
    _username = null;
    _email = null;
    _token = null;
    _userId = null;
    notifyListeners();

    // Clear decks from provider
    if (deckProvider != null) {
      deckProvider.clearAuth();
      deckProvider.clear();
    }

    // Clear from local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('token');
    await prefs.remove('userId');
  }

  /// ---- RESTORE SESSION ----
  Future<void> loadUserFromPrefs({DeckProvider? deckProvider}) async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');
    final savedUsername = prefs.getString('username');
    final savedEmail = prefs.getString('email');
    final savedUserId = prefs.getString('userId');

    if (savedToken != null && savedToken.isNotEmpty && savedUserId != null) {
      _token = savedToken;
      _username = savedUsername;
      _email = savedEmail;
      _userId = savedUserId;
      notifyListeners();

      if (deckProvider != null) {
        deckProvider.setAuth(token: _token!, userId: _userId!);
        await deckProvider.fetchDecks();
      }
    }
  }

  /// ---- UPDATE PROFILE LOCALLY ----
  Future<void> updateProfile({String? username, String? email}) async {
    if (username != null) _username = username;
    if (email != null) _email = email;

    final prefs = await SharedPreferences.getInstance();
    if (username != null) await prefs.setString('username', username);
    if (email != null) await prefs.setString('email', email);

    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// ---- DELETE ACCOUNT (stub for backend integration) ----
  Future<void> deleteAccount({DeckProvider? deckProvider}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    await logout(deckProvider: deckProvider);
  }
}
