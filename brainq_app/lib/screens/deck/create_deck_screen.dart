import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/deck_item.dart';
import '../../models/flashcard.dart';
import '../../providers/deck_provider.dart';

class CreateDeckScreen extends StatefulWidget {
  final DeckItem? deckToEdit; // optional for editing

  const CreateDeckScreen({super.key, this.deckToEdit});

  @override
  State<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends State<CreateDeckScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _tagController = TextEditingController();
  late List<String> _tags;
  late String _visibility;
  late List<Flashcard> _cards;

  @override
  void initState() {
    super.initState();

    if (widget.deckToEdit != null) {
      final deck = widget.deckToEdit!;
      _titleController = TextEditingController(text: deck.title);
      _descriptionController = TextEditingController(text: deck.description);
      _tags = List.from(deck.tags);
      _visibility = deck.isPublic ? 'Public' : 'Private';
      _cards = deck.cards.isNotEmpty
          ? deck.cards.map((c) => Flashcard(question: c.question, answer: c.answer, options: c.options)).toList()
          : [Flashcard(question: '', answer: ''), Flashcard(question: '', answer: '')];
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _tags = [];
      _visibility = 'Private';
      _cards = [Flashcard(question: '', answer: ''), Flashcard(question: '', answer: '')];
    }
  }

  // --- Tag/Card helpers ---
  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
      _tagController.clear();
    }
  }

  void _addCard() => setState(() => _cards.add(Flashcard(question: '', answer: '')));
  void _removeCard(int index) => setState(() => _cards.removeAt(index));

  // --- Save ---
  void _saveDeck() async {
    if (!_formKey.currentState!.validate()) return;

    final nonEmptyCards =
        _cards.where((c) => c.question.isNotEmpty && c.answer.isNotEmpty).toList();
    if (nonEmptyCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add at least one flashcard")),
      );
      return;
    }

    final deck = DeckItem(
      id: widget.deckToEdit?.id, // important for editing
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      tags: _tags,
      isPublic: _visibility == 'Public',
      cards: nonEmptyCards,
    );

    final deckProvider = Provider.of<DeckProvider>(context, listen: false);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saving deck...")),
      );

      if (widget.deckToEdit != null) {
        await deckProvider.editDeck(deck); // PATCH to backend
      } else {
        await deckProvider.createDeck(deck); // POST to backend
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deck '${deck.title}' saved successfully!")),
      );

      Navigator.pop(context, deck); // return the deck for updates
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving deck: $e")),
      );
    }
  }

  // --- Unsaved changes warning ---
  bool get _hasUnsavedContent {
    return _titleController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty ||
        _tags.isNotEmpty ||
        _cards.any((c) => c.question.isNotEmpty || c.answer.isNotEmpty);
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedContent) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Discard Deck?"),
        content: const Text("You have unsaved changes. Are you sure you want to leave?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Discard", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.deckToEdit != null ? "Edit Deck" : "Create Deck"),
          backgroundColor: AppColors.primary,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Description
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: "Deck Title", prefixIcon: Icon(Icons.book)),
                  validator: (v) => v == null || v.isEmpty ? "Enter title" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Description (optional)", prefixIcon: Icon(Icons.description)),
                ),
                const SizedBox(height: 12),
                // Tags
                TextFormField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    labelText: "Add Tag",
                    prefixIcon: const Icon(Icons.tag),
                    suffixIcon: IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _addTag),
                  ),
                  onFieldSubmitted: (_) => _addTag(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _tags.map((t) => Chip(
                        label: Text(t, style: const TextStyle(color: Colors.white)),
                        backgroundColor: AppColors.primary,
                        onDeleted: () => setState(() => _tags.remove(t)),
                      )).toList(),
                ),
                const SizedBox(height: 12),
                // Visibility
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Visibility:"),
                    DropdownButton<String>(
                      value: _visibility,
                      items: const [
                        DropdownMenuItem(value: 'Private', child: Text('Private')),
                        DropdownMenuItem(value: 'Public', child: Text('Public')),
                      ],
                      onChanged: (val) => setState(() => _visibility = val ?? 'Private'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Flashcards
                const Text("Flashcards", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cards.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final card = _cards.removeAt(oldIndex);
                      _cards.insert(newIndex, card);
                    });
                  },
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    return Card(
                      key: ValueKey(card),
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextFormField(
                              initialValue: card.question,
                              decoration: InputDecoration(labelText: "Question ${index + 1}"),
                              onChanged: (v) => card.question = v,
                              validator: (v) => v == null || v.isEmpty ? "Enter question" : null,
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: card.answer,
                              decoration: InputDecoration(labelText: "Answer ${index + 1}"),
                              onChanged: (v) => card.answer = v,
                              validator: (v) => v == null || v.isEmpty ? "Enter answer" : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeCard(index)),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
                TextButton.icon(onPressed: _addCard, icon: const Icon(Icons.add), label: const Text("Add Flashcard")),
                const SizedBox(height: 20),
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Save Deck"),
                    onPressed: _saveDeck,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
