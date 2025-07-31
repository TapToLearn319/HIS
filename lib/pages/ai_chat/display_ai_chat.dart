
import 'package:flutter/material.dart';
import 'gemini_api.dart';

class AIPage extends StatefulWidget {
  const AIPage({super.key});

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  final TextEditingController _controller = TextEditingController();
  late final ChatBot _chatBot;

  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _chatBot = ChatBot();
  }

  void _sendPrompt() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': prompt});
      _isLoading = true;
      _hasStarted = true;
      _controller.clear();
    });

    FocusScope.of(context).unfocus();

    try {
      final result = await _chatBot.getChatResponse(prompt);
      setState(() {
        _messages.add({'sender': 'ai', 'text': result});
      });
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'system', 'text': '오류: ${e.toString()}'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildChatUI() {
    return Column(
      children: [
        Expanded(
          child:
              _messages.isEmpty && !_isLoading
                  ? const Center(
                    child: Text(
                      'Ask Anything!',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                  : ListView.builder(
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final message = _messages[index];
                      final isUser = message['sender'] == 'user';
                      final isSystem = message['sender'] == 'system';

                      return Align(
                        alignment:
                            isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color:
                                isUser
                                    ? Colors.blueAccent.withOpacity(0.8)
                                    : isSystem
                                    ? Colors.red[100]
                                    : Colors.grey[200],
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(isUser ? 15 : 0),
                              topRight: Radius.circular(isUser ? 0 : 15),
                              bottomLeft: const Radius.circular(15),
                              bottomRight: const Radius.circular(15),
                            ),
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          child: Text(
                            message['text']!,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontStyle:
                                  isSystem
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Enter the question...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendPrompt(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: _sendPrompt,
              mini: true,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Chat',
            onPressed: () {
              setState(() {
                _chatBot.resetChat();
                _messages.clear();
                _hasStarted = false;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _hasStarted
                ? _buildChatUI()
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withOpacity(0.2),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.smart_toy,
                            size: 64,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: 'Enter the question...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) => _sendPrompt(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton(
                          onPressed: _sendPrompt,
                          mini: true,
                          child: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
      ),
    );
  }
}
