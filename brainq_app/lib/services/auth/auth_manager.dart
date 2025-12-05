import 'package:shared_preferences/shared_preferences.dart';

class AuthManager {
  static String? _cachedToken;
  static String? _cachedUserId;
  static String? _cachedUsername;
  static String? _cachedEmail;
  static String? _cachedRole;
  static bool? _cachedIsSuspended;
  static bool? _cachedIsActive;

  // ----------------------------
  // Getters
  // ----------------------------
  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('token');
    return _cachedToken;
  }

  static Future<String?> getUserId() async {
    if (_cachedUserId != null) return _cachedUserId;
    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getString('userId');
    return _cachedUserId;
  }

  static Future<String?> getUsername() async {
    if (_cachedUsername != null) return _cachedUsername;
    final prefs = await SharedPreferences.getInstance();
    _cachedUsername = prefs.getString('username');
    return _cachedUsername;
  }

  static Future<String?> getEmail() async {
    if (_cachedEmail != null) return _cachedEmail;
    final prefs = await SharedPreferences.getInstance();
    _cachedEmail = prefs.getString('email');
    return _cachedEmail;
  }

  static Future<String?> getRole() async {
    if (_cachedRole != null) return _cachedRole;
    final prefs = await SharedPreferences.getInstance();
    _cachedRole = prefs.getString('role');
    return _cachedRole;
  }

  static Future<bool> isSuspended() async {
    if (_cachedIsSuspended != null) return _cachedIsSuspended!;
    final prefs = await SharedPreferences.getInstance();
    _cachedIsSuspended = prefs.getBool('isSuspended') ?? false;
    return _cachedIsSuspended!;
  }

  static Future<bool> isActive() async {
    if (_cachedIsActive != null) return _cachedIsActive!;
    final prefs = await SharedPreferences.getInstance();
    _cachedIsActive = prefs.getBool('isActive') ?? true;
    return _cachedIsActive!;
  }

  // ----------------------------
  // Role checks
  // ----------------------------
  static Future<bool> isAdmin() async {
    final role = await getRole();
    return role == 'admin';
  }

  static Future<bool> isUser() async {
    final role = await getRole();
    return role == 'user';
  }

  // ----------------------------
  // Combined guards
  // ----------------------------
  static Future<bool> canAccess() async {
    final suspended = await isSuspended();
    final active = await isActive();
    return !suspended && active;
  }

  static Future<bool> canAccessAdmin() async {
    return await canAccess() && await isAdmin();
  }

  static Future<bool> canAccessUser() async {
    return await canAccess() && await isUser();
  }

  // ----------------------------
  // Clear session / cache
  // ----------------------------
  static Future<void> clear() async {
    _cachedToken = null;
    _cachedUserId = null;
    _cachedUsername = null;
    _cachedEmail = null;
    _cachedRole = null;
    _cachedIsSuspended = null;
    _cachedIsActive = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ----------------------------
  // update single field in cache + prefs
  // ---------------------------
  static Future<void> setRole(String role) async {
    _cachedRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role);
  }

  static Future<void> setActive(bool active) async {
    _cachedIsActive = active;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isActive', active);
  }

  static Future<void> setSuspended(bool suspended) async {
    _cachedIsSuspended = suspended;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSuspended', suspended);
  }
}
