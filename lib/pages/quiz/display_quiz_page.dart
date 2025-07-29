// lib/pages/display_quiz_page.dart
import 'package:flutter/material.dart';
import '../../main.dart';   

class DisplayQuizPage extends StatelessWidget {
  const DisplayQuizPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Display Quiz Selection',
          style: TextStyle(
            fontSize: 48,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
