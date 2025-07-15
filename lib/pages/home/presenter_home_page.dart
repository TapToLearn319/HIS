// lib/pages/presenter_home_page.dart
import 'package:flutter/material.dart';// slideIndex 전역 참조
import '../../sidebar_menu.dart';

class PresenterHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(body: Scaffold(
      appBar:
          AppBar(title: const Text('Presenter Home')),
      body: Center(
        child: Text(
          'Presenter 화면\n슬라이드 '
        ),
      ),
    ), 
    selectedIndex: 0);
  }
}
