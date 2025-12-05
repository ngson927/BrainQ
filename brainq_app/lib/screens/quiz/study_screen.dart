import 'dart:math';
import 'package:brainq_app/screens/quiz/deck_screen.dart';
import 'package:flutter/material.dart';
import '../../models/deck.dart';
import '../../models/deck_theme.dart';
import '../../models/flashcard.dart';
import '../../services/api_service.dart';
import '../../api_helper.dart';
import '../quiz/ratings_screen.dart';

class StudyModeScreen extends StatefulWidget {
  final Deck deck;
  final List<Flashcard> cards;
  final DeckTheme deckTheme;

  const StudyModeScreen({
    super.key,
    required this.deck,
    required this.cards,
    required this.deckTheme,
  });

  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen>
    with TickerProviderStateMixin {
  
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _completed = false;
  String? _currentUserId;
  bool _isShuffled = false;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  late List<Flashcard> _originalCards;
  late List<Flashcard> _displayCards;

  @override
  void initState() {
    super.initState();
    _originalCards = List.from(widget.cards);
    _displayCards = List.from(widget.cards);
    _initAnimations();
    _loadUserId();
  }

  void _initAnimations() {
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnimation = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeInOut));
  }

  Future<void> _loadUserId() async {
    _currentUserId = await ApiHelper.getUserId();
    setState(() {});
  }

  @override
  void dispose() {
    _flipController.dispose();
    _slideController.dispose();
    super.dispose();
  }


  void _toggleShuffle() {
    setState(() {
      _isShuffled = !_isShuffled;

      if (_isShuffled) {
        _displayCards = List.from(_displayCards)..shuffle();
      } else {
        _displayCards = List.from(_originalCards);
      }

      _currentIndex = 0;
      _showAnswer = false;
      _completed = false;
      _flipController.reset();
    });
  }

  void _flipCard() {
    if (_flipController.isAnimating || _completed) return;

    if (_showAnswer) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }

    setState(() => _showAnswer = !_showAnswer);
  }

  Future<void> _nextCard() async {
    if (_completed) return;

    if (_currentIndex >= _displayCards.length - 1) {
      setState(() => _completed = true);
      await _updateStreakIfTokenExists();
      return;
    }

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.2, 0),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeInOut));

    await _slideController.forward();
    setState(() {
      _currentIndex++;
      _showAnswer = false;
      _flipController.reset();
    });
    _slideController.reset();
  }

  Future<void> _previousCard() async {
    if (_completed || _currentIndex <= 0) return;

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.2, 0),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeInOut));

    await _slideController.forward();
    setState(() {
      _currentIndex--;
      _showAnswer = false;
      _flipController.reset();
    });
    _slideController.reset();
  }

  Future<void> _updateStreakIfTokenExists() async {
    final token = await ApiHelper.getAuthToken();
    if (token?.isNotEmpty ?? false) {
      try {
        await ApiService.updateStreak(token: token!);
        debugPrint("🔥 Streak updated successfully!");
      } catch (e) {
        debugPrint("⚠️ Failed to update streak: $e");
      }
    } else {
      debugPrint("⚠️ Skipping streak update: auth token not found.");
    }
  }

@override
Widget build(BuildContext context) {
  final theme = widget.deckTheme;

  Color hexOrDefault(String? hex, Color defaultColor) {
    if (hex == null) return defaultColor;
    try {
      return HexColor(hex);
    } catch (_) {
      return defaultColor;
    }
  }

  hexOrDefault(theme.cardColor, Colors.white);
  final textColor = hexOrDefault(theme.textColor, Colors.black);
  final backgroundColor = hexOrDefault(theme.backgroundColor, Colors.white);
  final fontSize = theme.fontSize ?? 22;
  final borderRadius = theme.borderRadius ?? 20;
  final elevation = theme.elevation ?? 8;
  final accentColor = hexOrDefault(theme.accentColor, Colors.deepPurple);

  final card = _displayCards[_currentIndex];


  return Scaffold(
    backgroundColor: backgroundColor,
    appBar: AppBar(
      title: Text(
        "Study: ${widget.deck.title}",
        style: TextStyle(
          color: textColor,
          fontFamily: theme.fontFamily,
        ),
      ),
      backgroundColor: accentColor,
      centerTitle: true,

      actions: [
        IconButton(
          icon: Icon(
            Icons.shuffle,
            color: _isShuffled ? Colors.greenAccent : textColor,
          ),
          onPressed: _toggleShuffle,
          tooltip: _isShuffled ? "Turn Shuffle Off" : "Turn Shuffle On",
        ),
      ],
    ),

    body: Stack(
      children: [
        GestureDetector(
          onTap: _flipCard,
          onHorizontalDragEnd: (details) {
            if (_completed) return;
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < 0) _nextCard();
              if (details.primaryVelocity! > 0) _previousCard();
            }
          },
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_flipAnimation, _slideAnimation]),
              builder: (context, _) {
                final flipValue = _flipAnimation.value;
                final isFront = flipValue < pi / 2;

                final frontColor = accentColor;
                final backColor = accentColor.withValues(alpha:0.95);

                return SlideTransition(
                  position: _slideAnimation,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(flipValue),
                    child: Card(
                      elevation: elevation,
                      color: isFront ? frontColor : backColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: isFront ? Matrix4.identity() : Matrix4.rotationY(pi),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                isFront ? card.question : card.answer,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: fontSize,
                                  fontFamily: theme.fontFamily,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          ),
        ),

        if (_completed)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 80, color: Colors.greenAccent),
                const SizedBox(height: 16),
                Text(
                  "You completed the deck!",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    fontFamily: theme.fontFamily,
                  ),
                ),
                const SizedBox(height: 24),
                if (_currentUserId != null &&
                    widget.deck.ownerId != null &&
                    _currentUserId != widget.deck.ownerId)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.star_rate),
                    label: const Text("Rate This Deck"),
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RatingScreen(deckId: int.parse(widget.deck.id)),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                  onPressed: () {
                    setState(() {
                      _completed = false;
                      _currentIndex = 0;
                      _showAnswer = false;
                      _flipController.reset();
                    });
                  },
                  child: const Text("Restart Deck"),
                ),
              ],
            ),
          ),
      ],
    ),
    bottomNavigationBar: Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor),
            onPressed: _completed ? null : _previousCard,
          ),
          Text(
            "${_currentIndex + 1} / ${_displayCards.length}",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontFamily: theme.fontFamily,
              fontSize: 18,
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: textColor),
            onPressed: _completed ? null : _nextCard,
          ),
        ],
      ),
    ),
  );
}
}