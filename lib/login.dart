// lib/login_page.dart
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  void _continueAsGuest() {
    if (kIsWeb) {
      final origin = html.window.location.origin;
      final path   = html.window.location.pathname;
      final displayUrl =
          '$origin$path?view=display&route=/home';
      html.window.open(
        displayUrl,
        'displayWindow',
        'width=1024,height=768',
      );
    }
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24),
          children: <Widget>[
            const SizedBox(height: 80),
            Column(
              children: [
                const Text("My Button"),
                Image.asset(
                  'assets/flicbutton.png',
                  width: 400,
                  height: 400,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Continue as Guest'),
              onPressed: _continueAsGuest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF397751),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
