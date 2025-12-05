import 'dart:io';

import 'package:brainq_app/providers/auth_provider.dart';
import 'package:brainq_app/screens/quiz/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/deck_theme.dart';
import '../../models/flashcard.dart';
import '../../models/deck_item.dart';
import '../../providers/deck_provider.dart';
import '../../providers/theme_provider.dart';
import '../AI/ai_chat_screen.dart';
import '../deck_customize_screen.dart';
import 'ratings_screen.dart';
import 'study_screen.dart';

class DeckScreen extends StatefulWidget {
  final DeckItem deck;
  final bool editMode;
  final bool forceDirty;

  const DeckScreen({
    super.key,
    required this.deck,
    this.editMode = false,
    this.forceDirty = false,
  });

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  late DeckItem editableDeck;
  late List<Flashcard> cards;

  late TextEditingController titleController;
  late TextEditingController descController;

  final Map<int, TextEditingController> questionControllers = {};
  final Map<int, TextEditingController> answerControllers = {};
  bool unsavedChanges = false;

  late bool isEditing;
  late bool canEdit;
  int? _selectedThemeId;
  List<DeckTheme> availableThemes = [];   // available themes from provider
  late String? _coverImageUrl;
  File? _coverImageFile;




  @override
  void initState() {
    super.initState();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    canEdit = widget.deck.ownerId == authProvider.userId;

    isEditing = widget.editMode && canEdit;
    if (widget.forceDirty && canEdit) {
      isEditing = true;
      unsavedChanges = true;
    }

    editableDeck = widget.deck.copyWith();
    cards = List.from(widget.deck.cards);

    titleController = TextEditingController(text: editableDeck.title);
    descController = TextEditingController(text: editableDeck.description);

    _initFlashcardControllers();

 
    _coverImageUrl = editableDeck.coverImageUrl;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    availableThemes = List.from(themeProvider.availableThemes);



    _selectedThemeId = editableDeck.theme?.id;

    if (_selectedThemeId == null && availableThemes.isNotEmpty) {
      _selectedThemeId = availableThemes.first.id;
    }

  }

  void _initFlashcardControllers() {
    for (var i = 0; i < cards.length; i++) {
      questionControllers[i] = TextEditingController(text: cards[i].question);
      answerControllers[i] = TextEditingController(text: cards[i].answer);
    }
  }

