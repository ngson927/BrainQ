import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';
import '../providers/auth_provider.dart';

class AdminProvider extends ChangeNotifier {
  final AuthProvider authProvider;

  AdminProvider({required this.authProvider});


  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> decks = [];
  Map<String, dynamic>? dashboardStats;

  final Map<int, Map<String, dynamic>> _userCache = {};
  final Map<int, Map<String, dynamic>> _deckCache = {};

  bool loadingUsers = false;
  bool loadingDecks = false;
  bool loadingDashboard = false;

  String? error;

  // -----------------------------
  // HELPER
  // -----------------------------
  bool _canProceed() {
    if (!authProvider.isAdmin || authProvider.token == null) {
      error = "Unauthorized: Admin access required";
      notifyListeners();
      return false;
    }
    return true;
  }

  // =============================
  // QUERY BUILDERS
  // =============================
  Map<String, String> buildUserQuery({
    String? role,
    String? status,
    String? search,
    DateTime? joinedAfter,
    DateTime? joinedBefore,
  }) {
    final Map<String, String> query = {};
    if (role != null) query['role'] = role;
    if (status != null) query['status'] = status;
    if (search != null) query['search'] = search;
    if (joinedAfter != null) query['joined_after'] = joinedAfter.toIso8601String();
    if (joinedBefore != null) query['joined_before'] = joinedBefore.toIso8601String();
    return query;
  }

  Map<String, String> buildDeckQuery({
    String? search,
    bool? isPublic,
    bool? flagged,
    String? owner,
    DateTime? createdAfter,
    DateTime? createdBefore,
  }) {
    final Map<String, String> query = {};
    if (search != null) query['search'] = search;
    if (isPublic != null) query['is_public'] = isPublic.toString();
    if (flagged != null) query['flagged'] = flagged.toString();
    if (owner != null) query['owner'] = owner;
    if (createdAfter != null) query['created_after'] = createdAfter.toIso8601String();
    if (createdBefore != null) query['created_before'] = createdBefore.toIso8601String();
    return query;
  }

  // =============================
  // USERS
  // =============================
Future<void> fetchUsers({
  Map<String, dynamic>? queryParams,
  int? page,
  int? pageSize,
}) async {
  if (!_canProceed()) return;

  loadingUsers = true;
  error = null;
  notifyListeners();

  try {
    // Convert all queryParams keys and values to strings
    final params = queryParams != null
        ? queryParams.map((key, value) => MapEntry(key.toString(), value.toString()))
        : <String, String>{};

    if (page != null) params['page'] = page.toString();
    if (pageSize != null) params['page_size'] = pageSize.toString();

    final response = await ApiService.adminGetUsers(
      token: authProvider.token!,
      queryParams: params,
    );

    if (response.statusCode == 200) {
      final data = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      _userCache.clear();
      for (var user in data) {
        _userCache[user['id']] = user;
      }
      users = _userCache.values.toList();
    } else {
      error = "Failed to fetch users (${response.statusCode})";
    }
  } catch (e) {
    error = "fetchUsers error: $e";
  }

  loadingUsers = false;
  notifyListeners();
}


