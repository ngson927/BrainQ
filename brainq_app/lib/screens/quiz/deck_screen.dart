import 'package:brainq_app/providers/auth_provider.dart';
import 'package:brainq_app/screens/quiz/quiz_screen.dart'; // ✅ ApiQuizScreen + QuizMode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flashcard.dart';
import '../../models/deck_item.dart';
import '../../providers/deck_provider.dart';
import 'study_screen.dart';

class DeckScreen extends StatefulWidget {
  final DeckItem deck;
  final bool editMode;

  const DeckScreen({super.key, required this.deck, this.editMode = false});

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  late List<Flashcard> cards;
  late TextEditingController titleController;
  late TextEditingController descController;

  @override
  void initState() {
    super.initState();
    cards = List.from(widget.deck.cards);
    titleController = TextEditingController(text: widget.deck.title);
    descController = TextEditingController(text: widget.deck.description);
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    super.dispose();
  }

  // ---------------------------- QUIZ MODES ----------------------------
  void _showQuizModeSelector() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Select Quiz Mode", style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.sort),
              label: const Text("Sequential"),
              onPressed: () {
                Navigator.pop(context);
                _startApiQuiz(mode: QuizMode.sequential);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.shuffle),
              label: const Text("Random"),
              onPressed: () {
                Navigator.pop(context);
                _startApiQuiz(mode: QuizMode.random);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.timer),
              label: const Text("Timed Mode"),
              onPressed: () async {
                Navigator.pop(context);
                final selectedSeconds = await showDialog<int>(
                  context: context,
                  builder: (ctx) {
                    int tempSelection = 15;
                    return AlertDialog(
                      title: const Text("Select Timer Duration"),
                      content: StatefulBuilder(
                        builder: (context, setState) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [10, 15, 20, 30].map((sec) {
                            return RadioListTile<int>(
                              title: Text("$sec seconds"),
                              value: sec,
                              groupValue: tempSelection,
                              onChanged: (val) => setState(() => tempSelection = val!),
                            );
                          }).toList(),
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                        ElevatedButton(onPressed: () => Navigator.pop(ctx, tempSelection), child: const Text("Confirm")),
                      ],
                    );
                  },
                );

                if (selectedSeconds != null) {
                  _startApiQuiz(mode: QuizMode.timed, timerSeconds: selectedSeconds);
                }
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }

  void _startApiQuiz({required QuizMode mode, int? timerSeconds}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (widget.deck.cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This deck has no flashcards. Add some before starting a quiz.")),
      );
      return;
    }

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to start the quiz.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApiQuizScreen(
          deckItem: widget.deck,
          token: token,
          mode: mode,
          initialTime: timerSeconds,
        ),
      ),
    );
  }

  // ---------------------------- STUDY MODE ----------------------------
  void _openStudyMode() {
    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No flashcards in this deck yet.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudyModeScreen(
          deck: widget.deck.toDeckModel(),
          cards: cards,
        ),
      ),
    );
  }

  // ---------------------------- EDIT & SAVE ----------------------------
  void _addFlashcard() {
    setState(() {
      cards.add(Flashcard(
        question: "New Question",
        answer: "New Answer",
        isNew: true,
      ));
    });
  }

  void _editFlashcard(int index) async {
    final updated = await Navigator.push<Flashcard>(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardEditorScreen(flashcard: cards[index]),
      ),
    );

    if (updated != null) {
      setState(() {
        updated.isNew = cards[index].isNew || updated.isNew;
        updated.id = cards[index].id;
        cards[index] = updated;
      });
    }
  }

  void _deleteFlashcard(int index) async {
    final deckProv = Provider.of<DeckProvider>(context, listen: false);
    final card = cards[index];

    setState(() => cards.removeAt(index)); // Optimistic UI update

    try {
      await deckProv.deleteFlashcard(widget.deck.id.toString(), card);
    } catch (e) {
      debugPrint("Error deleting flashcard: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete flashcard.")),
      );
      setState(() => cards.insert(index, card)); // rollback
    }
  }

  void _saveDeck() async {
    final deckProv = Provider.of<DeckProvider>(context, listen: false);

    final updatedDeck = widget.deck.copyWith(
      title: titleController.text,
      description: descController.text,
      cards: cards.map((c) => c.copyWith(isNew: c.isNew)).toList(),
    );

    try {
      if (widget.editMode) {
        await deckProv.editDeck(updatedDeck);
      } else {
        await deckProv.createDeck(updatedDeck);
      }
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save deck.")),
      );
    }
  }

  // ---------------------------- UI ----------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editMode ? "Edit Deck" : widget.deck.title),
        actions: [
          if (widget.editMode)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveDeck,
            ),
          if (!widget.editMode) ...[
            IconButton(
              icon: const Icon(Icons.menu_book_rounded),
              onPressed: _openStudyMode,
              tooltip: "Study Mode",
            ),
            IconButton(
              icon: const Icon(Icons.quiz),
              onPressed: cards.isEmpty ? null : _showQuizModeSelector,
              tooltip: "Start Quiz",
              color: cards.isEmpty ? Colors.grey : null,
            ),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.editMode)
              TextField(
                controller: titleController,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: "Deck Title",
                  border: OutlineInputBorder(),
                ),
              ),
            if (!widget.editMode) ...[
              Text(widget.deck.title,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 22)),
              const SizedBox(height: 8),
              Text(widget.deck.description,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: cards.length,
                itemBuilder: (_, i) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(cards[i].question),
                    subtitle: Text(cards[i].answer),
                    trailing: widget.editMode
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editFlashcard(i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteFlashcard(i),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
            ),
            if (widget.editMode)
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Add Flashcard"),
                onPressed: _addFlashcard,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------- FLASHCARD EDITOR ----------------------------
class FlashcardEditorScreen extends StatefulWidget {
  final Flashcard flashcard;

  const FlashcardEditorScreen({super.key, required this.flashcard});

  @override
  State<FlashcardEditorScreen> createState() => _FlashcardEditorScreenState();
}

class _FlashcardEditorScreenState extends State<FlashcardEditorScreen> {
  late TextEditingController questionController;
  late TextEditingController answerController;

  @override
  void initState() {
    super.initState();
    questionController = TextEditingController(text: widget.flashcard.question);
    answerController = TextEditingController(text: widget.flashcard.answer);
  }

  @override
  void dispose() {
    questionController.dispose();
    answerController.dispose();
    super.dispose();
  }

  void _saveFlashcard() {
    final updated = Flashcard(
      question: questionController.text,
      answer: answerController.text,
      isNew: widget.flashcard.isNew,
      id: widget.flashcard.id,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Flashcard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveFlashcard,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: questionController,
              decoration: const InputDecoration(labelText: "Question"),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: answerController,
              decoration: const InputDecoration(labelText: "Answer"),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
