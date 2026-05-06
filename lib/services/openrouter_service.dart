// lib/services/openrouter_service.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OpenRouterService {
  static const String _apiKey =
      '';

  static Map<String, dynamic> _parseAiJson(String content) {
    var cleaned = content.trim();

    cleaned = cleaned.replaceAll('```json', '').replaceAll('```', '').trim();

    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  static const List<String> _models = [
    'google/gemma-4-31b-it:free',
    'google/gemma-4-26b-a4b-it:free',
    'openai/gpt-oss-120b:free',
  ];

  static Future<Map<String, dynamic>> getStudentAnalysis({
    required String studentName,
  }) async {
    Exception? lastError;

    for (final model in _models) {
      try {
        debugPrint('[OPENROUTER] Trying model = $model');

        final result = await _requestAnalysis(
          model: model,
          studentName: studentName,
        );

        debugPrint('[OPENROUTER] Success model = $model');
        return result;
      } catch (e) {
        debugPrint('[OPENROUTER] Failed model = $model');
        debugPrint('[OPENROUTER] Error = $e');

        lastError = Exception(e.toString());
        continue;
      }
    }

    throw lastError ?? Exception('All OpenRouter models failed.');
  }

  static Future<Map<String, dynamic>> _requestAnalysis({
    required String model,
    required String studentName,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('OpenRouter API key is empty.');
    }

    final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',

        // OpenRouter 권장 헤더
        'HTTP-Referer': 'http://localhost',
        'X-Title': 'MyButton Student Analysis',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': '''
You are an educational AI assistant.
Analyze student performance briefly.
Do not judge personality.
Use supportive teacher-friendly language.
Return only valid JSON.
''',
          },
          {
            'role': 'user',
            'content': '''
Analyze this student.

Student name: $studentName
Attendance: 92%
Quiz average: 92%
Homework: 92%
Presentation: 92%
Attitude: 92%

Return JSON only in this exact format:
{
  "summary": "...",
  "teacherNote": "...",
  "strength": "...",
  "suggestion": "..."
}
''',
          },
        ],
      }),
    );

    debugPrint('[OPENROUTER] model = $model');
    debugPrint('[OPENROUTER] status = ${response.statusCode}');
    debugPrint('[OPENROUTER] body = ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'OpenRouter error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final content = data['choices']?[0]?['message']?['content']?.toString();

    if (content == null || content.isEmpty) {
      throw Exception('OpenRouter returned empty content.');
    }

    debugPrint('[OPENROUTER] content = $content');

    try {
      return _parseAiJson(content);
    } catch (_) {
      return {
        'summary': 'AI analysis parsing failed.',
        'teacherNote': content,
        'strength': '',
        'suggestion': 'Check OpenRouter response format.',
      };
    }
  }
}
