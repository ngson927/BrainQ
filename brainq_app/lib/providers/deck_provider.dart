import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck_item.dart';
import '../models/flashcard.dart';
import '../services/api_service.dart';

class DeckProvider with ChangeNotifier {
  final List<DeckItem> _decks = [];
  String? _authToken;
  String? _userId;

  List<DeckItem> get decks => List.unmodifiable(_decks);
  String? get authToken => _authToken;
  String? get userId => _userId;

  void setAuth({required String token, required String userId}) {
    _authToken = token;
    _userId = userId;
  }

  void clearAuth() {
    _authToken = null;
    _userId = null;
    _decks.clear();
    notifyListeners();
  }

  // ---- Fetch decks ----
  Future<void> fetchDecks() async {
    if (_authToken == null) return;
    try {
      final res = await ApiService.listDecks(token: _authToken!);
      if (res.statusCode != 200) return;

      final List data = jsonDecode(res.body);
      _decks
        ..clear()
        ..addAll(data.map((d) {
          final ownerId = d['owner_id']?.toString();
          final isPublic = d['is_public'] ?? false;

          if (ownerId == _userId || isPublic) {
            return DeckItem(
              id: int.tryParse(d['id'].toString()) ?? DateTime.now().millisecondsSinceEpoch,
              title: d['title'] ?? '',
              description: d['description'] ?? '',
              tags: List<String>.from(d['tags'] ?? []),
              ownerId: ownerId,
              isPublic: isPublic,
              cards: (d['flashcards'] as List<dynamic>? ?? [])
                  .map((c) => Flashcard.fromBackendJson(c))
                  .toList(),
            );
          }
          return null;
        }).whereType<DeckItem>());

      await loadRecents();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching decks: $e");
    }
  }

  // ---- Recents ----
  Future<void> loadRecents() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final recentIds = prefs.getStringList('recentDecks_$_userId') ?? [];
    for (final deck in _decks) {
      deck.recentlyUsed = recentIds.contains(deck.id.toString());
    }
  }

  Future<void> saveRecents() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final recentIds = _decks.where((d) => d.recentlyUsed).map((d) => d.id.toString()).toList();
    await prefs.setStringList('recentDecks_$_userId', recentIds);
  }

  List<DeckItem> get userDecks {
    if (_userId == null) return [];
    return _decks.where((d) => d.ownerId == _userId).toList();
  }

  // ---- Create deck ----
  Future<void> createDeck(DeckItem deck) async {
    if (_authToken == null || _userId == null) return;

    try {
      final deckRes = await ApiService.createDeck(
        token: _authToken!,
        title: deck.title,
        description: deck.description,
        isPublic: deck.isPublic,
      );
      if (deckRes.statusCode != 201) throw Exception("Failed to create deck");

      final deckData = jsonDecode(deckRes.body);
      final deckId = int.tryParse(deckData['id'].toString()) ?? DateTime.now().millisecondsSinceEpoch;

      // Create flashcards and assign IDs from backend
      for (var i = 0; i < deck.cards.length; i++) {
        final card = deck.cards[i];
        final flashRes = await ApiService.createFlashcard(
          token: _authToken!,
          deckId: deckId.toString(),
          question: card.question,
          answer: card.answer,
        );
        if (flashRes.statusCode == 201) {
          final flashData = jsonDecode(flashRes.body);
          card.id = flashData['id'] as int?;
          card.isNew = false;
        }
      }

      _decks.add(deck.copyWith(id: deckId, ownerId: _userId, cards: deck.cards));
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error creating deck: $e");
      rethrow;
    }
  }

Future<void> editDeck(DeckItem deck) async {
  if (_authToken == null || _userId == null) return;
  if (deck.id == 0) throw Exception("Deck ID is required");

  try {
    // PATCH deck info on backend
    final res = await ApiService.editDeck(
      token: _authToken!,
      deckId: deck.id.toString(),
      title: deck.title,
      description: deck.description,
      isPublic: deck.isPublic,
    );

    if (res.statusCode != 200) throw Exception("Failed to edit deck");

    // Sync flashcards: create new ones and preserve existing ones
    final deckIndex = _decks.indexWhere((d) => d.id == deck.id);
    if (deckIndex == -1) return;

    final updatedCards = <Flashcard>[];

    for (var card in deck.cards) {
      // Only create new cards on backend
      if (card.isNew) {
        final flashRes = await ApiService.createFlashcard(
          token: _authToken!,
          deckId: deck.id.toString(),
          question: card.question,
          answer: card.answer,
        );
        if (flashRes.statusCode == 201) {
          final flashData = jsonDecode(flashRes.body);
          card.id = flashData['id'] as int?;
          card.isNew = false;
        }
      }
      // Add to updated list, no duplicates
      updatedCards.add(card);
    }

    // Replace deck cards and notify UI
    final updatedDeck = deck.copyWith(cards: updatedCards);
    _decks[deckIndex] = updatedDeck;
    notifyListeners();
  } catch (e) {
    debugPrint("❌ Error editing deck: $e");
    rethrow;
  }
}


  void removeDeck(int id) {
    _decks.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  void clear() {
    _decks.clear();
    notifyListeners();
  }

  // ---- Delete flashcard ----
Future<void> deleteFlashcard(String deckId, Flashcard card) async {
  if (_authToken == null) return;

  try {
    // Delete from backend if it exists remotely
    if (!card.isNew && card.id != null) {
      final res = await ApiService.deleteFlashcard(
        token: _authToken!,
        flashcardId: card.id!,
      );
      if (res.statusCode != 204) {
        throw Exception('Failed to delete flashcard on backend');
      }
    }

    // Remove locally by ID or by content if unsynced
    final deckIndex = _decks.indexWhere((d) => d.id.toString() == deckId);
    if (deckIndex != -1) {
      _decks[deckIndex].cards.removeWhere(
        (c) => c.id == card.id || (c.isNew && c.question == card.question && c.answer == card.answer)
      );
      notifyListeners(); // Only once at the end
    }
  } catch (e) {
    debugPrint("❌ Error deleting flashcard: $e");
    rethrow;
  }
}


}
