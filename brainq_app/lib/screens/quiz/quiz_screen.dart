import 'dart:async';
import 'package:flutter/material.dart';
import 'package:brainq_app/models/deck_item.dart';
import 'package:brainq_app/screens/quiz/quiz_result_screen.dart';
import 'package:brainq_app/services/api_service.dart';

enum QuizMode { sequential, random, timed }


class ApiQuizScreen extends StatefulWidget {
  final DeckItem deckItem;
  final String token;
  final QuizMode mode;
  final int? initialTime;

  const ApiQuizScreen({
    super.key,
    required this.deckItem,
    required this.token,
    required this.mode,
    this.initialTime,
  });

  @override
  State<ApiQuizScreen> createState() => _ApiQuizScreenState();
}

class _ApiQuizScreenState extends State<ApiQuizScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int? sessionId;
  String? question;
  List<String> options = [];
  bool isLoading = true;
  bool isAnswered = false;
  String feedback = '';
  late QuizMode currentMode;

  Timer? _timer;
  int _timeLeft = 15;
  int _selectedTime = 15;
  bool _timerRunning = false; // ✅ track timer state

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    currentMode = widget.mode;

    _selectedTime = widget.initialTime ?? 15;
    _timeLeft = _selectedTime;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _startQuiz();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (currentMode == QuizMode.timed) {
      if (state == AppLifecycleState.paused) {
        _stopTimer();
      } else if (state == AppLifecycleState.resumed && !_timerRunning && !isAnswered) {
        _startTimer();
      }
    }
  }

  // ---------------- TIMER ----------------
  void _startTimer() {
    _timer?.cancel();
    if (currentMode != QuizMode.timed) return;

    setState(() => _timerRunning = true);

    _animController.forward(from: 0);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft <= 1) {
        timer.cancel();
        setState(() => _timerRunning = false);
        _autoSkip();
      } else {
        setState(() => _timeLeft--);
        _animController.forward(from: 0);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _timerRunning = false);
  }

  Future<void> _autoSkip() async {
    if (mounted && !isAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⏰ Time’s up! Skipping question...")),
      );
      await _skipQuestion();
    }
  }

  // ---------------- QUIZ ----------------
  Future<void> _startQuiz() async {
    setState(() => isLoading = true);
    try {
      final backendMode = currentMode == QuizMode.timed
          ? QuizMode.sequential.name
          : currentMode.name;

      final data = await ApiService.startSession(
        deckId: widget.deckItem.id,
        mode: backendMode,
        token: widget.token,
      );

      setState(() {
        sessionId = data['session']['id'];
        question = data['question'];
        options = List<String>.from(data['options'] ?? []);
        isAnswered = false;
        feedback = '';
        _timeLeft = _selectedTime;
        isLoading = false;
      });

      if (currentMode == QuizMode.timed) {
        _startTimer();
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to start quiz: $e')));
    }
  }

  Future<void> _submitAnswer(String answer) async {
    if (sessionId == null || isAnswered) return;

    _stopTimer(); // ✅ pause timer when answering
    setState(() => isAnswered = true);

    try {
      final res = await ApiService.submitAnswer(
        sessionId: sessionId!,
        answer: answer,
        token: widget.token,
      );

      if (res['next_question'] == null) {
        _goToResults();
        return;
      }

      setState(() {
        question = res['next_question'];
        options = List<String>.from(res['next_options'] ?? []);
        feedback = res['feedback'] ?? '';
        isAnswered = false;
        _timeLeft = _selectedTime; // reset timer
      });

      if (currentMode == QuizMode.timed) {
        _startTimer(); // ✅ auto-resume for next question
      }
    } catch (e) {
      setState(() => isAnswered = false);
      if (currentMode == QuizMode.timed) _startTimer();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to submit answer: $e')));
    }
  }

  Future<void> _skipQuestion() async {
    _stopTimer();
    if (sessionId == null) return;

    try {
      final res = await ApiService.skipQuestion(
        sessionId: sessionId!,
        token: widget.token,
      );

      if (res['next_question'] == null) {
        _goToResults();
        return;
      }

      setState(() {
        question = res['next_question'];
        options = List<String>.from(res['next_options'] ?? []);
        feedback = '';
        isAnswered = false;
        _timeLeft = _selectedTime;
      });

      if (currentMode == QuizMode.timed) {
        _startTimer();
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to skip question: $e')));
    }
  }

  // ---------------- MODE & QUIT ----------------
  Future<void> _changeMode(QuizMode newMode) async {
    if (sessionId == null) return;

    if (newMode == QuizMode.timed) {
      final seconds = await _showTimerSettingsDialog();
      if (seconds == null) return;

      setState(() {
        _selectedTime = seconds;
        currentMode = newMode;
        isLoading = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⏱ Timed mode set: $_selectedTime seconds')),
      );

      await _startQuiz();
      return;
    }

    try {
      await ApiService.changeMode(
        sessionId: sessionId!,
        mode: newMode.name,
        token: widget.token,
      );

      setState(() {
        currentMode = newMode;
        isLoading = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mode changed to ${newMode.name}')),
      );

      await _startQuiz();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to change mode: $e')));
    }
  }

  Future<int?> _showTimerSettingsDialog() async {
    int tempSelection = _selectedTime;
    return await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Timer Duration"),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final seconds in [10, 15, 20, 30])
                RadioListTile<int>(
                  title: Text("$seconds seconds"),
                  value: seconds,
                  groupValue: tempSelection,
                  onChanged: (val) => setState(() => tempSelection = val!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, tempSelection),
              child: const Text("Confirm")),
        ],
      ),
    );
  }

  Future<void> _quitQuiz() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Quit Quiz"),
        content: const Text(
          "Are you sure you want to quit? Your progress will be saved.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Quit"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _stopTimer();

      if (sessionId != null) {
        try {
          await ApiService.finishQuiz(
            sessionId: sessionId!,
            token: widget.token,
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to finish quiz session: $e')),
          );
        }
      }

      Navigator.pop(context);
    }
  }

  void _goToResults() async {
    if (!mounted || sessionId == null) return;
    _stopTimer();

    try {
      await ApiService.finishQuiz(
        sessionId: sessionId!,
        token: widget.token,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to finish quiz session: $e')),
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            QuizResultsScreen(sessionId: sessionId!, token: widget.token),
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deckItem.title),
        actions: [
          PopupMenuButton<QuizMode>(
            icon: const Icon(Icons.sync_alt),
            tooltip: 'Change Mode',
            onSelected: _changeMode,
            itemBuilder: (_) => const [
              PopupMenuItem(value: QuizMode.sequential, child: Text('Sequential Mode')),
              PopupMenuItem(value: QuizMode.random, child: Text('Random Mode')),
              PopupMenuItem(value: QuizMode.timed, child: Text('Timed Mode')),
            ],
          ),
          IconButton(
            onPressed: _quitQuiz,
            icon: const Icon(Icons.exit_to_app),
            tooltip: "Quit Quiz",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (currentMode == QuizMode.timed)
                    SizedBox(
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: _timeLeft / _selectedTime,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                            ),
                          ),
                          Text(
                            "$_timeLeft s",
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    question ?? 'No question',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ...options.map(
                    (opt) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ElevatedButton(
                        onPressed: isAnswered ? null : () => _submitAnswer(opt),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: Text(opt),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (feedback.isNotEmpty)
                    Text(
                      feedback,
                      style: TextStyle(
                        color: feedback.startsWith('Correct') ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (currentMode == QuizMode.timed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_timerRunning) {
                            _stopTimer();
                          } else {
                            _startTimer();
                          }
                        },
                        icon: Icon(_timerRunning ? Icons.pause : Icons.play_arrow),
                        label: Text(_timerRunning ? 'Pause' : 'Resume'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _timerRunning ? Colors.orange : Colors.green,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isAnswered ? null : _skipQuestion,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Skip'),
                      ),

                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
