// lib/pages/quiz/presenter_quiz_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';
// 같은 폴더에 둘 파일들
import 'topic_list_and_dialogs.dart'; // _TopicList, _CreateTopicFab에서 사용

// ====================== Global Consts ======================

// 집계용(다른 파일에서 참조 가능). 허브/TS 수정은 아직 적용하지 않음.
const String kHubId = 'hub-001';

// 둥둥 뜨는 FAB/아이콘 에셋(다른 파일에서도 import로 참조)
const String kFabCreateTopicAsset = 'assets/icons/fab_create_topic.png';
const String kFabAddQuizAsset = 'assets/icons/fab_add_quiz.png';
const String kSaveIconAsset = 'assets/icons/save_quiz.png';

// ====================== Entry Page ======================

/// Presenter Quiz (Top-level shell)
class PresenterQuizPage extends StatelessWidget {
  const PresenterQuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 246, 250, 255),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Quiz (Presenter)'),
      ),
      body: Stack(
        children: const [
          TopicList(),     // ← topic_list_and_dialogs.dart 로 이동
          CreateTopicFab() // ← topic_list_and_dialogs.dart 로 이동
        ],
      ),
    );
  }
}

// ====================== Shared Utils ======================

void _snack(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  (m ?? ScaffoldMessenger.of(context))
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> _maybeStopRunningTopic({
  required String status,
  required String topicId,
}) async {
  if (status != 'running') return;
  final fs = FirebaseFirestore.instance;
  await fs.doc('quizTopics/$topicId').set({
    'status': 'stopped',
    'phase': 'finished',
    'currentIndex': null,
    'currentQuizId': null,
    'endedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'showSummaryOnDisplay': false,
  }, SetOptions(merge: true));
}
