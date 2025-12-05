import 'dart:async';

import 'package:brainq_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../models/deck_item.dart';
import '../../models/flashcard.dart';
import '../../providers/deck_provider.dart';
import '../../services/api_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:confetti/confetti.dart';


class AIDeckScreen extends StatefulWidget {
  final String token;
  const AIDeckScreen({super.key, required this.token});

  @override
  AIDeckScreenState createState() => AIDeckScreenState();
}

class AIDeckScreenState extends State<AIDeckScreen>
    with SingleTickerProviderStateMixin {
  bool _isPublic = true;

  AnimationController? _animController;
  Animation<double>? _fadeIn;



  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeIn = CurvedAnimation(
      parent: _animController!,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animController?.forward();
    });
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  void _showVisibilitySettings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deck Visibility'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioMenuButton<bool>(
              value: false,
              groupValue: _isPublic,
              onChanged: (val) {
                setState(() => _isPublic = val ?? false);
                Navigator.pop(ctx);
              },
              child: const Text('Private'),
            ),
            RadioMenuButton<bool>(
              value: true,
              groupValue: _isPublic,
              onChanged: (val) {
                setState(() => _isPublic = val ?? true);
                Navigator.pop(ctx);
              },
              child: const Text('Public'),
            ),
          ],
        ),
      ),
    );
  }



Widget _buildOptionCard(String type, IconData icon, String label) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  final Color cardBg = isDark
      ? theme.colorScheme.surface.withValues(alpha:0.9)
      : Colors.white.withValues(alpha:0.95);

  final Color textColor = theme.colorScheme.onSurface;

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AIDeckInputPage(
            token: widget.token,
            inputType: type,
            isPublic: _isPublic,
          ),
        ),
      );
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cardBg,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha:0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 50,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 20,
            color: textColor.withValues(alpha:0.6),
          ),
        ],
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Deck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            onPressed: _showVisibilitySettings,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeIn!,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildOptionCard('prompt', Icons.text_fields, 'Enter Text'),
              _buildOptionCard('file', Icons.upload_file, 'Select File'),
              _buildOptionCard('image', Icons.image, 'Select Image'),
            ],
          ),
        ),
      ),
    );
  }
}

class AIDeckInputPage extends StatefulWidget {
  final String token;
  final String inputType;
  final bool isPublic;

  const AIDeckInputPage({
    super.key,
    required this.token,
    required this.inputType,
    required this.isPublic,
  });

  @override
  State<AIDeckInputPage> createState() => _AIDeckInputPageState();
}

class _AIDeckInputPageState extends State<AIDeckInputPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();

  final TextEditingController _countController =
    TextEditingController(text: "10");
  int? _requestedCount;

  File? _selectedFile;
  http.MultipartFile? _selectedFileWeb;

  bool _isLoading = false;
  String? _error;
  String _aiStatus = "Initializing...";
  List<String> _previewCards = [];

  late AnimationController _fadeInCtrl;
  late Animation<double> _fadeInAnim;
  late ConfettiController _confettiCtrl;

  Timer? _cardTimer;
  int _cardIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeInCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeInAnim = CurvedAnimation(parent: _fadeInCtrl, curve: Curves.easeOut);
    _fadeInCtrl.forward();

    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 2));

    if (widget.inputType != 'prompt') {
      Future.delayed(const Duration(milliseconds: 150), _pickFile);
    }
  }

  @override
  void dispose() {
    _fadeInCtrl.dispose();
    _promptController.dispose();
    _countController.dispose();
    _confettiCtrl.dispose();
    _cardTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: kIsWeb,
      );
      if (result == null) return;

      if (kIsWeb && result.files.single.bytes != null) {
        setState(() {
          _selectedFileWeb = http.MultipartFile.fromBytes(
            widget.inputType == 'file' ? 'file' : 'image',
            result.files.single.bytes!,
            filename: result.files.single.name,
          );
        });
      } else if (!kIsWeb && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      setState(() => _error = "Error selecting file: $e");
    }
  }

  void _startCardAnimationSequential(List<String> cards) {
    _cardIndex = 0;
    _previewCards.clear();
    _cardTimer?.cancel();

    void showNextCard() {
      if (!mounted || !_isLoading || _cardIndex >= cards.length) return;

      setState(() {
        _previewCards = [cards[_cardIndex]];
        _aiStatus = "Generating ${cards[_cardIndex]}...";
      });

      _cardIndex++;
      if (_cardIndex < cards.length) {
        _cardTimer = Timer(const Duration(seconds: 2), showNextCard);
      }
    }

    showNextCard();
  }