  Future<Map<String, dynamic>?> getUserDetail(int userId) async {
    if (!_canProceed()) return null;
    if (_userCache.containsKey(userId)) return _userCache[userId];

    try {
      final response = await ApiService.adminGetUserDetail(
        token: authProvider.token!,
        userId: userId,
      );
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body));
        _userCache[userId] = data;
        return data;
      } else {
        error = "Failed to get user detail (${response.statusCode})";
        notifyListeners();
      }
    } catch (e) {
      error = "getUserDetail error: $e";
      notifyListeners();
    }

    return null;
  }

  Future<bool> updateUser(int userId, Map<String, dynamic> data) async {
    if (!_canProceed()) return false;
    try {
      final response = await ApiService.adminUpdateUser(
        token: authProvider.token!,
        userId: userId,
        data: data,
      );
      if (response.statusCode == 200) {
        final updatedUser = Map<String, dynamic>.from(jsonDecode(response.body));
        _userCache[userId] = updatedUser;
        users = _userCache.values.toList();
        notifyListeners();
        return true;
      } else {
        error = "Update failed (${response.statusCode})";
        notifyListeners();
      }
    } catch (e) {
      error = "updateUser error: $e";
      notifyListeners();
    }
    return false;
  }

  Future<bool> deleteUser(int userId) async {
    if (!_canProceed()) return false;
    try {
      final response = await ApiService.adminDeleteUser(
        token: authProvider.token!,
        userId: userId,
      );
      if (response.statusCode == 204) {
        _userCache.remove(userId);
        users = _userCache.values.toList();
        notifyListeners();
        return true;
      } else {
        error = "Delete failed (${response.statusCode})";
        notifyListeners();
      }
    } catch (e) {
      error = "deleteUser error: $e";
      notifyListeners();
    }
    return false;
  }

  Future<bool> bulkUserAction(List<int> userIds, String action) async {
    if (!_canProceed()) return false;
    try {
      final response = await ApiService.adminBulkUserAction(
        token: authProvider.token!,
        userIds: userIds,
        action: action,
      );
      if (response.statusCode == 200) {
        await fetchUsers();
        return true;
      } else {
        error = "Bulk action failed (${response.statusCode})";
        notifyListeners();
      }
    } catch (e) {
      error = "bulkUserAction error: $e";
      notifyListeners();
    }
    return false;
  }

  // =============================
  // USER CONVENIENCE HELPERS
  // =============================
  Future<bool> suspendUser(int userId) => updateUser(userId, {'suspend': true});
  Future<bool> activateUser(int userId) => updateUser(userId, {'activate': true});
  Future<bool> changeUserRole(int userId, String newRole) => updateUser(userId, {'role': newRole});

  Future<bool> bulkSuspendUsers(List<int> userIds) => bulkUserAction(userIds, 'suspend');
  Future<bool> bulkActivateUsers(List<int> userIds) => bulkUserAction(userIds, 'activate');
  Future<bool> bulkDeleteUsers(List<int> userIds) => bulkUserAction(userIds, 'delete');

  // =============================
  // DASHBOARD
  // =============================
  Future<void> fetchDashboardStats({Map<String, String>? queryParams}) async {
    if (!_canProceed()) return;
    loadingDashboard = true;
    error = null;
    notifyListeners();
    try {
      final response = await ApiService.adminDashboardStats(
        token: authProvider.token!,
        queryParams: queryParams,
      );
      if (response.statusCode == 200) {
        dashboardStats = Map<String, dynamic>.from(jsonDecode(response.body));
      } else {
        error = "Failed to fetch dashboard (${response.statusCode})";
      }
    } catch (e) {
      error = "fetchDashboardStats error: $e";
    }
    loadingDashboard = false;
    notifyListeners();
  }

// =============================
// DECKS
// =============================
Future<void> fetchDecks({
  Map<String, dynamic>? queryParams,
  int? page,
  int? pageSize,
}) async {
  if (!_canProceed()) return;

  loadingDecks = true;
  error = null;
  notifyListeners();

  try {
    final params = queryParams != null
        ? queryParams.map((key, value) => MapEntry(key.toString(), value.toString()))
        : <String, String>{};

    if (page != null) params['page'] = page.toString();
    if (pageSize != null) params['page_size'] = pageSize.toString();

    if (kDebugMode) {
      debugPrint("🔹 Fetching decks with params: $params");
    }

    final response = await ApiService.adminGetDecks(
      token: authProvider.token!,
      queryParams: params,
    );

    if (kDebugMode) {
      debugPrint("🔹 Fetch decks response: ${response.statusCode} ${response.body}");
    }

    if (response.statusCode == 200) {
      final data = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      _deckCache.clear();
      for (var deck in data) {
        if (deck['id'] != null) {
          _deckCache[deck['id']] = deck;
        }
      }
      decks = _deckCache.values.toList();
    } else {
      error = "Failed to fetch decks (${response.statusCode})";
    }
  } catch (e) {
    error = "fetchDecks error: $e";
  }

  loadingDecks = false;
  notifyListeners();
}

