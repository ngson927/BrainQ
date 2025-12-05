import 'package:flutter/material.dart';
import '../models/quiz_session.dart';
import '../services/api_service.dart';

class QuizProvider extends ChangeNotifier {
  QuizSession? session;
  final String token;
  String? currentQuestion;
  double accuracy = 0.0;
  String? feedback;

  QuizProvider({required this.token});

  bool get hasSession => session != null;

  // ------------------- START -------------------
  Future<void> startSession(int deckId, String mode) async {
    final data = await ApiService.startSession(deckId: deckId, mode: mode, token: token);
    session = QuizSession.fromBackendJson(data['session']);
    currentQuestion = data['question'];
    accuracy = 0.0;
    feedback = null;
    notifyListeners();
  }

  // ------------------- ANSWER -------------------
  Future<void> submitAnswer(String answer) async {
    if (session == null) return;
    final data = await ApiService.submitAnswer(sessionId: session!.id, answer: answer, token: token);
    feedback = data['feedback'];
    accuracy = (data['accuracy'] as num?)?.toDouble() ?? 0.0;
    currentQuestion = data['next_question'];
    notifyListeners();
  }

  // ------------------- SKIP -------------------
  Future<void> skipQuestion() async {
    if (session == null) return;
    final data = await ApiService.skipQuestion(sessionId: session!.id, token: token);
    feedback = data['detail'];
    currentQuestion = data['next_question'];
    notifyListeners();
  }

  // ------------------- FINISH -------------------
  Future<Map<String, dynamic>> finishQuiz() async {
    if (session == null) return {};
    final data = await ApiService.finishQuiz(sessionId: session!.id, token: token);
    notifyListeners();
    return data;
  }

  // ------------------- RESUME -------------------
  Future<void> resumeQuiz() async {
    if (session == null) return;
    final data = await ApiService.resumeQuiz(sessionId: session!.id, token: token);
    currentQuestion = data['question'];
    notifyListeners();
  }

  // ------------------- CHANGE MODE -------------------
  Future<void> changeMode(String mode) async {
    if (session == null) return;
    final data = await ApiService.changeMode(sessionId: session!.id, mode: mode, token: token);
    currentQuestion = data['question'];
    feedback = data['detail'];
    notifyListeners();
  }

  String get question => currentQuestion ?? '';
}
