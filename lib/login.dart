



// lib/login_page.dart
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_arc_text/flutter_arc_text.dart';

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
          '$origin$path?view=display&route=/tools';
      html.window.open(
        displayUrl,
        'displayWindow',
        'width=1024,height=768',
      );
    }
    Navigator.pushReplacementNamed(context, '/tools');
  }

  static const _underlineColor = Color(0xFF354070);
  InputDecoration _dec(String label) => const InputDecoration(
    labelText: '',
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: _underlineColor, width: 1.5),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: _underlineColor, width: 1.5),
    ),
  );

  Widget _underlineField(String label, {bool obscure = false}) {
    return SizedBox(
      width: 542,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label,
              style: const TextStyle(
                color: _underlineColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextField(
            obscureText: obscure,
            decoration: _dec(label),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 246, 250, 255),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = constraints.maxWidth;
          double screenHeight = constraints.maxHeight;

          // 화면이 충분히 크면 → 비율 확대 (현재 옵션 2 방식)
          if (screenWidth >= 1440 && screenHeight >= 720) {
            double targetAspectRatio = 1440 / 720;
            double containerWidth;
            double containerHeight;

            if (screenWidth / screenHeight > targetAspectRatio) {
              containerHeight = screenHeight;
              containerWidth = screenHeight * targetAspectRatio;
            } else {
              containerWidth = screenWidth;
              containerHeight = screenWidth / targetAspectRatio;
            }

            return Center(
              child: SizedBox(
                width: containerWidth,
                height: containerHeight,
                child: _buildFixedUI(),
              ),
            );
          }

          // 화면이 작으면 → 1440×720 고정 + 스크롤
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Center(
              child: SizedBox(
                width: 1440,
                height: 720,
                child: _buildFixedUI(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFixedUI() {
    return Stack(
      children: [
        /// ✅ 배경 원
        Positioned(
          left: -98,
          top: 175,
          child: Container(
            width: 563,
            height: 563,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 223, 253, 126),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: -192,
          top: -262,
          child: Container(
            width: 667,
            height: 667,
            decoration: const BoxDecoration(
              color: Color(0xFFC4F6FE),
              shape: BoxShape.circle,
            ),
          ),
        ),

        /// ✅ 메인 콘텐츠
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: <Widget>[
              // const SizedBox(height: 50),

              Center(
            child: Column(
              children: [
                
                const SizedBox(height: 8),
                Image.asset('assets/logo_bird_main.png', width: 501, height: 344),
              ],
            ),
          ),

          //     Align(alignment: Alignment.center, child: _underlineField('Full Name')),
          // const SizedBox(height: 24),
          // Align(alignment: Alignment.center, child: _underlineField('Email')),
          // const SizedBox(height: 24),
          // Align(alignment: Alignment.center, child: _underlineField('Password', obscure: true)),

              // SizedBox(
              //   width: 542,
              //   height: 1.5,
              //   child: const TextField(
              //     decoration: InputDecoration(
              //       labelText: "Full Name",
              //       labelStyle: TextStyle(fontWeight: FontWeight.w500),
              //       enabledBorder: UnderlineInputBorder(
              //         borderSide: BorderSide(color: Color(0xFF354070)),
              //       ),
              //     ),
              //   ),
              // ),
             
              const SizedBox(height: 16),

              // Align(
              //   alignment: Alignment.center,
              //   child: SizedBox(
              //     width: 542,
              //     child: const TextField(
              //       decoration: InputDecoration(
              //         labelText: "Email",
              //         labelStyle: TextStyle(fontWeight: FontWeight.w900),
              //         enabledBorder: UnderlineInputBorder(
              //           borderSide: BorderSide(color: Colors.black),
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 16),

              // Align(
              //   alignment: Alignment.center,
              //   child: SizedBox(
              //     width: 542,
              //     child: const TextField(
              //       obscureText: true,
              //       decoration: InputDecoration(
              //         labelText: "Password",
              //         labelStyle: TextStyle(fontWeight: FontWeight.w900),
              //         enabledBorder: UnderlineInputBorder(
              //           borderSide: BorderSide(color: Colors.black),
              //         ),
              //       ),
              //     ),
              //   ),
              // ),

              // const SizedBox(height: 32),

              Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 281, height: 47,
              child: ElevatedButton(
                onPressed: _continueAsGuest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9370F7), // 원하던 색
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: const Text("Let's begin", style: TextStyle(fontSize: 18)),
              ),
            ),
          ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Center(
                  child: Text(
                    "© 2025 Team MyButton. All rights reserved.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                )
              )

              // Center(
              //   child: RichText(
              //     text: const TextSpan(
              //       text: "Already have an account? ",
              //       style: TextStyle(color: Colors.black, fontSize: 14),
              //       children: [
              //         TextSpan(
              //           text: "Login",
              //           style: TextStyle(
              //             color: Color.fromARGB(255, 251, 211, 103),
              //             fontWeight: FontWeight.bold,
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ],
    );
  }
}