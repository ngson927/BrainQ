import 'dart:convert';
import 'dart:io';
import 'package:brainq_app/models/deck.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api_helper.dart';
import '../models/notifications.dart';

class ApiService {

  static Future<http.Response> login(
    String username,
    String password, {
    String? timezone,
  }) async {
    try {
      final response = await ApiHelper.post(
        'users/login/',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          if (timezone != null) 'timezone': timezone,
        }),
      );

      if (kDebugMode) {
        debugPrint('Login response: ${response.statusCode} ${response.body}');
      }

      return response;
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }


  static Future<http.Response> logout({required String token}) async {
    try {
      return await ApiHelper.post(
        'users/logout/',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }


  static Future<http.Response> register({
    String? username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      // Auto-generate username if not provided
      final generatedUsername = (username != null && username.isNotEmpty)
          ? username
          : 'user_${DateTime.now().millisecondsSinceEpoch}';

      final body = {
        'username': generatedUsername,
        'email': email,
        'password': password,
        'password2': password,
      };

      if (firstName != null && firstName.isNotEmpty) body['first_name'] = firstName;
      if (lastName != null && lastName.isNotEmpty) body['last_name'] = lastName;

      return await ApiHelper.post(
        'users/register/',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }



  static Future<http.Response> requestPasswordReset(String email) async {
    try {
      return await ApiHelper.post(
        'users/password-reset/',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }


  static Future<http.Response> confirmPasswordReset(
    String token,
    String newPassword,
  ) async {
    try {
      return await ApiHelper.post(
        'users/password-reset/confirm/',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'new_password': newPassword}),
      );
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }

  static Future<http.Response> updateProfile({
  required String token,


  String? username,
  String? email,
  String? firstName,
  String? lastName,

  String? currentPassword,
  String? newPassword,
  String? confirmPassword,
}) async {
  try {
    final Map<String, dynamic> body = {};

    // Profile fields
    if (username != null) body['username'] = username;
    if (email != null) body['email'] = email;
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;

    // Password fields
    if (currentPassword != null) body['current_password'] = currentPassword;
    if (newPassword != null) body['new_password'] = newPassword;
    if (confirmPassword != null) body['confirm_password'] = confirmPassword;

    final response = await ApiHelper.patch(
      'users/update-profile/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(body),
    );

    if (kDebugMode) {
      debugPrint('Update Profile response: ${response.statusCode}');
      debugPrint(response.body);
    }

    return response;
  } catch (e) {
    throw Exception('Failed to update profile: $e');
  }
}
static Future<http.Response> deleteAccount({
  required String token,
  required String password,
}) async {
  try {
    final response = await ApiHelper.post(
      'users/delete-account/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({'password': password}),
    );

    if (kDebugMode) {
      debugPrint('Delete Account response: ${response.statusCode}');
      debugPrint(response.body);
    }

    return response;
  } catch (e) {
    throw Exception('Failed to delete account: $e');
  }
}


  // -----------------------------
  // ADMIN USERS
  // -----------------------------
  static Future<http.Response> adminGetUsers({required String token, Map<String, String>? queryParams}) async {
    String url = 'admin/users/';
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams).query;
      url += '?$queryString';
    }
    return await ApiHelper.get(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
    );
  }

  static Future<http.Response> adminGetUserDetail({required String token, required int userId}) async {
    return await ApiHelper.get(
      'admin/users/$userId/',
      headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
    );
  }

  static Future<http.Response> adminUpdateUser({required String token, required int userId, Map<String, dynamic>? data}) async {
    return await ApiHelper.patch(
      'admin/users/$userId/',
      headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
      body: jsonEncode(data ?? {}),
    );
  }

  static Future<http.Response> adminDeleteUser({required String token, required int userId}) async {
    return await ApiHelper.delete(
      'admin/users/$userId/',
      headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
    );
  }

  static Future<http.Response> adminBulkUserAction({required String token, required List<int> userIds, required String action}) async {
    return await ApiHelper.post(
      'admin/users/bulk/',
      headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
      body: jsonEncode({'user_ids': userIds, 'action': action}),
    );
  }

  // -----------------------------
  // ADMIN DASHBOARD
  // -----------------------------
  static Future<http.Response> adminDashboardStats({required String token, Map<String, String>? queryParams}) async {
    String url = 'admin/dashboard/stats';
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams).query;
      url += '?$queryString';
    }
    return await ApiHelper.get(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
    );
  }

  // -----------------------------
  // ADMIN DECKS
  // -----------------------------
  static Future<http.Response> adminGetDecks({required String token, Map<String, String>? queryParams}) async {
    String url = 'admin/decks/';
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams).query;
      url += '?$queryString';
    }
    return await ApiHelper.get(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
    );
  }

  static Future<http.Response> adminGetDeckDetail({required String token, required int deckId}) async {
    return await ApiHelper.get(
      'admin/decks/$deckId/',
      headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
    );
  }

  static Future<http.Response> adminUpdateDeck({required String token, required int deckId, Map<String, dynamic>? data}) async {
    return await ApiHelper.patch(
      'admin/decks/$deckId/',
      headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
      body: jsonEncode(data ?? {}),
    );
  }

  static Future<http.Response> adminDeleteDeck({required String token, required int deckId}) async {
    return await ApiHelper.delete(
      'admin/decks/$deckId/',
      headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
    );
  }

  static Future<http.Response> adminBulkDeckAction({required String token, required List<int> deckIds, required String action}) async {
    return await ApiHelper.post(
      'admin/decks/bulk/',
      headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
      body: jsonEncode({'deck_ids': deckIds, 'action': action}),
    );
  }


  static Future<http.StreamedResponse> createDeck({
    required String token,
    required String title,
    required String description,
    required bool isPublic,
    List<Map<String, dynamic>>? cards,
    List<String>? tags,
    File? coverImageFile,
    String? cardOrder,
    Map<String, dynamic>? theme,
    bool saveAsNewTheme = false,
    String? themeName,

  }) async {
    final uri = Uri.parse('${ApiHelper.baseUrl}decks/create/');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Token $token';

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['is_public'] = isPublic.toString();

    if (cardOrder != null) request.fields['card_order'] = cardOrder;

    final normalizedTags = (tags ?? []).map((t) => t.toString()).toList();
    final normalizedCards = cards ?? [];

    // send tags as a comma-separated string
    request.fields['tags'] = normalizedTags.join(",");

    request.fields['flashcards'] = jsonEncode(normalizedCards);

    if (theme != null) {
      request.fields['theme'] = jsonEncode(theme);
      request.fields['save_as_new_theme'] = saveAsNewTheme.toString();

      if (themeName != null && themeName.isNotEmpty) {
        request.fields['theme_name'] = themeName;
      }
    }


    if (coverImageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('cover_image', coverImageFile.path),
      );
    }

    return await request.send();
  }

  static Future<http.StreamedResponse> editDeck({
    required String token,
    required int deckId,
    String? title,
    String? description,
    bool? isPublic,
    List<Map<String, dynamic>>? cards,
    List<String>? tags,
    File? coverImageFile,
    String? cardOrder,
    Map<String, dynamic>? theme,
    bool saveAsNewTheme = false,
  }) async {
    final uri = Uri.parse('${ApiHelper.baseUrl}decks/$deckId/edit/');
    final request = http.MultipartRequest('PATCH', uri);

    request.headers['Authorization'] = 'Token $token';

    if (title != null) request.fields['title'] = title;
    if (description != null) request.fields['description'] = description;
    if (isPublic != null) request.fields['is_public'] = isPublic.toString();
    if (cardOrder != null) request.fields['card_order'] = cardOrder;

    if (tags != null) {
      final normalizedTags = tags.map((t) => t.toString()).toList();
      debugPrint("📤 [editDeck] tags: ${normalizedTags.join(",")}");
      // ✅ Send tags as a comma-separated string
      request.fields['tags'] = normalizedTags.join(",");
    }

    if (cards != null) {
      debugPrint("📤 [editDeck] cards: ${jsonEncode(cards)}");
      request.fields['flashcards'] = jsonEncode(cards);
    }

    if (theme != null) {
      debugPrint("📤 [editDeck] theme: ${jsonEncode(theme)} saveAsNewTheme: $saveAsNewTheme");
      request.fields['theme'] = jsonEncode(theme);
      request.fields['save_as_new_theme'] = saveAsNewTheme.toString();
    }

    if (coverImageFile != null) {
      debugPrint("📤 [editDeck] coverImageFile: ${coverImageFile.path}");
      request.files.add(
        await http.MultipartFile.fromPath('cover_image', coverImageFile.path),
      );
    }

    return await request.send();
  }




