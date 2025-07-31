import 'package:flutter/material.dart';
import '../../sidebar_menu.dart';  // AppScaffold
        // isDisplay 전역 플래그

/// Presenter 모드일 때 보여줄 화면
class PresenterAIChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(body:Scaffold(
      appBar: AppBar(
        title: const Text('Presenter AI'),
      ),
      body: const Center(
        child: Text(
          'Presenter AI Selection',
          style: TextStyle(fontSize: 24),
        ),
      ),),
      selectedIndex: 4, // 사이드바에서 퀴즈 선택 메뉴 인덱스
      
    );
  }
}