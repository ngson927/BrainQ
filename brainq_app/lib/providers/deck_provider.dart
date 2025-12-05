import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brainq_app/models/deck_theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/deck_item.dart';
import '../models/flashcard.dart';
import '../services/api_service.dart';

class DeckProvider with ChangeNotifier {

  final List<DeckItem> _decks = [];
  final List<DeckItem> _archivedDecks = [];
  final List<DeckItem> _recents = [];

  String? _authToken;
  String? _userId;

  DeckItem? _selectedDeck;

  List<DeckItem> get decks => List.unmodifiable(_decks);
  List<DeckItem> get archivedDecks => List.unmodifiable(_archivedDecks);
  List<DeckItem> get recents => List.unmodifiable(_recents);


  String? get token => _authToken;
  String? get userId => _userId;

  DeckItem? get selectedDeck => _selectedDeck;
  set selectedDeck(DeckItem? deck) {
    _selectedDeck = deck;
    notifyListeners();
  }


  // ------------------------------------------------------------
  // AUTH
  // ------------------------------------------------------------

  void setAuth({required String token, required String userId}) {
    _authToken = token;
    _userId = userId;

  }


  void clearAuth() {
    _authToken = null;
    _userId = null;
    _decks.clear();
    _archivedDecks.clear();
    _recents.clear();
    _selectedDeck = null;
    notifyListeners();
  }




  // After fetchDecks, reconcile recents so that recents contain latest server fields.
  void _reconcileRecentsWithServer() {
    for (int i = 0; i < _recents.length; i++) {
      final rid = _recents[i].id;
      final serverIdx = _decks.indexWhere((d) => d.id == rid);
      if (serverIdx != -1) {
        _recents[i] = _decks[serverIdx];
      } else {
        // maybe it's archived -> check archived list
        final aidx = _archivedDecks.indexWhere((d) => d.id == rid);
        if (aidx != -1) {
          _recents[i] = _archivedDecks[aidx];
        }
      }
    }
  }

