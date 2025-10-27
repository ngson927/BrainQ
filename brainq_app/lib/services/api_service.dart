import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_helper.dart';

class ApiService {
  // ==================== AUTH ====================

  static Future<http.Response> login(String username, String password) async {
    return await ApiHelper.post(
      'users/login/',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
  }

  static Future<http.Response> register(
    String username,
    String email,
    String password,
  ) async {
    return await ApiHelper.post(
      'users/register/',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'password2': password,
      }),
    );
  }

  static Future<http.Response> requestPasswordReset(String email) async {
    return await ApiHelper.post(
      'users/password-reset/',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  static Future<http.Response> confirmPasswordReset(
    String token,
    String newPassword,
  ) async {
    return await ApiHelper.post(
      'users/password-reset/confirm/',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    );
  }

  // ==================== DECKS ====================

  static Future<http.Response> createDeck({
    required String token,
    required String title,
    required String description,
    required bool isPublic,
  }) async {
    return await ApiHelper.post(
      '/decks/create/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'is_public': isPublic,
      }),
    );
  }

  static Future<http.Response> listDecks({String? token}) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
    return await ApiHelper.get('/decks/list/', headers: headers);
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

// ---- Edit deck ----
static Future<http.Response> editDeck({
  required String token,
  required String deckId,
  required String title,
  required String description,
  required bool isPublic,
  List<Map<String, String>>? cards, // optional: [{question, answer}, ...]
}) async {
  final body = {
    "title": title,
    "description": description,
    "is_public": isPublic,
    if (cards != null) "cards": cards,
  };

  return await ApiHelper.patch(
    '/decks/$deckId/edit/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
    body: jsonEncode(body),
  );
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
      '/flashcards/list/$deckId/',
      headers: headers,
    );
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
    // Try to extract JSON error detail; otherwise fallback to plain text
    try {
      final errorJson = jsonDecode(body);
      final detail = errorJson['detail'] ?? errorJson.toString();
      throw Exception("❌ $action failed (status $status): $detail");
    } catch (_) {
      throw Exception("❌ $action failed (status $status)\nResponse:\n$body");
    }
  }
}

static Future<Map<String, dynamic>> startSession({
  required int deckId,
  required String mode,
  required String token,
}) async {
  final response = await ApiHelper.post(
    '/quiz/start/$deckId/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
    body: jsonEncode({'mode': mode}),
  );
  return _safeJson(response, "Start quiz session");
}

static Future<Map<String, dynamic>> submitAnswer({
  required int sessionId,
  required String answer,
  required String token,
}) async {
  final response = await ApiHelper.post(
    '/quiz/answer/$sessionId/',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    },
    body: jsonEncode({'answer': answer}),
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

}