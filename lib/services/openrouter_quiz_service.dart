import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/generated_quiz_models.dart';

class QuizGenerationException implements Exception {
  final int? statusCode;
  final String message;
  final String? rawBody;
  final String? modelTried;

  QuizGenerationException({
    required this.message,
    this.statusCode,
    this.rawBody,
    this.modelTried,
  });

  @override
  String toString() {
    final codePart = statusCode != null ? '[$statusCode] ' : '';
    final modelPart = modelTried != null ? ' (model: $modelTried)' : '';
    return '$codePart$message$modelPart';
  }
}

class OpenRouterQuizService {
  OpenRouterQuizService({
    required this.apiKey,
    this.primaryModel = 'google/gemma-4-26b-a4b-it:free',
    this.siteUrl = '',
    this.siteName = 'MyButton AI Helper',
  });

  final String apiKey;
  final String primaryModel;
  final String siteUrl;
  final String siteName;

  static const String _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';

  static const List<String> _fallbackModels = [
    'google/gemma-4-26b-a4b-it:free',
    'qwen/qwen-2.5-72b-instruct:free',
    'meta-llama/llama-3.3-70b-instruct:free',
    'mistralai/mistral-small-3.2-24b-instruct:free',
  ];

  String extractTextFromPdfBytes(Uint8List pdfBytes) {
    print('📄 [PDF] extractTextFromPdfBytes 시작');
    print('📄 [PDF] bytes length = ${pdfBytes.length}');

    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final String text = extractor.extractText();
    document.dispose();

    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    print('📄 [PDF] 원본 추출 길이 = ${text.length}');
    print('📄 [PDF] 정리 후 길이 = ${cleaned.length}');
    print(
      '📄 [PDF] 미리보기 = ${cleaned.length > 200 ? cleaned.substring(0, 200) : cleaned}',
    );

    return cleaned;
  }

