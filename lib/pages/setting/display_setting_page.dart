// lib/pages/display_quiz_page.dart
import 'package:flutter/material.dart';
import '../../main.dart';   

class DisplaySettingPage extends StatelessWidget {
  const DisplaySettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color.fromARGB(255, 41, 224, 215),
      body: Center(
        child: Text(
          '🔹 Display setting Selection',
          style: TextStyle(
            fontSize: 48,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
