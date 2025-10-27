import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/deck.dart';
import '../../models/flashcard.dart';

class StudyModeScreen extends StatefulWidget {
  final Deck deck;
  final List<Flashcard> cards;

  const StudyModeScreen({
    super.key,
    required this.deck,
    required this.cards,
  });

  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showAnswer = false;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  bool _completed = false;

  @override
  void initState() {
    super.initState();

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

  @override
  void dispose() {
    _flipController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;

    if (_showAnswer) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }

    setState(() => _showAnswer = !_showAnswer);
  }

  Future<void> _nextCard() async {
    if (_currentIndex >= widget.cards.length - 1) {
      setState(() => _completed = true);
      return;
    }

    // Slide left for next
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
    if (_currentIndex <= 0) return;

    // Slide right for previous
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final card = widget.cards[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text("Study: ${widget.deck.title}"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: _flipCard,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < 0) {
                  _nextCard();
                } else if (details.primaryVelocity! > 0) {
                  _previousCard();
                }
              }
            },
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_flipAnimation, _slideAnimation]),
                builder: (context, _) {
                  final flipValue = _flipAnimation.value;
                  final isFront = flipValue < pi / 2;

                  return SlideTransition(
                    position: _slideAnimation,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(flipValue),
                      child: Card(
                        elevation: 8,
                        color: isFront
                            ? colorScheme.surface
                            : colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Transform(
                              alignment: Alignment.center,
                              transform:
                                  isFront ? Matrix4.identity() : Matrix4.rotationY(pi),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  isFront ? card.question : card.answer,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22,
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
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _completed = false;
                        _currentIndex = 0;
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
        color: colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: _previousCard,
              tooltip: "Previous Card",
            ),
            Text(
              "${_currentIndex + 1} / ${widget.cards.length}",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: _nextCard,
              tooltip: "Next Card",
            ),
          ],
        ),
      ),
    );
  }
}