static Future<http.Response> getDeckTheme({
  required String token,
  required int deckId,
}) async {
  return await ApiHelper.get(
    '/decks/$deckId/customize-theme/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
  );
}

static Future<http.Response> customizeDeckTheme({
  required String token,
  required int deckId,
  Map<String, dynamic>? themeData,
  bool saveAsNew = false,
  bool resetToDefault = false,
  int? themeId,
}) async {
  final Map<String, dynamic> body = {};

  if (resetToDefault) {
    body['reset_to_default'] = true;
  }

  if (themeId != null) {
    body['theme_id'] = themeId;
  }

  if (themeData != null) {
    body.addAll(themeData);
    body['save_as_new'] = saveAsNew;
  }

  debugPrint("PATCH /decks/$deckId/customize-theme → ${jsonEncode(body)}");

  return await ApiHelper.patch(
    '/decks/$deckId/customize-theme/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
    body: jsonEncode(body),
  );
}
static Future<http.Response> getAvailableThemes({
  required String token,
}) async {
  debugPrint("📥 GET /themes/available/");

  return await ApiHelper.get(
    '/themes/available/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
  );
}


/// ---- List all decks----
static Future<http.Response> listDecks({String? token}) async {
  final headers = {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Token $token',
  };
  return await ApiHelper.get('/decks/', headers: headers);
}