Future<Map<String, dynamic>?> getDeckDetail(int deckId, {bool forceRefresh = false}) async {
  if (!_canProceed()) return null;

  if (!forceRefresh) {
    final cached = _deckCache[deckId];
    if (cached != null) {
      if (kDebugMode) print("🔹 Returning cached deck $deckId");
      return cached;
    }
  }

  if (kDebugMode) print("🔹 Fetching deck with ID: $deckId");

  try {
    final response = await ApiService.adminGetDeckDetail(
      token: authProvider.token!,
      deckId: deckId,
    );

    if (response.statusCode == 200) {
      final data = Map<String, dynamic>.from(jsonDecode(response.body));

      // Ensure flashcards, tags, and comments are always Lists
      data['flashcards'] = data['flashcards'] != null
          ? List<Map<String, dynamic>>.from(data['flashcards'])
          : <Map<String, dynamic>>[];
      data['tags'] = data['tags'] != null ? List<String>.from(data['tags']) : <String>[];
      data['comments'] = data['comments'] != null
          ? List<Map<String, dynamic>>.from(data['comments'])
          : <Map<String, dynamic>>[];

      if (kDebugMode) print("🔹 Deck detail received: $data");

      _deckCache[deckId] = data;
      return data;
    } else {
      error = "Deck detail failed (${response.statusCode})";
      notifyListeners();
    }
  } catch (e) {
    error = "getDeckDetail error: $e";
    notifyListeners();
  }

  return null;
}



Future<bool> updateDeck(int deckId, Map<String, dynamic> data) async {
  if (!_canProceed()) return false;
  try {
    final response = await ApiService.adminUpdateDeck(
      token: authProvider.token!,
      deckId: deckId,
      data: data,
    );
    if (response.statusCode == 200) {
      final updatedDeck = Map<String, dynamic>.from(jsonDecode(response.body));
      _deckCache[deckId] = updatedDeck;
      decks = _deckCache.values.toList();
      notifyListeners();
      return true;
    } else {
      error = "Update deck failed (${response.statusCode})";
      notifyListeners();
    }
  } catch (e) {
    error = "updateDeck error: $e";
    notifyListeners();
  }
  return false;
}

Future<bool> deleteDeck(int deckId) async {
  if (!_canProceed()) return false;

  final deck = _deckCache[deckId];
  if (deck != null) {
    final isPublic = deck['is_public'] as bool?;
    if (isPublic == false) {
      error = "Cannot delete private decks.";
      notifyListeners();
      return false;
    }
  }

  try {
    final response = await ApiService.adminDeleteDeck(
      token: authProvider.token!,
      deckId: deckId,
    );
    if (response.statusCode == 204) {
      _deckCache.remove(deckId);
      decks = _deckCache.values.toList();
      notifyListeners();
      return true;
    } else {
      error = "Delete deck failed (${response.statusCode})";
      notifyListeners();
    }
  } catch (e) {
    error = "deleteDeck error: $e";
    notifyListeners();
  }
  return false;
}

Future<bool> bulkDeckAction(List<int> deckIds, String action) async {
  if (!_canProceed()) return false;

  // Ensure private decks aren't deleted
  if (action == 'delete') {
    deckIds = deckIds.where((id) {
      final deck = _deckCache[id];
      final isPublic = deck?['is_public'] as bool?;
      return isPublic != false;
    }).toList();
  }

  try {
    final response = await ApiService.adminBulkDeckAction(
      token: authProvider.token!,
      deckIds: deckIds,
      action: action,
    );
    if (response.statusCode == 200) {
      await fetchDecks();
      return true;
    } else {
      error = "Bulk deck action failed (${response.statusCode})";
      notifyListeners();
    }
  } catch (e) {
    error = "bulkDeckAction error: $e";
    notifyListeners();
  }
  return false;
}

// Deck convenience helpers
Future<bool> archiveDeck(int deckId) => updateDeck(deckId, {'is_archived': true});
Future<bool> unarchiveDeck(int deckId) => updateDeck(deckId, {'is_archived': false});
Future<bool> hideDeck(int deckId) => updateDeck(deckId, {'admin_hidden': true});
Future<bool> unhideDeck(int deckId) => updateDeck(deckId, {'admin_hidden': false});
Future<bool> flagDeck(int deckId, String reason) => updateDeck(deckId, {'is_flagged': true, 'flag_reason': reason});
Future<bool> unflagDeck(int deckId) => updateDeck(deckId, {'is_flagged': false, 'flag_reason': null});

Future<bool> bulkArchiveDecks(List<int> deckIds) => bulkDeckAction(deckIds, 'archive');
Future<bool> bulkUnarchiveDecks(List<int> deckIds) => bulkDeckAction(deckIds, 'unarchive');
Future<bool> bulkHideDecks(List<int> deckIds) => bulkDeckAction(deckIds, 'hide');
Future<bool> bulkUnhideDecks(List<int> deckIds) => bulkDeckAction(deckIds, 'unhide');
Future<bool> bulkDeleteDecks(List<int> deckIds) => bulkDeckAction(deckIds, 'delete');
}