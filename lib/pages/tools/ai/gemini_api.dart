import 'package:google_generative_ai/google_generative_ai.dart';

const String _apiKey = 'AIzaSyCC54rpSgLwj8zoSTsLbnQiohBDI5tudR8';

class ChatBot {
  late final GenerativeModel _model;
  late final ChatSession _chat;

  ChatBot({String modelName = 'gemini-1.5-flash'}) {
    if (_apiKey.isEmpty) {
      throw Exception("Gemini API Key is not set. Please replace 'APIKEY' in file");
    }
    _model = GenerativeModel(model: modelName, apiKey: _apiKey);
    _chat = _model.startChat();
  }

  Future<String> getChatResponse(String prompt) async {
    try {
      final response = await _chat.sendMessage(Content.text(prompt));
      return response.text ?? 'No response from AI.';
    } catch (e) {
      print('Gemini API Error: $e');
      return 'AI 응답 오류: ${e.toString()}';
    }
  }

  List<Content> getChatHistory() {
    return _chat.history.toList();
  }

  void resetChat() {
    _chat = _model.startChat();
  }
}
