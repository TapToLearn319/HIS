import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project/sidebar_menu.dart';
import 'topic_list_and_dialogs.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';

class PresenterQuizPage extends StatefulWidget {
  const PresenterQuizPage({super.key});

  @override
  State<PresenterQuizPage> createState() => _PresenterQuizPageState();
}

class _PresenterQuizPageState extends State<PresenterQuizPage> {
  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) => _resetRunningQuizzesOnce());
}

  /// 🔹 퀴즈 페이지 들어올 때 기존 running 상태 모두 초기화
 bool _hasResetDone = false;

Future<void> _resetRunningQuizzesOnce() async {
  if (_hasResetDone) return; // ✅ 이미 한 번 했으면 다시 하지 않음
  _hasResetDone = true;

  final hubPath = context.read<HubProvider>().hubDocPath;
  if (hubPath == null) return;
  final fs = FirebaseFirestore.instance;

  try {
    // 🔹 짧은 딜레이 (Firestore 연결 안정화용)
    await Future.delayed(const Duration(milliseconds: 800));

    final runningDocs = await fs
        .collection('$hubPath/quizTopics')
        .where('status', isEqualTo: 'running')
        .get();

    if (runningDocs.docs.isNotEmpty) {
      for (final doc in runningDocs.docs) {
        await doc.reference.update({'status': 'finished'});
      }
      debugPrint('✅ stale running quizzes cleared once');
    } else {
      debugPrint('ℹ️ no running quizzes to reset');
    }
  } catch (e) {
    debugPrint('⚠️ resetRunningQuizzes error: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      selectedIndex: 0,
      body: Scaffold(
        backgroundColor: const Color(0xFFF6FAFF),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF6FAFF),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back,
            color: Colors.black),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Quiz',
                  style: TextStyle(color: Colors.black)),
        ),
        body: const TopicList(),
      ),
    );
  }
}
