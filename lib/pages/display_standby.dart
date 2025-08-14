// lib/pages/display_quiz_page.dart
import 'package:flutter/material.dart';
import '../../main.dart';   

class DisplayStandByPage extends StatelessWidget {
  const DisplayStandByPage ({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 246, 250, 255),
      body: Center(
        child: Image.asset(
          'logo_bird_standby.png',
          ),
        ),
      );
    
  }
}
