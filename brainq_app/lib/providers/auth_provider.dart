import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_helper.dart';
import '../services/api_service.dart';
import '../providers/deck_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthProvider extends ChangeNotifier {
  String? _username;
  String? _email;
  String? _firstName;
  String? _lastName;
  String? _token;
  String? _userId;
  String? _role;
  bool _isSuspended = false;
  bool _isActive = true;

  // ----------------- Getters -----------------
  String? get username => _username;
  String? get email => _email;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  String? get token => _token;
  String? get userId => _userId;
  String? get role => _role;
  bool get isSuspended => _isSuspended;
  bool get isActive => _isActive;

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  bool get isAdmin => _role == 'admin';

  // ----------------- Login -----------------
  Future<void> login({
    required String username,
    required String email,
    String? firstName,
    String? lastName,
    required String token,
    required String userId,
    required String role,
    required bool isSuspended,
    required bool isActive,
    DeckProvider? deckProvider,
  }) async {
    if (isSuspended || !isActive) {
      throw Exception(
        isSuspended ? "This account has been suspended" : "This account is inactive",
      );
    }

    _username = username;
    _email = email;
    _firstName = firstName;
    _lastName = lastName;
    _token = token;
    _userId = userId;
    _role = role;
    _isSuspended = isSuspended;
    _isActive = isActive;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setString('email', email);
    if (firstName != null) await prefs.setString('firstName', firstName);
    if (lastName != null) await prefs.setString('lastName', lastName);
    await prefs.setString('token', token);
    await prefs.setString('userId', userId);
    await prefs.setString('role', role);
    await prefs.setBool('isSuspended', isSuspended);
    await prefs.setBool('isActive', isActive);

    if (deckProvider != null) {
      deckProvider.setAuth(token: token, userId: userId);
      await deckProvider.fetchDecks();
    }

    // Register FCM token
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await ApiHelper.post(
          'device-tokens/',
          headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'token': fcmToken}),
        );
      }
    } catch (e) {
      debugPrint("❌ Failed to register FCM token: $e");
    }
  }

  // ----------------- Logout -----------------
  Future<void> logout({DeckProvider? deckProvider}) async {
    try {
      if (_token != null) {
        await ApiHelper.post(
          'users/logout/',
          headers: {'Authorization': 'Token $_token', 'Content-Type': 'application/json'},
        );
      }
    } catch (_) {}

    _username = null;
    _email = null;
    _firstName = null;
    _lastName = null;
    _token = null;
    _userId = null;
    _role = null;
    _isSuspended = false;
    _isActive = true;

    notifyListeners();

    if (deckProvider != null) deckProvider.clearAuth();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ----------------- Restore Session -----------------
  Future<void> loadUserFromPrefs({DeckProvider? deckProvider}) async {
    final prefs = await SharedPreferences.getInstance();

    final savedToken = prefs.getString('token');
    final savedUserId = prefs.getString('userId');

    if (savedToken != null && savedToken.isNotEmpty && savedUserId != null) {
      _token = savedToken;
      _username = prefs.getString('username');
      _email = prefs.getString('email');
      _firstName = prefs.getString('firstName');
      _lastName = prefs.getString('lastName');
      _userId = savedUserId;
      _role = prefs.getString('role');
      _isSuspended = prefs.getBool('isSuspended') ?? false;
      _isActive = prefs.getBool('isActive') ?? true;

      if (_isSuspended || !_isActive) {
        await logout(deckProvider: deckProvider);
        throw Exception("Account suspended or inactive");
      }

      notifyListeners();

      if (deckProvider != null) {
        deckProvider.setAuth(token: savedToken, userId: savedUserId);
        await deckProvider.fetchDecks();
      }
    }
  }

  // ----------------- Update Profile -----------------
  Future<void> updateProfile({
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? currentPassword,
    String? newPassword,
    String? confirmPassword,
  }) async {
    if (_token == null) throw Exception("Not authenticated");

    final response = await ApiService.updateProfile(
      token: _token!,
      username: username,
      email: email,
      firstName: firstName,
      lastName: lastName,
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to update profile');
    }

    final data = jsonDecode(response.body);

    if (data['user'] != null) {
      _username = data['user']['username'];
      _email = data['user']['email'];
      _firstName = data['user']['first_name'];
      _lastName = data['user']['last_name'];
    }

    final prefs = await SharedPreferences.getInstance();
    if (_username != null) await prefs.setString('username', _username!);
    if (_email != null) await prefs.setString('email', _email!);
    if (_firstName != null) await prefs.setString('firstName', _firstName!);
    if (_lastName != null) await prefs.setString('lastName', _lastName!);

    notifyListeners();
  }

  // ----------------- Change Password -----------------
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await updateProfile(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  // ----------------- Delete Account -----------------
  Future<void> deleteAccount({
    required String password,
    DeckProvider? deckProvider,
  }) async {
    if (_token == null) throw Exception("Not authenticated");

    final response = await ApiService.deleteAccount(
      token: _token!,
      password: password,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to delete account');
    }

    await logout(deckProvider: deckProvider);
  }
}
