import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/generated_quiz_models.dart';

class QuizFirestoreService {
  QuizFirestoreService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> createAndSaveGeneratedQuizSet({
    required String hubId,
    required String sourceFileName,
    required String bundleTitle,
    required List<GeneratedQuizQuestion> questions,
    required QuizSettingsModel settings,
  }) async {
    final topicRef = _firestore
        .collection('hubs')
        .doc(hubId)
        .collection('quizTopics')
        .doc();

    final quizzesRef = topicRef.collection('quizzes');
    final batch = _firestore.batch();

    final quizRefs = questions.map((_) => quizzesRef.doc()).toList();

    batch.set(topicRef, {
  'title': bundleTitle,
  'sourceFileName': sourceFileName,
  'questionCount': questions.length,
  'totalQuizCount': questions.length,

  // 실행 관련 상태: 생성 직후에는 아직 시작 안 된 상태
  'activeRunId': null,
  'sessionId': null,
  'status': 'draft',
  'phase': 'draft',

  // 현재 문항 없음
  'currentIndex': null,
  'currentQuizId': null,
  'currentQuizIndex': null,

  // 시간/응답 상태 초기화
  'startedAt': null,
  'endedAt': null,
  'questionStartedAt': null,
  'questionStartedAtMs': null,
  'showSummaryOnDisplay': false,

  // 설정값
  'anonymous': settings.anonymous,
  'showResultsMode':
      settings.showResultsInRealTime ? 'realtime' : 'afterQuizEnds',
  'timeLimitEnabled': settings.totalSeconds > 0,

  // AI 생성 정보
  'generatedByAI': true,
  'settings': settings.toMap(),

  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});

    final bindings = [
      {'button': 1, 'gesture': 'single'},
      {'button': 2, 'gesture': 'single'},
      {'button': 1, 'gesture': 'hold'},
      {'button': 2, 'gesture': 'hold'},
    ];

    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final quizDoc = quizRefs[i];

      final optionMaps = List.generate(4, (optionIndex) {
        return {
          'title': question.options[optionIndex].text,
          'binding': bindings[optionIndex],
        };
      });

      final correctBinding = bindings[question.correctIndex];

      batch.set(quizDoc, {
        'allowMultiple': settings.multipleSelections,
        'correctBinding': correctBinding,
        'createdAt': FieldValue.serverTimestamp(),
        'options': optionMaps,
        'public': settings.isPublic,
        'question': question.question,
        'status': 'draft',
        'updatedAt': FieldValue.serverTimestamp(),
        'votes': [0, 0, 0, 0],
        'votesByDevice': <String, dynamic>{},

        'sourceFileName': sourceFileName,
        'generatedByAI': true,
        'order': i,
        'index': i,
        'topicId': topicRef.id,
      });
    }

    await batch.commit();
    return topicRef.id;
  }
}