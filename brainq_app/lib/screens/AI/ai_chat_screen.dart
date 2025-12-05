import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/api_service.dart';

class AIChatScreen extends StatefulWidget {
  final String token;
  final int? deckId;
  final String? deckTitle;

  const AIChatScreen({
    super.key,
    required this.token,
    this.deckId,
    this.deckTitle,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  int? sessionId;
  List<Map<String, String>> messages = [];
  bool loading = true;
  bool sending = false;
  bool endingSession = false;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _typingQueue = [];
  String _currentTyping = '';
  Timer? _typingTimer;
  bool _cursorVisible = true;
  Timer? _cursorTimer;

  // --- Speech Recognition ---
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _startSession();
    _startCursorBlink();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  void _startCursorBlink() {
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_currentTyping.isNotEmpty) {
        setState(() {
          _cursorVisible = !_cursorVisible;
        });
      }
    });
  }

  Future<void> _startSession() async {
    try {
      final response = await ApiService.startAIAssistantSession(
        token: widget.token,
        deckId: widget.deckId,
        title: widget.deckTitle,
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        sessionId = data['id'];
        final msgs = data['messages'] as List<dynamic>;
        setState(() {
          messages = msgs
              .map((m) => {
                    'role': m['role'] as String,
                    'content': m['content'] as String,
                  })
              .toList();
          loading = false;
        });
      } else {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start session')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }


  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || sending || sessionId == null) return;

    final message = _controller.text.trim();
    setState(() {
      messages.add({'role': 'user', 'content': message});
      sending = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await ApiService.sendAIAssistantMessage(
        token: widget.token,
        sessionId: sessionId!,
        message: message,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final assistantMsg = data['assistant_message'] as String;
        _queueAssistantMessage(assistantMsg);
      } else {
        setState(() => sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }


  void _queueAssistantMessage(String text) {
    _typingQueue.add(text);
    if (_currentTyping.isEmpty) {
      _startTyping();
    }
  }

  void _startTyping() {
    if (_typingQueue.isEmpty) return;

    final nextMessage = _typingQueue.removeAt(0);
    int index = 0;
    _currentTyping = '';

    _typingTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (index < nextMessage.length) {
        setState(() {
          _currentTyping += nextMessage[index];
        });
        index++;
        _scrollToBottom();
      } else {
        setState(() {
          messages.add({'role': 'assistant', 'content': _currentTyping});
          _currentTyping = '';
        });
        timer.cancel();
        _startTyping();
        sending = false;
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    final bubbleColor = isUser ? Colors.blueAccent : Colors.grey[100];
    final textColor = isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(1, 2),
              ),
            ],
          ),
          child: isUser
              ? Text(
                  msg['content'] ?? '',
                  style: TextStyle(color: textColor),
                )
              : Stack(
                  children: [
                    MarkdownBody(
                      data: msg['content'] ?? '',
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: textColor),
                        code: TextStyle(
                          backgroundColor: Colors.grey[200],
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onTapLink: (text, href, title) async {
                        if (href != null && await canLaunchUrl(Uri.parse(href))) {
                          await launchUrl(Uri.parse(href));
                        }
                      },
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: msg['content'] ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied to clipboard')));
                        },
                      ),
                    )
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _endSession() async {
    if (sessionId == null) return;

    setState(() => endingSession = true);
    try {
      final response = await ApiService.endAIAssistantSession(
        token: widget.token,
        sessionId: sessionId!,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) {
          setState(() => endingSession = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Failed to end session')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => endingSession = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- Voice Input ---
void _toggleListening() async {
  if (!_isListening) {
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
      },
      onError: (error) {
        print('Speech error: ${error.errorMsg}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech error: ${error.errorMsg}')),
        );
      },
    );

    if (available) {
      setState(() => _isListening = true);

      _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );

            if (result.finalResult) {
              _isListening = false;
            }
          });
        },
        localeId: 'en_US',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition unavailable')),
      );
    }
  } else {
    setState(() => _isListening = false);
    _speech.stop();
  }
}



  @override
  Widget build(BuildContext context) {
  return PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result){

    },
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.deckTitle ?? 'AI Assistant'),
        actions: [
          IconButton(
            icon: endingSession
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.close),
            tooltip: 'End Session',
            onPressed: endingSession ? null : _endSession,
          ),
        ],
      ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length + (_currentTyping.isNotEmpty ? 1 : 0),
                      itemBuilder: (_, index) {
                        if (index < messages.length) {
                          return _buildMessageBubble(messages[index]);
                        } else {
                          final typingText = _currentTyping + (_cursorVisible ? '|' : '');
                          return _buildMessageBubble(
                              {'role': 'assistant', 'content': typingText});
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(30),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                hintText: 'Type your message...',
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isListening ? Icons.mic_off : Icons.mic,
                              color: _isListening ? Colors.red : Colors.black,
                            ),
                            tooltip: 'Voice Input',
                            onPressed: _toggleListening,
                          ),
                          IconButton(
                            icon: sending
                                ? const CircularProgressIndicator()
                                : const Icon(Icons.send),
                            onPressed: sending ? null : _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

}