Future<void> _generateDeck() async {
  // Validate input
  if (widget.inputType == 'prompt' && _promptController.text.trim().isEmpty) {
    setState(() => _error = "Please enter a prompt.");
    return;
  }

  if (widget.inputType != 'prompt' && _selectedFile == null && _selectedFileWeb == null) {
    setState(() => _error = "Please select a file or image.");
    return;
  }

  setState(() {
    _isLoading = true;
    _error = null;
    _aiStatus = "Reading input...";
    _previewCards.clear();
  });

  // Start card animation placeholder
  _startCardAnimationSequential(["Card 1", "Card 2", "Card 3"]);

  try {
    http.MultipartFile? file;
    http.MultipartFile? image;

    if (widget.inputType == "file") {
      file = kIsWeb
          ? _selectedFileWeb
          : await http.MultipartFile.fromPath("file", _selectedFile!.path);
    } else if (widget.inputType == "image") {
      image = kIsWeb
          ? _selectedFileWeb
          : await http.MultipartFile.fromPath("image", _selectedFile!.path);
    }

    // Only for prompt input, send requested count
    if (widget.inputType == 'prompt') {
    }

    final response = await ApiService.generateAIDeck(
      token: widget.token,
      inputType: widget.inputType,
      isPublic: widget.isPublic,
      promptText: widget.inputType == 'prompt' ? _promptController.text : null,
      requestedCount: widget.inputType == 'prompt' ? _requestedCount : null,
      file: file,
      image: image,
    );

    if (!mounted) return;

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final deckData = data['ai_job']?['deck'] ?? {};
      final deckId = deckData['id'] ?? data['deck_id'];
      final deckTitle = deckData['title'] ?? 'AI Deck';
      final deckDesc = deckData['description'] ?? '';

      final flashcardsData =
          List<Map<String, dynamic>>.from(deckData['flashcards'] ?? []);
      final flashcards = flashcardsData
          .map((f) => Flashcard(
                question: f['question'] ?? '',
                answer: f['answer'] ?? '',
              ))
          .toList();

      final deckItem = DeckItem(
        id: deckId,
        title: deckTitle,
        description: deckDesc,
        cards: flashcards,
        ownerId: authProvider.userId,
        isPublic: widget.isPublic,
        tags: [],
      );

      final deckProv = Provider.of<DeckProvider>(context, listen: false);
      deckProv.addDeck(deckItem);

      _confettiCtrl.play();
      _cardTimer?.cancel();

      if (!mounted) return;
      setState(() {
        _aiStatus =
            "🎉 Your AI deck is ready! You’ll find it in your Library.";
        _previewCards.clear();
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    } else {
      if (!mounted) return;
      setState(() => _error = data['detail'] ?? "AI generation failed.");
    }
  } catch (e) {
    setState(() => _error = "Error: $e");
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}



  Future<bool> _onWillPop() async {
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Your AI deck is still generating. You can leave now — it will appear in your library when ready.",
          ),
          duration: Duration(seconds: 3),
        ),
      );

      return true;
    }

    return true;
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        title: Text(
          widget.inputType == 'prompt'
              ? "Enter Prompt"
              : widget.inputType == 'file'
                  ? "Upload File"
                  : "Upload Image",
        ),
      ),
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _fadeInAnim,
              builder: (_, child) {
                final v = _fadeInAnim.value;
                return Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - v)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                child: _isLoading
                    ? Center(
                        key: const ValueKey('loading'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(strokeWidth: 4),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _aiStatus,
                              style: theme.textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30),
                            if (_previewCards.isNotEmpty)
                              TweenAnimationBuilder<double>(
                                key: ValueKey(_previewCards.first),
                                tween: Tween(begin: 0.8, end: 1.0),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOut,
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: Opacity(
                                      opacity: scale,
                                      child: Container(
                                        width: 180,
                                        height: 130,
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _previewCards.first,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 16),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      )
                      : SingleChildScrollView(
                          key: const ValueKey('input'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.inputType == 'prompt') ...[
                                // 1️⃣ Prompt input
                                TextField(
                                  controller: _promptController,
                                  maxLines: 5,
                                  decoration: InputDecoration(
                                    labelText: "Describe what you want",
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Icons.text_fields),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // 2️⃣ Number of flashcards input
                                TextField(
                                  controller: _countController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: "Number of flashcards",
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Icons.format_list_numbered),
                                  ),
                                  onChanged: (value) {
                                    _requestedCount = int.tryParse(value.trim());
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],

                              if (widget.inputType != 'prompt') ...[
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed: _pickFile,
                                  icon: Icon(widget.inputType == 'file'
                                      ? Icons.upload_file
                                      : Icons.image),
                                  label: Text(widget.inputType == 'file'
                                      ? "Select File"
                                      : "Select Image"),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_selectedFile != null || _selectedFileWeb != null)
                                  Text(
                                    _selectedFile != null
                                        ? _selectedFile!.path.split('/').last
                                        : _selectedFileWeb!.filename!,
                                    style: theme.textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _generateDeck,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("Generate Deck",
                                    style: TextStyle(fontSize: 16)),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiCtrl,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.blue,
                  Colors.green,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