// ---- Delete deck ----
static Future<http.Response> deleteDeck({
  required String token,
  required int deckId,
}) async {
  return await ApiHelper.delete(
    '/decks/$deckId/delete/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
  );
}

// ==================== AI / OPENAI ====================

/// ---- Generate AI Deck ----
static Future<http.Response> generateAIDeck({
  required String token,
  required String inputType,
  required bool isPublic,
  String? promptText,
  String? inputSummary,
  int? requestedCount, // ✅ new field
  http.MultipartFile? file,
  http.MultipartFile? image,
}) async {
  final uri = Uri.parse('${ApiHelper.baseUrl}ai/generate/');
  final request = http.MultipartRequest('POST', uri);

  // Headers
  request.headers['Authorization'] = 'Token $token';
  request.headers['Accept'] = 'application/json';

  // Fields
  request.fields['input_type'] = inputType;
  request.fields['is_public'] = isPublic.toString();

  if (promptText != null && promptText.isNotEmpty) {
    request.fields['prompt_text'] = promptText;
  }

  if (inputSummary != null && inputSummary.isNotEmpty) {
    request.fields['input_summary'] = inputSummary;
  }

  // ✅ Send requested count only for text prompts
  if (requestedCount != null && inputType == 'prompt') {
    request.fields['requested_count'] = requestedCount.toString();
  }

  // Files
  if (file != null && inputType == 'file') {
    request.files.add(file);
  }

  if (image != null && inputType == 'image') {
    request.files.add(image);
  }

  // Send request
  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);

  if (kDebugMode) {
    print('generateAIDeck status: ${response.statusCode}');
    print('generateAIDeck body: ${response.body}');
  }

  return response;
}



/// ---- Start AI Assistant Session ----
static Future<http.Response> startAIAssistantSession({
  required String token,
  int? deckId,
  String? title,
}) async {
  final body = <String, dynamic>{};
  if (deckId != null) body['deck_id'] = deckId;
  if (title != null) body['title'] = title;

  return await ApiHelper.post(
    '/ai/assistant/start/',
    headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
}

/// ---- Send message to AI Assistant ----
static Future<http.Response> sendAIAssistantMessage({
  required String token,
  required int sessionId,
  required String message,
}) async {
  return await ApiHelper.post(
    '/ai/assistant/$sessionId/message/',
    headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
    body: jsonEncode({'message': message}),
  );
}

/// ---- List AI Assistant Sessions ----
static Future<http.Response> listAIAssistantSessions({required String token}) async {
  return await ApiHelper.get(
    '/ai/assistant/sessions/',
    headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
  );
}

/// ---- End AI Assistant Session ----
static Future<http.Response> endAIAssistantSession({
  required String token,
  required int sessionId,
}) async {
  return await ApiHelper.post(
    '/ai/assistant/$sessionId/end/',
    headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
  );
}


// ==================== SEARCH ====================
static Future<Map<String, dynamic>> search({
  required String query,
  String? token,
}) async {
  final headers = {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Token $token',
  };

  final response = await ApiHelper.get(
    '/search/?q=$query',
    headers: headers,
  );

  return _safeJson(response, "Search decks and flashcards");
}





  // ==================== FLASHCARDS ====================
static Future<http.Response> deleteFlashcard({
  required String token,
  required int flashcardId,
}) async {
  return await ApiHelper.delete(
    '/flashcards/$flashcardId/delete/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
  );
}


  static Future<http.Response> createFlashcard({
    required String token,
    required dynamic deckId,
    required String question,
    required String answer,
  }) async {
    return await ApiHelper.post(
      '/flashcards/create/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({
        'deck': int.tryParse(deckId.toString()) ?? deckId,
        'question': question,
        'answer': answer,
      }),
    );
  }


  static Future<http.Response> listFlashcards({
    required int deckId,
    String? token,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
    return await ApiHelper.get(
      '/decks/$deckId/flashcards',
      headers: headers,
    );
  }

    // ==================== DECKS SHARING ====================

  static Future<Map<String, dynamic>> getDeckShares(String token, int deckId) async {
    final response = await ApiHelper.get(
      '/decks/$deckId/share/list/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch shared users');
    }
  }


  /// Share deck with users
  static Future<List<SharedUser>> shareDeck(
    String token,
    int deckId,
    List<Map<String, String>> recipients,
  ) async {
    final response = await ApiHelper.post(
      '/decks/$deckId/share/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({'recipients': recipients}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final shared = (data['shared'] as List<dynamic>? ?? []);
      return shared.map((s) => SharedUser.fromJson(s)).toList();
    } else {
      throw Exception('Failed to share deck');
    }
  }

  /// Revoke shared users' access
  static Future<List<String>> revokeDeckShare(
      String token, int deckId, List<String> usernames) async {
    final response = await ApiHelper.post(
      '/decks/$deckId/share/revoke/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({'usernames': usernames}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['revoked'] ?? []);
    } else {
      throw Exception('Failed to revoke deck share');
    }
  }

  /// Toggle link sharing
  static Future<Map<String, dynamic>> toggleDeckLink(
      String token, int deckId, String action) async {
    final response = await ApiHelper.post(
      '/decks/$deckId/share/toggle_link/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({'action': action}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body); 
    } else {
      throw Exception('Failed to toggle link sharing');
    }
  }