  Future<GeneratedQuizBundle> generateQuizBundle({
    required Uint8List pdfBytes,
    required String fileName,
    String userPrompt = '',
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🚀 [AI] generateQuizBundle 시작');
    print('🚀 [AI] primaryModel = $primaryModel');
    print('🚀 [AI] fileName = $fileName');
    print(
      '🚀 [AI] userPrompt = ${userPrompt.trim().isEmpty ? '(empty)' : userPrompt}',
    );
    print('🚀 [AI] apiKey length = ${apiKey.length}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final extractedText = extractTextFromPdfBytes(pdfBytes);

    if (extractedText.isEmpty) {
      throw QuizGenerationException(
        message: 'PDF에서 읽을 수 있는 텍스트를 찾지 못했습니다.',
      );
    }

    final limitedText = extractedText.length > 4000
        ? extractedText.substring(0, 4000)
        : extractedText;

    print('✂️ [AI] limitedText length = ${limitedText.length}');

    final modelsToTry = <String>[
      primaryModel,
      ..._fallbackModels.where((m) => m != primaryModel),
    ];

    QuizGenerationException? lastError;

    for (final model in modelsToTry) {
      try {
        print('🟡 [MODEL] 시도 시작: $model');

        final bundle = await _generateWithModel(
          model: model,
          fileName: fileName,
          limitedText: limitedText,
          userPrompt: userPrompt,
        );

        print('✅ [MODEL] 성공: $model');
        return bundle;
      } on QuizGenerationException catch (e) {
        lastError = e;

        print('❌ [MODEL] 실패: $model');
        print('❌ [MODEL] error = $e');

        final shouldTryNextModel =
            e.statusCode == 429 || e.statusCode == 503 || e.statusCode == 502;

        if (!shouldTryNextModel) {
          rethrow;
        }

        print('🔁 [MODEL] 다음 fallback 모델 시도 예정');
      }
    }

    throw lastError ??
        QuizGenerationException(
          message: '퀴즈 생성에 실패했습니다.',
        );
  }

  Future<GeneratedQuizBundle> _generateWithModel({
    required String model,
    required String fileName,
    required String limitedText,
    required String userPrompt,
  }) async {
    final requestBody = {
      'model': model,
      'temperature': 0.4,
      'messages': [
        {
          'role': 'user',
          'content': '''
You are an educational quiz generator.

Generate exactly 5 multiple-choice questions from the PDF text below.

IMPORTANT OUTPUT RULES:
Return JSON only.
Do not include markdown.
Do not include explanation outside JSON.

Use exactly this JSON structure:

{
  "title": "Short quiz title",
  "questions": [
    {
      "question": "Question text",
      "choices": ["Choice A", "Choice B", "Choice C", "Choice D"],
      "answer": "The exact correct choice text"
    }
  ]
}

Rules:
- There must be exactly 5 questions.
- Each question must have exactly 4 choices.
- Only one choice can be correct.
- The answer value must exactly match one of the 4 choices.
- Do not use "all of the above" or "none of the above".

File name: $fileName

Additional user request:
${userPrompt.trim().isEmpty ? 'None' : userPrompt}

PDF text:
$limitedText
'''
        }
      ],
    };

    QuizGenerationException? last429Error;

    for (int attempt = 1; attempt <= 2; attempt++) {
      http.Response response;

      try {
        print('🌐 [OPENROUTER] 요청 시작');
        print('🌐 [OPENROUTER] model = $model');
        print('🌐 [OPENROUTER] attempt = $attempt');
        print(
          '🌐 [OPENROUTER] request body size = ${jsonEncode(requestBody).length}',
        );

        response = await http.post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            if (siteUrl.isNotEmpty) 'HTTP-Referer': siteUrl,
            if (siteName.isNotEmpty) 'X-Title': siteName,
          },
          body: jsonEncode(requestBody),
        );

        print('✅ [OPENROUTER] 응답 수신 완료');
        print('✅ [OPENROUTER] statusCode = ${response.statusCode}');
        print('✅ [OPENROUTER] response body = ${response.body}');
      } catch (e, st) {
        print('❌ [OPENROUTER] 네트워크 요청 중 예외 발생');
        print('❌ [OPENROUTER] error = $e');
        print('❌ [OPENROUTER] stack = $st');

        throw QuizGenerationException(
          message: '네트워크 요청 중 오류가 발생했습니다.',
          modelTried: model,
        );
      }

      if (response.statusCode == 429) {
        last429Error = QuizGenerationException(
          statusCode: 429,
          message: _extract429Message(response.body),
          rawBody: response.body,
          modelTried: model,
        );

        print('⏳ [429] 잠시 대기 후 재시도');

        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 2 * attempt));
          continue;
        } else {
          throw last429Error;
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw QuizGenerationException(
          statusCode: response.statusCode,
          message: _buildHttpErrorMessage(response.statusCode, response.body),
          rawBody: response.body,
          modelTried: model,
        );
      }

