import 'dart:io';

import 'package:brainq_app/models/deck_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/deck_item.dart';
import '../../models/flashcard.dart';
import '../../providers/deck_provider.dart';
import '../../providers/theme_provider.dart';


class CreateDeckScreen extends StatefulWidget {
  final DeckItem? deckToEdit;

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
  File? _deckCoverImage;       
  String? _deckCoverImageUrl;   
  int? _selectedThemeId;
  List<DeckTheme> availableThemes = [];

  @override
  void initState() {
    super.initState();

    // -------------------------
    // Initialize deck fields
    // -------------------------
    if (widget.deckToEdit != null) {
      final deck = widget.deckToEdit!;
      _titleController = TextEditingController(text: deck.title);
      _descriptionController = TextEditingController(text: deck.description);
      _tags = deck.tags.map((t) => t.toString()).toList();
      _visibility = deck.isPublic ? 'Public' : 'Private';

      _cards = deck.cards.isNotEmpty
          ? deck.cards.map((c) => Flashcard(question: c.question, answer: c.answer, options: c.options)).toList()
          : [Flashcard(question: '', answer: ''), Flashcard(question: '', answer: '')];

      _deckCoverImageUrl = deck.coverImageUrl;
      _deckCoverImage = deck.coverImageFile;
      
      // -------------------------
      // Theme: store the selected theme ID as string
      // -------------------------
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _tags = [];
      _visibility = 'Private';
      _cards = [Flashcard(question: '', answer: ''), Flashcard(question: '', answer: '')];
    }


    _selectedThemeId = widget.deckToEdit?.theme?.id;

    // Load available themes
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    availableThemes = List.from(themeProvider.availableThemes);


    // If no theme selected, pick first available or system default
    _selectedThemeId ??= availableThemes.isNotEmpty
          ? availableThemes.first.id
          : DeckTheme.defaultTheme().id;



  }



  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.white;
    return Color(int.parse(hex.replaceFirst('#', '0xff')));
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag.toString()));
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

    final isEditing = widget.deckToEdit != null;

    final selectedThemeObj = availableThemes.firstWhere(
      (t) => t.id == _selectedThemeId,
      orElse: () => DeckTheme.defaultTheme(),
    );



    final deck = DeckItem(
      id: isEditing ? widget.deckToEdit!.id : 0,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      tags: _tags.map((t) => t.toString()).toList(),
      isPublic: _visibility == 'Public',
      cards: nonEmptyCards,
      theme: selectedThemeObj,
      coverImageFile: _deckCoverImage,
      coverImageUrl: _deckCoverImageUrl,
    );



    final deckProvider = Provider.of<DeckProvider>(context, listen: false);

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saving deck...")),
      );

      if (widget.deckToEdit != null) {
        await deckProvider.editDeck(deck);
      } else {
        await deckProvider.createDeck(deck); 
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deck '${deck.title}' saved successfully!")),
      );

      if (!mounted) return;
      Navigator.pop(context, deck);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving deck: $e")),
      );
    }
  }

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

  Future<void> _pickCoverImage() async {
  final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (pickedFile != null) {
    setState(() => _deckCoverImage = File(pickedFile.path));
  }
}


  @override
  Widget build(BuildContext context) {

  final themeProvider = Provider.of<ThemeProvider>(context);
  availableThemes = themeProvider.availableThemes;

  // Determine the selected theme
  late DeckTheme selectedTheme;
  selectedTheme = availableThemes.firstWhere(
    (t) => t.id == _selectedThemeId,
    orElse: () => themeProvider.activeDeckTheme ?? DeckTheme.defaultTheme(),
  );



    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop(result); 
        }
      },
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
                  decoration: const InputDecoration(
                    labelText: "Deck Title",
                    prefixIcon: Icon(Icons.book),
                  ),
                  validator: (v) => v == null || v.isEmpty ? "Enter title" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Description (optional)",
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 12),
                // Tags
                TextFormField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    labelText: "Add Tag",
                    prefixIcon: const Icon(Icons.tag),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _addTag,
                    ),
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
                      onChanged: (val) =>
                          setState(() => _visibility = val ?? 'Private'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("Cover Image", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Center(
                  child: Column(
                    children: [
                      if (_deckCoverImage != null) 
                        Image.file(
                          _deckCoverImage!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        )
                      else if (widget.deckToEdit?.fullCoverImageUrl != null)
                        Image.network(
                          widget.deckToEdit!.fullCoverImageUrl!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        )

                      else
                        Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.photo, size: 50),
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text("Select Cover Image"),
                        onPressed: _pickCoverImage,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                DropdownButton<int>(
                  value: availableThemes.any((t) => t.id == _selectedThemeId)
                      ? _selectedThemeId
                      : null,
                  hint: const Text("Select Theme"),
                  items: availableThemes.map((t) {
                    return DropdownMenuItem<int>(
                      value: t.id,
                      child: Text(t.name ?? 'Unnamed'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedThemeId = val;
                    });
                  },
                ),
                Center(
                  child: Card(
                    color: _hexToColor(selectedTheme.backgroundColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(selectedTheme.borderRadius?.toDouble() ?? 12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(selectedTheme.cardSpacing?.toDouble() ?? 12),
                      child: Text(
                        "Sample Card Preview",
                        style: TextStyle(
                          color: _hexToColor(selectedTheme.textColor),
                          fontSize: selectedTheme.fontSize?.toDouble() ?? 16,
                          fontFamily: selectedTheme.fontFamily,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                // Flashcards
                const Text("Flashcards",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      color: _hexToColor(selectedTheme.backgroundColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(selectedTheme.borderRadius?.toDouble() ?? 12),
                      ),
                      elevation: 3,
                      margin: EdgeInsets.symmetric(vertical: (selectedTheme.cardSpacing?.toDouble() ?? 6)),
                      child: Padding(
                        padding: EdgeInsets.all(selectedTheme.cardSpacing?.toDouble() ?? 12),
                        child: Column(
                          children: [
                            TextFormField(
                              initialValue: card.question,
                              style: TextStyle(
                                color: _hexToColor(selectedTheme.textColor),
                                fontSize: selectedTheme.fontSize?.toDouble() ?? 16,
                                fontFamily: selectedTheme.fontFamily,
                              ),
                              decoration: InputDecoration(
                                labelText: "Question ${index + 1}",
                                labelStyle: TextStyle(color: _hexToColor(selectedTheme.accentColor)),
                              ),
                              onChanged: (v) => card.question = v,
                              validator: (v) => v == null || v.isEmpty ? "Enter question" : null,
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: card.answer,
                              style: TextStyle(
                                color: _hexToColor(selectedTheme.textColor),
                                fontSize: selectedTheme.fontSize?.toDouble() ?? 16,
                                fontFamily: selectedTheme.fontFamily,
                              ),
                              decoration: InputDecoration(
                                labelText: "Answer ${index + 1}",
                                labelStyle: TextStyle(color: _hexToColor(selectedTheme.accentColor)),
                              ),
                              onChanged: (v) => card.answer = v,
                              validator: (v) => v == null || v.isEmpty ? "Enter answer" : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: Icon(Icons.delete, color: _hexToColor(selectedTheme.accentColor)),
                                onPressed: () => _removeCard(index),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                  },
                ),
                TextButton.icon(
                    onPressed: _addCard,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Flashcard")),
                const SizedBox(height: 20),
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Save Deck"),
                    onPressed: _saveDeck,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white),
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