// ==================== QUIZ ====================

  static Future<Map<String, dynamic>> _safeJson(http.Response response, String action) async {
    final body = response.body;
    final status = response.statusCode;

    if (status >= 200 && status < 300) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) return decoded;
        throw Exception("Invalid JSON object for $action: $body");
      } catch (e) {
        throw Exception("⚠️ $action: Failed to parse JSON.\nRaw body:\n$body");
      }
    } else {
      try {
        final errorJson = jsonDecode(body);
        final detail = errorJson['detail'] ?? errorJson.toString();
        throw Exception("❌ $action failed (status $status): $detail");
      } catch (_) {
        throw Exception("❌ $action failed (status $status)\nResponse:\n$body");
      }
    }
  }



  // ==================== QUIZ ====================

  static Future<Map<String, dynamic>> startSession({
    required int deckId,
    required String mode,
    required String token,
    bool adaptiveMode = true,
    bool srsEnabled = true,
    int? timePerCard,
  }) async {
    final body = {
      'mode': mode,
      'adaptive_mode': adaptiveMode,
      'srs_enabled': srsEnabled,
      if (timePerCard != null) 'time_per_card': timePerCard,
    };

    final response = await ApiHelper.post(
      '/quiz/start/$deckId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(body),
    );

    return _safeJson(response, "Start quiz session");
  }

  static Future<Map<String, dynamic>> submitAnswer({
    required int sessionId,
    required String answer,
    required String token,
    double? responseTime,
  }) async {
    final body = {
      'answer': answer,
      if (responseTime != null) 'response_time': responseTime,
    };

    final response = await ApiHelper.post(
      '/quiz/answer/$sessionId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(body),
    );

    return _safeJson(response, "Submit answer");
  }

  static Future<Map<String, dynamic>> skipQuestion({
    required int sessionId,
    required String token,
  }) async {
    final response = await ApiHelper.post(
      '/quiz/skip/$sessionId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
    return _safeJson(response, "Skip question");
  }

  static Future<Map<String, dynamic>> finishQuiz({
    required int sessionId,
    required String token,
  }) async {
    final response = await ApiHelper.post(
      '/quiz/finish/$sessionId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
    return _safeJson(response, "Finish quiz");
  }

  static Future<Map<String, dynamic>> changeMode({
    required int sessionId,
    required String mode,
    required String token,
  }) async {
    final response = await ApiHelper.post(
      '/quiz/change_mode/$sessionId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({'mode': mode}),
    );
    return _safeJson(response, "Change quiz mode");
  }

  static Future<Map<String, dynamic>> pauseQuiz({
    required int sessionId,
    required String token,
  }) async {
    final response = await ApiHelper.post(
      '/quiz/pause/$sessionId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
    return _safeJson(response, "Pause quiz");
  }

  static Future<Map<String, dynamic>> resumeQuiz({
    required int sessionId,
    required String token,
  }) async {
    final response = await ApiHelper.post(
      '/quiz/resume/$sessionId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
    return _safeJson(response, "Resume quiz");
  }

  static Future<Map<String, dynamic>> getResults({
    required int sessionId,
    required String token,
  }) async {
    final response = await ApiHelper.get(
      '/quiz/results/$sessionId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
    return _safeJson(response, "Fetch quiz results");
  }


// ==================== STREAK & REMINDERS ====================

static Future<Map<String, dynamic>> getStreak({
  required String token,
}) async {
  final response = await ApiHelper.get(
    '/achievements/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
  );
  return _safeJson(response, "Fetch streak stats");
}


static Future<Map<String, dynamic>> updateStreak({
  required String token,
}) async {
  final response = await ApiHelper.post(
    '/achievements/update/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
  );
  return _safeJson(response, "Update streak");
}

static Future<Map<String, dynamic>> recoverStreak({
  required String token,
}) async {
  final response = await ApiHelper.post(
    '/achievements/recover/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
  );
  return _safeJson(response, "Recover streak");
}


// List user's archived decks
static Future<http.Response> listArchivedDecks({required String token}) async {
  return await ApiHelper.get(
    '/decks/archived/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
  );
}

// Toggle archive/unarchive a deck
static Future<http.Response> toggleArchiveDeck({
  required String token,
  required int deckId,
}) async {
  return await ApiHelper.post(
    '/decks/$deckId/archive/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
  );
}

// ==================================================
  // ADD FEEDBACK (rating + optional comment)
  // ==================================================
static Future<http.Response> addFeedback({
    required String token,
    required int deckId,
    required int rating,
    String? comment,
  }) async {
    final body = {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    };

    return await ApiHelper.post(
      '/feedback/add/$deckId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> getUserFeedback({
    required String token,
    required int deckId,
  }) async {
    return await ApiHelper.get(
      '/feedback/user/$deckId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
  }

  // ==================================================
  // UPDATE FEEDBACK
  // ==================================================
  static Future<http.Response> updateFeedback({
    required String token,
    required int feedbackId,
    int? rating,
    String? comment,
  }) async {
    final body = {
      if (rating != null) 'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    };

    return await ApiHelper.patch(
      '/feedback/$feedbackId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(body),
    );
  }

  // ==================================================
  // DELETE FEEDBACK
  // ==================================================
  static Future<http.Response> deleteFeedback({
    required String token,
    required int feedbackId,
  }) async {
    return await ApiHelper.delete(
      '/feedback/$feedbackId/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
  }

  static Future<http.Response> getDeckFeedback({
    required int deckId,
  }) async {
    return await ApiHelper.get(
      '/feedback/list/$deckId/',
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }


  static Future<http.Response> registerDeviceToken({
    required String token,
    required String authToken,
  }) async {
    try {
      return await ApiHelper.post(
        'device-tokens',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $authToken',
        },
        body: jsonEncode({'token': token}),
      );
    } catch (e) {
      throw Exception('Failed to register FCM device token: $e');
    }
  }


  static Future<PaginatedNotifications> getNotifications({
    required String token,
    bool? isRead,
    int? page,
  }) async {
    final queryParams = <String, String>{};
    if (isRead != null) queryParams['is_read'] = isRead.toString();
    if (page != null) queryParams['page'] = page.toString();

    String path = 'notifications/';
    if (queryParams.isNotEmpty) {
      path += '?${Uri(queryParameters: queryParams).query}';
    }

    try {
      final response = await ApiHelper.get(
        path,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return PaginatedNotifications.fromJson(jsonData);
      } else {
        throw Exception(
            'Failed to fetch notifications: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  // Mark single notification as read
  static Future<NotificationModel> markNotificationRead({
    required String token,
    required String notificationId,
  }) async {
    String path = 'notifications/$notificationId/read/';

    try {
      final response = await ApiHelper.post(
        path,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return NotificationModel.fromJson(jsonData);
      } else {
        throw Exception(
            'Failed to mark notification read: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to mark notification read: $e');
    }
  }

  // Mark all notifications as read
  static Future<List<NotificationModel>> markAllNotificationsRead({
    required String token,
  }) async {
    String path = 'notifications/mark-all-read/';

    try {
      final response = await ApiHelper.post(
        path,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final List<dynamic> updated = jsonData['updated_notifications'] ?? [];
        return updated
            .map((e) => NotificationModel.fromJson(e))
            .toList();
      } else {
        throw Exception(
            'Failed to mark all notifications read: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to mark all notifications read: $e');
    }
  }
}