  void _rebuildFlashcardControllers() {
    final newQ = <int, TextEditingController>{};
    final newA = <int, TextEditingController>{};

    for (int i = 0; i < cards.length; i++) {
      newQ[i] = questionControllers[i] ?? TextEditingController(text: cards[i].question);
      newA[i] = answerControllers[i] ?? TextEditingController(text: cards[i].answer);
    }

    questionControllers
      ..clear()
      ..addAll(newQ);

    answerControllers
      ..clear()
      ..addAll(newA);
  }



  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    for (final c in questionControllers.values) {
      c.dispose();
    }
    for (final c in answerControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _markUnsaved() => setState(() => unsavedChanges = true);

  DeckTheme get selectedTheme {
    return availableThemes.firstWhere(
      (t) => t.id == _selectedThemeId,
      orElse: () => DeckTheme(
        id: 0,
        name: "Default",
        cardColor: "#FFFFFF",
        textColor: "#000000",
        fontSize: 16,
        cardSpacing: 12,
      ),
    );
  }


  // ---------------------------- FLASHCARDS ----------------------------
  void _addFlashcard() {
    if (!canEdit) return;

    setState(() {
      final newCard = Flashcard(question: "", answer: "", isNew: true);
      cards.add(newCard);
      final index = cards.length - 1;
      questionControllers[index] = TextEditingController();
      answerControllers[index] = TextEditingController();
      _markUnsaved();
    });
  }

  Future<void> _deleteFlashcard(int index, Flashcard card) async {
    if (!canEdit) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Flashcard"),
        content: const Text("Are you sure you want to delete this flashcard?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final deckProv = Provider.of<DeckProvider>(context, listen: false);

      await deckProv.deleteFlashcard(editableDeck.id.toString(), card);

      setState(() {
        cards.removeAt(index);

        questionControllers[index]?.dispose();
        answerControllers[index]?.dispose();
        questionControllers.remove(index);
        answerControllers.remove(index);

        _rebuildFlashcardControllers();
        _markUnsaved();
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete flashcard")),
      );
    }
  }



  Future<void> _pickCoverImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _coverImageFile = File(picked.path);
        _coverImageUrl = picked.path;
        _markUnsaved();
      });
    }
  }



  void _saveDeck() async {
    if (!canEdit) return;

    final deckProv = Provider.of<DeckProvider>(context, listen: false);

    final selectedThemeObj = availableThemes.firstWhere(
      (t) => t.id == _selectedThemeId,
      orElse: () => availableThemes.isNotEmpty
          ? availableThemes.first
          : DeckTheme(id: 0, name: "Default"),
    );


    final updatedDeck = editableDeck.copyWith(
      title: titleController.text,
      description: descController.text,
      cards: List.from(cards),
      theme: selectedThemeObj,
      coverImageUrl: _coverImageUrl,
    );

    try {
      DeckItem syncedDeck;

      if (isEditing) {
        // Edit deck with optional cover image upload
        syncedDeck = await deckProv.editDeck(
          updatedDeck,
          coverImageFile: _coverImageFile,
        );
      } else {
        // Create deck with optional cover image upload
        syncedDeck = await deckProv.createDeck(
          updatedDeck,
          coverImageFile: _coverImageFile,
        );
      }

      if (!mounted) return;

      setState(() {
        editableDeck = syncedDeck.copyWith();
        cards = List.from(syncedDeck.cards);
        unsavedChanges = false;
        isEditing = false;
        _coverImageFile = null;
        _coverImageUrl = syncedDeck.coverImageUrl; 
      });
    } catch (e, st) {
      debugPrint("❌ _saveDeck failed: $e\n$st");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save deck.")),
      );
    }
  }





  // ---------------------------- TAGS ----------------------------
  Future<String?> _showTagDialog({String? currentTag}) {
    final tagController = TextEditingController(text: currentTag ?? "");
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentTag != null ? "Edit Tag" : "Add Tag"),
        content: TextField(
          controller: tagController,
          decoration: const InputDecoration(labelText: "Tag"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, tagController.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ---------------------------- QUIZ ----------------------------
  void _showQuizModeSelector() {
    final theme = Theme.of(context);
    bool adaptiveMode = true;
    bool srsEnabled = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Select Quiz Mode", style: theme.textTheme.titleLarge),
              const SizedBox(height: 20),

              // Adaptive Mode toggle
              SwitchListTile(
                title: const Text("Adaptive Mode"),
                value: adaptiveMode,
                onChanged: (val) => setState(() => adaptiveMode = val),
              ),
              // SRS toggle
              SwitchListTile(
                title: const Text("Spaced Repetition (SRS)"),
                value: srsEnabled,
                onChanged: (val) => setState(() => srsEnabled = val),
              ),

              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.sort),
                label: const Text("Sequential"),
                onPressed: () {
                  Navigator.pop(context);
                  _startApiQuiz(
                    mode: QuizMode.sequential,
                    adaptiveMode: adaptiveMode,
                    srsEnabled: srsEnabled,
                  );
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.shuffle),
                label: const Text("Random"),
                onPressed: () {
                  Navigator.pop(context);
                  _startApiQuiz(
                    mode: QuizMode.random,
                    adaptiveMode: adaptiveMode,
                    srsEnabled: srsEnabled,
                  );
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
                          builder: (context, setState) => RadioGroup<int>(
                            groupValue: tempSelection,
                            onChanged: (val) => setState(() => tempSelection = val!),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [10, 15, 20, 30].map((sec) {
                                return RadioListTile<int>(
                                  title: Text("$sec seconds"),
                                  value: sec,
                              
                                );
                              }).toList(),),
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
                    _startApiQuiz(
                      mode: QuizMode.timed,
                      timerSeconds: selectedSeconds,
                      adaptiveMode: adaptiveMode,
                      srsEnabled: srsEnabled,
                    );
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
      ),
    );
  }


  void _startApiQuiz({
    required QuizMode mode,
    int? timerSeconds,
    bool adaptiveMode = true,
    bool srsEnabled = true,
  }) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (cards.isEmpty) {
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
          deckItem: editableDeck,
          token: token,
          mode: mode,
          initialTime: timerSeconds,
          adaptiveMode: adaptiveMode,
          srsEnabled: srsEnabled,
        ),
      ),
    );
  }


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
          deck: editableDeck.toDeckModel(),
          cards: cards,
          deckTheme: selectedTheme,
        ),
      ),
    );
  }


