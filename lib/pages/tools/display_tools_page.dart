// lib/pages/display_quiz_page.dart
import 'package:flutter/material.dart';
import '../../main.dart';   

class DisplayToolsPage extends StatelessWidget {
  const DisplayToolsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color.fromARGB(255, 224, 41, 148),
      body: Center(
        child: Text(
          'Display tools Selection',
          style: TextStyle(
            fontSize: 48,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
