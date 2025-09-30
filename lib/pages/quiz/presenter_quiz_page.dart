// lib/pages/quiz/presenter_quiz_page.dart
import 'package:flutter/material.dart';
import 'package:project/sidebar_menu.dart';
import 'topic_list_and_dialogs.dart';

class PresenterQuizPage extends StatelessWidget {
  const PresenterQuizPage({super.key});

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
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text('Quiz'),
        ),
        body: const TopicList(), // HubProvider는 TopicList 내부에서 사용
      ),
    );
  }
}