@override
Widget build(BuildContext context) {
  return Consumer<ThemeProvider>(
    builder: (context, themeProvider, _) {
      availableThemes = themeProvider.availableThemes;

      DeckTheme fallbackTheme = themeProvider.activeDeckTheme ??
          (availableThemes.isNotEmpty
              ? availableThemes.first
              : DeckTheme.defaultTheme());

      DeckTheme selectedTheme;
      if (_selectedThemeId != null) {
        selectedTheme = availableThemes.firstWhere(
          (t) => t.id == _selectedThemeId,
          orElse: () => fallbackTheme,
        );
      } else {
        selectedTheme = fallbackTheme;
      }

      final deckColors = themeProvider.getDeckThemeColors(selectedTheme);

      Color cardColor = deckColors["cardColor"]!;
      Color textColor = deckColors["textColor"]!;
      final Color backgroundColor = deckColors["backgroundColor"]!;
      final Color accentColor = themeProvider.adaptDeckColor(
        selectedTheme.accentColor,
        fallback: Colors.deepPurple,
      );

      final isDark = Theme.of(context).brightness == Brightness.dark;

      if ((cardColor.computeLuminance() - backgroundColor.computeLuminance())
              .abs() <
          0.15) {
        cardColor = isDark
            ? Colors.grey.shade900
            : Colors.grey.shade100;
      }

      if ((textColor.computeLuminance() - cardColor.computeLuminance()).abs() <
          0.3) {
        textColor = isDark ? Colors.white : Colors.black;
      }

  
      final Color borderColor = isDark
          ? Colors.white.withValues(alpha: 0.25)
          : Colors.black.withValues(alpha: 0.2);

      final Color visibleIconColor = isDark ? Colors.white : Colors.black87;

      return Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: accentColor,
            selectionColor: accentColor.withValues(alpha: 0.3),
            selectionHandleColor: accentColor,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: cardColor,
            labelStyle: TextStyle(color: textColor),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: cardColor,
            labelStyle: TextStyle(color: textColor),
            secondaryLabelStyle: TextStyle(color: textColor),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            secondarySelectedColor:
                accentColor.withValues(alpha: 0.2),
            selectedColor: accentColor.withValues(alpha: 0.2),
            brightness: Theme.of(context).brightness,
            pressElevation: 0,
            shadowColor: Colors.transparent,
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.all(accentColor),
            trackColor: WidgetStateProperty.all(
                accentColor.withValues(alpha: 0.5)),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: textColor),
          ),
        ),
        child: Scaffold(
          backgroundColor: backgroundColor,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: isEditing
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.4),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: AppBar(
                elevation: isEditing ? 10 : 2,
                shadowColor: isEditing
                    ? accentColor.withValues(alpha: 0.6)
                    : Colors.black26,
                backgroundColor: accentColor,
                title: Text(
                  isEditing ? "Edit Deck" : editableDeck.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: selectedTheme.fontFamily,
                  ),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  if (isEditing && canEdit)
                    IconButton(
                      icon: const Icon(Icons.save),
                      color: Colors.white,
                      onPressed: unsavedChanges ? _saveDeck : null,
                    ),

                  if (!isEditing && canEdit)
                    PopupMenuButton<String>(
                      color: cardColor,
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) async {
                        switch (value) {
                          case 'edit':
                            setState(() => isEditing = true);
                            break;

                          case 'customize':
                            final authProvider =
                                Provider.of<AuthProvider>(context, listen: false);

                            final appliedTheme =
                                await Navigator.push<DeckTheme>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeckCustomizeScreen(
                                  deckId: editableDeck.id,
                                  token: authProvider.token!,
                                ),
                              ),
                            );

                            if (appliedTheme != null) {
                              setState(() {
                                _selectedThemeId = appliedTheme.id;

                                if (!availableThemes
                                    .any((t) => t.id == appliedTheme.id)) {
                                  availableThemes.add(appliedTheme);
                                }

                                Provider.of<ThemeProvider>(context,
                                        listen: false)
                                    .setActiveDeckTheme(appliedTheme);
                              });
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit,
                                  size: 18, color: visibleIconColor),
                              const SizedBox(width: 8),
                              Text("Edit Deck",
                                  style: TextStyle(color: textColor)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'customize',
                          child: Row(
                            children: [
                              Icon(Icons.palette,
                                  size: 18, color: visibleIconColor),
                              const SizedBox(width: 8),
                              Text("Customize Deck",
                                  style: TextStyle(color: textColor)),
                            ],
                          ),
                        ),
                      ],
                    ),

                  if (!isEditing) ...[
                    IconButton(
                      icon: const Icon(Icons.menu_book_rounded),
                      onPressed: _openStudyMode,
                      tooltip: "Study Mode",
                      color: Colors.white,
                    ),
                    IconButton(
                      icon: const Icon(Icons.quiz),
                      onPressed:
                          cards.isEmpty ? null : _showQuizModeSelector,
                      tooltip: "Start Quiz",
                      color: cards.isEmpty
                          ? Colors.white54
                          : Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ),


          body: Container(
            color: backgroundColor,
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                if (isEditing && canEdit)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        "Deck Cover",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: selectedTheme.fontFamily,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickCoverImage,
                        child: _coverImageUrl != null
                            ? Image.network(
                                _coverImageUrl!,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                              )
                            : Container(
                                height: 150,
                                color: cardColor,
                                child: Center(
                                  child: Text(
                                    "Tap to select cover image",
                                    style: TextStyle(
                                      color: textColor,
                                      fontFamily: selectedTheme.fontFamily,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                // Deck title
                TextField(
                  controller: titleController,
                  readOnly: !isEditing,
                  style: TextStyle(
                    color: textColor,
                    fontSize: selectedTheme.fontSize ?? 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: selectedTheme.fontFamily,
                  ),
                  onChanged: (_) => _markUnsaved(),
                  decoration: InputDecoration(labelText: "Deck Title"),
                ),
                const SizedBox(height: 12),
                // Deck description
                TextField(
                  controller: descController,
                  readOnly: !isEditing,
                  maxLines: 3,
                  style: TextStyle(
                    color: textColor,
                    fontSize: selectedTheme.fontSize ?? 16,
                    fontFamily: selectedTheme.fontFamily,
                  ),
                  onChanged: (_) => _markUnsaved(),
                  decoration: InputDecoration(labelText: "Description"),
                ),
                const SizedBox(height: 12),
                if (canEdit && editableDeck.isPublic)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: textColor,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RatingScreen(deckId: editableDeck.id, canRate: false),
                          ),
                        );
                      },
                      icon: const Icon(Icons.star_rate),
                      label: const Text("View Ratings"),
                    ),
                  ),
                if (isEditing && canEdit)
                  SwitchListTile(
                    title: Text("Make Deck Public", style: TextStyle(color: textColor)),
                    value: editableDeck.isPublic,
                    onChanged: (val) {
                      setState(() {
                        editableDeck = editableDeck.copyWith(isPublic: val);
                        _markUnsaved();
                      });
                    },
                  ),
                  // Tags 
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ...editableDeck.tags.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final tag = entry.value;

                        final Color chipBg = accentColor.withValues(alpha: 0.25);
                        final Color tagTextColor =
                            chipBg.computeLuminance() > 0.5 ? Colors.black : Colors.white;

                        return Theme(
                          data: Theme.of(context).copyWith(
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                          ),
                          child: InputChip(
                            label: Text(
                              tag,
                              style: TextStyle(
                                color: tagTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            backgroundColor: chipBg,
                            disabledColor: chipBg,
                            labelStyle: TextStyle(color: tagTextColor),

                            elevation: 0,
                            pressElevation: 0,
                            shadowColor: Colors.transparent,

                            onPressed: (isEditing && canEdit)
                                ? () async {
                                    final editedTag = await _showTagDialog(currentTag: tag);
                                    if (editedTag != null && editedTag.isNotEmpty) {
                                      setState(() {
                                        editableDeck.tags[idx] = editedTag;
                                        _markUnsaved();
                                      });
                                    }
                                  }
                                : () {},

                            onDeleted: (isEditing && canEdit)
                                ? () {
                                    setState(() {
                                      editableDeck.tags.removeAt(idx);
                                      _markUnsaved();
                                    });
                                  }
                                : null,

                            side: BorderSide(
                              color: accentColor.withValues(alpha: 0.45),
                            ),
                          ),
                        );


                      }),

                      if (isEditing && canEdit)
                        ActionChip(
                          label: const Text("Add Tag"),
                          backgroundColor: accentColor,

        
                          labelStyle: TextStyle(
                            color: accentColor.computeLuminance() < 0.5
                                ? Colors.white
                                : Colors.black,
                          ),

                          pressElevation: 0,
                          shadowColor: Colors.transparent,

                          onPressed: () async {
                            final newTag = await _showTagDialog();
                            if (newTag != null && newTag.isNotEmpty) {
                              setState(() {
                                editableDeck.tags.add(newTag);
                                _markUnsaved();
                              });
                            }
                          },
                        ),
                    ],
                  ),


                const SizedBox(height: 12),
                if (!isEditing && availableThemes.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Deck Theme",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: selectedTheme.fontFamily,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: textColor.withValues(alpha:0.3)),
                        ),
                        child: Text(
                          selectedTheme.name ?? "Unnamed Theme",
                          style: TextStyle(
                            color: textColor,
                            fontFamily: selectedTheme.fontFamily,
                            fontSize: selectedTheme.fontSize ?? 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),
                // Flashcards
                ...cards.asMap().entries.map((entry) {
                  final i = entry.key;
                  final card = entry.value;
                  return Card(
                    key: ValueKey(card.id ?? i),
                    margin: EdgeInsets.symmetric(vertical: selectedTheme.cardSpacing ?? 12),
                    color: cardColor,
                    elevation: selectedTheme.elevation ?? 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(selectedTheme.borderRadius ?? 8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: questionControllers[i],
                            readOnly: !(isEditing && canEdit),
                            style: TextStyle(
                              color: textColor,
                              fontSize: selectedTheme.fontSize ?? 16,
                              fontFamily: selectedTheme.fontFamily,
                            ),
                            maxLines: 2,
                            onChanged: (val) {
                              if (isEditing && canEdit) {
                                card.question = val;
                                _markUnsaved();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: "Question ${i + 1}",
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: answerControllers[i],
                            readOnly: !(isEditing && canEdit),
                            style: TextStyle(
                              color: textColor,
                              fontSize: selectedTheme.fontSize ?? 16,
                              fontFamily: selectedTheme.fontFamily,
                            ),
                            maxLines: 2,
                            onChanged: (val) {
                              if (isEditing && canEdit) {
                                card.answer = val;
                                _markUnsaved();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: "Answer ${i + 1}",
                            ),
                          ),
                          if (isEditing && canEdit)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                label: const Text("Delete", style: TextStyle(color: Colors.red)),
                                onPressed: () => _deleteFlashcard(i, card),
                              ),
                            ),

                        ],
                      ),
                    ),
                  );
                }),
                if (isEditing && canEdit)
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: textColor,
                      ),
                      onPressed: _addFlashcard,
                      icon: const Icon(Icons.add),
                      label: const Text("Add Flashcard"),
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: !isEditing
              ? FloatingActionButton.extended(
                  onPressed: _openDeckAIAssistant,
                  backgroundColor: accentColor,
                  foregroundColor: textColor,
                  icon: const Icon(Icons.smart_toy),
                  label: const Text("Chat with AI"),
                )
              : null,
        ),
      );
    },
  );
}


// --------------------------- AI Assistant ---------------------------
void _openDeckAIAssistant() {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);

  if (authProvider.token == null || !authProvider.isLoggedIn) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Login to chat with AI!")),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AIChatScreen(
        token: authProvider.token!,
        deckId: editableDeck.id, 
        deckTitle: editableDeck.title,
      ),
    ),
  );


}}
class HexColor extends Color {
  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));

  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) hexColor = "FF$hexColor";
    return int.parse(hexColor, radix: 16);
  }
}
