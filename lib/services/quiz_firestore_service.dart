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

      'activeRunId': null,
      'anonymous': settings.anonymous,
      'currentIndex': null,
      'currentQuizId': quizRefs.isNotEmpty ? quizRefs.first.id : null,
      'currentQuizIndex': 0,
      'endedAt': null,
      'phase': 'draft',
      'questionStartedAt': null,
      'questionStartedAtMs': null,
      'sessionId': null,
      'showResultsMode':
          settings.showResultsInRealTime ? 'realtime' : 'afterQuizEnds',
      'showSummaryOnDisplay': false,
      'startedAt': null,
      'status': 'draft',
      'timeLimitEnabled': settings.totalSeconds > 0,

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