      return _parseOpenRouterResponse(
        responseBody: response.body,
        fileName: fileName,
        model: model,
      );
    }

    throw last429Error ??
        QuizGenerationException(
          statusCode: 429,
          message: '요청 제한에 걸렸습니다.',
          modelTried: model,
        );
  }

  GeneratedQuizBundle _parseOpenRouterResponse({
    required String responseBody,
    required String fileName,
    required String model,
  }) {
    try {
      print('🧩 [PARSE] 응답 JSON 파싱 시작');

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;

      if (choices == null || choices.isEmpty) {
        throw QuizGenerationException(
          message: 'AI 응답이 비어 있습니다.',
          modelTried: model,
        );
      }

      final content = (((choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>)['content'])
          .toString()
          .trim();

      print('🧩 [PARSE] message content = $content');

      final cleanedContent = _cleanJsonContent(content);
      final parsed = jsonDecode(cleanedContent) as Map<String, dynamic>;

      print('🧩 [PARSE] parsed keys = ${parsed.keys.toList()}');

      final title =
          _firstString(parsed, ['title', 'quizTitle', 'name']).isNotEmpty
              ? _firstString(parsed, ['title', 'quizTitle', 'name'])
              : fileName.replaceAll('.pdf', '');

      final rawQuestions = _extractQuestionList(parsed);

      print('🧩 [PARSE] title = $title');
      print('🧩 [PARSE] questions count = ${rawQuestions.length}');

      if (rawQuestions.length < 5) {
        throw QuizGenerationException(
          message: 'AI가 정확히 5문제를 만들지 못했습니다.',
          modelTried: model,
        );
      }

      final questions = <GeneratedQuizQuestion>[];

      for (final item in rawQuestions.take(5)) {
        final q = Map<String, dynamic>.from(item as Map);

        print('📝 [RAW QUESTION] $q');

        final parsedQuestion = _parseQuestionMap(q, model);
        questions.add(parsedQuestion);
      }

      print('🎉 [AI] 퀴즈 생성 성공');
      print('🎉 [AI] 최종 문제 수 = ${questions.length}');

      return GeneratedQuizBundle(
        title: title,
        questions: questions,
      );
    } on QuizGenerationException {
      rethrow;
    } catch (e, st) {
      print('❌ [PARSE] 응답 해석 중 예외 발생');
      print('❌ [PARSE] error = $e');
      print('❌ [PARSE] stack = $st');

      throw QuizGenerationException(
        message: 'AI 응답 해석 중 오류가 발생했습니다.',
        modelTried: model,
      );
    }
  }

  GeneratedQuizQuestion _parseQuestionMap(
    Map<String, dynamic> q,
    String model,
  ) {
    final questionText = _firstString(
      q,
      [
        'question',
        'questionText',
        'prompt',
        'text',
        'title',
      ],
    );

    final answerText = _firstString(
      q,
      [
        'answer',
        'correctAnswer',
        'correct',
        'correct_choice',
        'correctChoice',
        'rightAnswer',
      ],
    );

    List<String> choices = _extractChoices(q);

    // correctAnswer + wrongAnswers 구조도 처리
    if (choices.isEmpty) {
      final correctAnswer = _firstString(q, ['correctAnswer', 'answer']);
      final wrongAnswersRaw = q['wrongAnswers'] ?? q['incorrectAnswers'];

      if (correctAnswer.isNotEmpty && wrongAnswersRaw is List) {
        final wrongAnswers = wrongAnswersRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();

        choices = [correctAnswer, ...wrongAnswers];
      }
    }

    print('📝 [QUESTION] question = $questionText');
    print('📝 [QUESTION] choices = $choices');
    print('📝 [QUESTION] answer = $answerText');

    if (questionText.isEmpty) {
      throw QuizGenerationException(
        message: '문제 본문이 비어 있습니다.',
        modelTried: model,
      );
    }

    if (choices.length < 4) {
      throw QuizGenerationException(
        message: '보기 개수가 4개보다 적습니다.',
        modelTried: model,
      );
    }

    choices = choices.take(4).toList();

    int correctIndex = _findCorrectIndex(
      choices: choices,
      answerText: answerText,
      q: q,
    );

    if (correctIndex == -1) {
      throw QuizGenerationException(
        message: '정답이 보기 4개 안에 없습니다.',
        modelTried: model,
      );
    }

    return GeneratedQuizQuestion(
      question: questionText,
      correctIndex: correctIndex,
      options: choices.map((e) => QuizOptionItem(text: e)).toList(),
      isEnabled: true,
      isExpanded: false,
    );
  }

  List<dynamic> _extractQuestionList(Map<String, dynamic> parsed) {
    final candidates = [
      parsed['questions'],
      parsed['quiz'],
      parsed['items'],
      parsed['data'],
    ];

    for (final c in candidates) {
      if (c is List) return c;
    }

    return [];
  }

  List<String> _extractChoices(Map<String, dynamic> q) {
    final candidates = [
      q['choices'],
      q['options'],
      q['answers'],
      q['selections'],
      q['choiceList'],
    ];

    for (final raw in candidates) {
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      if (raw is Map) {
        return raw.values
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    // A/B/C/D 키로 오는 경우 처리
    final abcd = ['A', 'B', 'C', 'D']
        .map((k) => q[k]?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    if (abcd.length == 4) return abcd;

    final lowerAbcd = ['a', 'b', 'c', 'd']
        .map((k) => q[k]?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    if (lowerAbcd.length == 4) return lowerAbcd;

    return [];
  }

  int _findCorrectIndex({
    required List<String> choices,
    required String answerText,
    required Map<String, dynamic> q,
  }) {
    final possibleIndex = q['correctIndex'] ?? q['answerIndex'];

    if (possibleIndex is int && possibleIndex >= 0 && possibleIndex < 4) {
      return possibleIndex;
    }

    if (possibleIndex is num && possibleIndex >= 0 && possibleIndex < 4) {
      return possibleIndex.toInt();
    }

    final answerLetter = _firstString(
      q,
      ['answerLetter', 'correctLetter', 'correctOption'],
    ).toUpperCase();

    if (answerLetter == 'A') return 0;
    if (answerLetter == 'B') return 1;
    if (answerLetter == 'C') return 2;
    if (answerLetter == 'D') return 3;

    if (answerText.isEmpty) return -1;

    final exactIndex = choices.indexOf(answerText);
    if (exactIndex != -1) return exactIndex;

    final normalizedAnswer = _normalize(answerText);

    for (int i = 0; i < choices.length; i++) {
      if (_normalize(choices[i]) == normalizedAnswer) {
        return i;
      }
    }

    for (int i = 0; i < choices.length; i++) {
      if (_normalize(choices[i]).contains(normalizedAnswer) ||
          normalizedAnswer.contains(_normalize(choices[i]))) {
        return i;
      }
    }

    return -1;
  }

  String _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];

      if (value == null) continue;

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is num || value is bool) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _cleanJsonContent(String content) {
    var cleaned = content.trim();

    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7).trim();
    }

    if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3).trim();
    }

    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3).trim();
    }

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    return cleaned;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s가-힣]'), '')
        .trim();
  }

  String _extract429Message(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      final metadata = error?['metadata'] as Map<String, dynamic>?;
      final raw = metadata?['raw']?.toString();

      if (raw != null && raw.isNotEmpty) return raw;

      return error?['message']?.toString() ?? '요청 제한에 걸렸습니다.';
    } catch (_) {
      return '요청 제한에 걸렸습니다.';
    }
  }

  String _buildHttpErrorMessage(int statusCode, String body) {
    switch (statusCode) {
      case 400:
        return '잘못된 요청입니다. 입력값이나 요청 형식을 확인해주세요.';
      case 401:
        return 'API 키가 올바르지 않거나 인증에 실패했습니다.';
      case 402:
        return '결제 또는 크레딧 문제가 있습니다. OpenRouter 사용량을 확인해주세요.';
      case 403:
        return '접근 권한이 없습니다.';
      case 404:
        return '요청한 모델 또는 경로를 찾을 수 없습니다.';
      case 408:
        return '요청 시간이 초과되었습니다.';
      case 413:
        return '입력 데이터가 너무 큽니다. PDF 내용 길이를 줄여주세요.';
      case 429:
        return _extract429Message(body);
      case 500:
        return '서버 내부 오류가 발생했습니다.';
      case 502:
        return '게이트웨이 오류가 발생했습니다.';
      case 503:
        return '서비스를 일시적으로 사용할 수 없습니다.';
      case 504:
        return '응답 대기 시간이 초과되었습니다.';
      default:
        final compactBody = body.trim().isEmpty ? '' : '\n$body';
        return '퀴즈 생성 요청에 실패했습니다.$compactBody';
    }
  }
}