  // Save recents to shared prefs
  Future<void> _saveRecents() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_recents.map((d) => d.toJson()).toList());
    await prefs.setString("recentDecks_$_userId", encoded);
  }

  // Load recents from shared prefs
  Future<void> _loadRecents() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("recentDecks_$_userId");
    _recents.clear();
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _recents.addAll(
        decoded.whereType<Map<String, dynamic>>().map((d) => DeckItem.fromJson(d)),
      );
    } catch (e) {
      debugPrint("⚠️ Failed to parse recents: $e");
      _recents.clear();
    }
  }

  // Ensure recents do not contain archived decks.
  void _pruneRecents() {
    _recents.removeWhere((d) => d.archived == true);
  }

  // ---------------------------------------------------------------------------
  // FETCH DECKS
  // ---------------------------------------------------------------------------

  Future<void> fetchDecks() async {
    if (_authToken == null) return;
    try {
      final res = await ApiService.listDecks(token: _authToken!);
      if (res.statusCode != 200) return;

      final raw = jsonDecode(res.body);
      if (raw is! List) return;

      _decks
        ..clear()
        ..addAll(raw.map((d) => DeckItem.fromBackendJson(d)));

      // Fetch archived separately
      await fetchArchivedDecks();

      // Load recents from storage and reconcile with fetched decks
      await _loadRecents();
      _reconcileRecentsWithServer();

      _pruneRecents();

      notifyListeners();
    } catch (e) {
      debugPrint("❌ fetchDecks error: $e");
    }
  }

  void applyThemeFromDeck(DeckTheme? theme) {
  if (_selectedDeck == null || theme == null) return;

  _selectedDeck = _selectedDeck!.copyWith(theme: theme);
  notifyListeners();
}


  // ---------------------------------------------------------------------------
  // ARCHIVED DECKS
  // ---------------------------------------------------------------------------

  Future<void> fetchArchivedDecks() async {
    if (_authToken == null) return;

    try {
      final res = await ApiService.listArchivedDecks(token: _authToken!);
      if (res.statusCode != 200) return;

      final raw = jsonDecode(res.body);
      if (raw is! List) return;

      _archivedDecks
        ..clear()
        ..addAll(raw.map((d) => DeckItem.fromBackendJson(d)));

      notifyListeners();
    } catch (e) {
      debugPrint("❌ fetchArchivedDecks error: $e");
    }
  }

  Future<void> toggleArchiveDeck(DeckItem deck) async {
    if (_authToken == null) return;

    try {
      final res = await ApiService.toggleArchiveDeck(
        token: _authToken!,
        deckId: deck.id,
      );

      if (res.statusCode != 200) {
        throw Exception("Failed to toggle archive");
      }

      final data = jsonDecode(res.body);

      // Find the existing deck (from active or archived)
      final existingDeckIndex = _decks.indexWhere((d) => d.id == deck.id);
      final existingDeck = existingDeckIndex != -1
          ? _decks[existingDeckIndex]
          : _archivedDecks.firstWhere((d) => d.id == deck.id);

      // Create updated deck by merging existing with backend changes
      final updatedDeck = existingDeck.copyWith(
        isArchived: data['is_archived'] ?? existingDeck.isArchived,
        isPublic: data['is_public'] ?? existingDeck.isPublic,
      );

      // Remove old deck from both lists
      _decks.removeWhere((d) => d.id == updatedDeck.id);
      _archivedDecks.removeWhere((d) => d.id == updatedDeck.id);

      // Insert into correct list
      if (updatedDeck.archived) {
        _archivedDecks.insert(0, updatedDeck);
      } else {
        _decks.insert(0, updatedDeck);
      }

      // Update recents
      final ridx = _recents.indexWhere((d) => d.id == updatedDeck.id);
      if (ridx != -1) _recents[ridx] = updatedDeck;

      _pruneRecents();
      await _saveRecents();

      notifyListeners();
    } catch (e) {
      debugPrint("❌ toggleArchiveDeck error: $e");
    }
  }



  // ---------------------------------------------------------------------------
  // RECENTS
  // ---------------------------------------------------------------------------

  Future<void> markDeckRecent(DeckItem deck) async {
    DeckItem toStore = deck;
    final serverIdx = _decks.indexWhere((d) => d.id == deck.id);
    if (serverIdx != -1) toStore = _decks[serverIdx];

    if (toStore.archived) return;

    _recents.removeWhere((d) => d.id == toStore.id);
    _recents.insert(0, toStore);

    if (_recents.length > 20) _recents.removeLast();


    final idx = _decks.indexWhere((d) => d.id == toStore.id);
    if (idx != -1) {
      _decks[idx] = toStore;
    }

    _pruneRecents();
    await _saveRecents();
    notifyListeners();
  }


  // ---------------------------------------------------------------------------
  // CREATE DECK
  // ---------------------------------------------------------------------------

  Future<DeckItem> createDeck(
    DeckItem deck, {
    String? cardOrder,
    Map<String, dynamic>? theme,
    bool saveAsNewTheme = false,
    File? coverImageFile,
  }) async {
    if (_authToken == null || _userId == null) throw Exception("No auth");

    try {
      final res = await ApiService.createDeck(
        token: _authToken!,
        title: deck.title,
        description: deck.description,
        isPublic: deck.isPublic,
        tags: deck.tags.whereType<String>().toList(),
        cardOrder: cardOrder,
        theme: deck.theme?.toJson(),
        saveAsNewTheme: saveAsNewTheme,
        coverImageFile: coverImageFile,
        cards: deck.cards
            .where((c) => c.question.isNotEmpty && c.answer.isNotEmpty)
            .map((c) => c.toBackendJson())
            .toList(),
      );

      if (res.statusCode != 201) {
        final errorBody = await _streamToString(res);
        throw Exception("Create deck failed: $errorBody");
      }

      final body = await _streamToString(res);
      final newDeck = DeckItem.fromBackendJson(jsonDecode(body));

      _decks.insert(0, newDeck);

      _recents.removeWhere((d) => d.id == newDeck.id);
      _recents.insert(0, newDeck);
      if (_recents.length > 20) _recents.removeLast();
      await _saveRecents();

      notifyListeners();
      return newDeck;
    } catch (e) {
      debugPrint("❌ createDeck error: $e");
      rethrow;
    }
  }



  Future<DeckItem> editDeck(
    DeckItem deck, {
    String? cardOrder,
    File? coverImageFile,
  }) async {
    if (_authToken == null || _userId == null) throw Exception("No auth");

    try {
      final res = await ApiService.editDeck(
        token: _authToken!,
        deckId: deck.id,
        title: deck.title,
        description: deck.description,
        isPublic: deck.isPublic,
        tags: deck.tags.whereType<String>().toList(),
        cardOrder: cardOrder,
        coverImageFile: coverImageFile,
        cards: deck.cards
            .where((c) => c.question.isNotEmpty && c.answer.isNotEmpty)
            .map((c) => c.toBackendJson())
            .toList(),
        theme: deck.theme?.toJson(),
      );

      if (res.statusCode != 200) {
        final errBody = await _streamToString(res);
        throw Exception("Edit deck failed: $errBody");
      }

      final body = await _streamToString(res);
      final updated = DeckItem.fromBackendJson(jsonDecode(body));

      final idx = _decks.indexWhere((d) => d.id == updated.id);
      if (idx != -1) {
        _decks[idx] = updated;
      } else {
        final aidx = _archivedDecks.indexWhere((d) => d.id == updated.id);
        if (aidx != -1) _archivedDecks[aidx] = updated;
      }

      final ridx = _recents.indexWhere((d) => d.id == updated.id);
      if (ridx != -1) {
        _recents[ridx] = updated;
        await _saveRecents();
      }

      if (_selectedDeck?.id == updated.id) _selectedDeck = updated;

      notifyListeners();
      return updated;
    } catch (e) {
      debugPrint("❌ editDeck error: $e");
      rethrow;
    }
  }


  Future<Map<String, dynamic>?> fetchDeckTheme(int deckId) async {
    if (_authToken == null) return null;

    final res = await ApiService.getDeckTheme(
      token: _authToken!,
      deckId: deckId,
    );

    if (res.statusCode != 200) return null;
    return jsonDecode(res.body);
  }

  Future<bool> customizeDeckTheme(
    int deckId, {
    Map<String, dynamic>? themeData,
    bool saveAsNew = false,
    bool resetToDefault = false,
    int? themeId,
  }) async {
    if (_authToken == null) return false;

    final res = await ApiService.customizeDeckTheme(
      token: _authToken!,
      deckId: deckId,
      themeData: themeData,
      saveAsNew: saveAsNew,
      resetToDefault: resetToDefault,
      themeId: themeId,
    );

    return res.statusCode == 200;
  }


  // ---------------------------------------------------------------------------
  // DELETE DECK
  // ---------------------------------------------------------------------------

  Future<void> deleteDeck(int deckId) async {
    if (_authToken == null) return;

    try {
      final res = await ApiService.deleteDeck(
        token: _authToken!,
        deckId: deckId,
      );

      if (res.statusCode != 204) {
        throw Exception("Delete deck failed");
      }

      _decks.removeWhere((d) => d.id == deckId);
      _archivedDecks.removeWhere((d) => d.id == deckId);
      _recents.removeWhere((d) => d.id == deckId);

      await _saveRecents();

      if (_selectedDeck?.id == deckId) _selectedDeck = null;

      notifyListeners();
    } catch (e) {
      debugPrint("❌ deleteDeck error: $e");
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // FLASHCARD OPERATIONS
  // ---------------------------------------------------------------------------

  Future<void> deleteFlashcard(String deckId, Flashcard card) async {
    if (_authToken == null) return;

    try {
      if (!card.isNew && card.id != null) {
        final res = await ApiService.deleteFlashcard(token: _authToken!, flashcardId: card.id!);

        if (res.statusCode != 204) {
          throw Exception("Backend failed to delete flashcard");
        }
      }

      final idx = _decks.indexWhere((d) => d.id.toString() == deckId);
      if (idx != -1) {
        _decks[idx].cards.removeWhere((c) => c.id == card.id);
      }

      notifyListeners();

      // refresh lists to ensure eventual consistency
      await fetchDecks();
    } catch (e) {
      debugPrint("❌ deleteFlashcard error: $e");
      rethrow;
    }
  }
  Future<String> _streamToString(http.StreamedResponse response) async {
  return await response.stream.bytesToString();
}

void addDeck(DeckItem deck) {
  _decks.insert(0, deck);
  notifyListeners();
}

}
