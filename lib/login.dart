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
          right: -250,
          top: -267,
          child: Container(
            width: 667,
            height: 667,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 239, 191, 251),
              shape: BoxShape.circle,
            ),
          ),
        ),

        /// ✅ 메인 콘텐츠
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: <Widget>[
              const SizedBox(height: 50),

              /// 이미지 + ArcText
              Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/flicbutton.png',
                        width: 451,
                        height: 300,
                      ),
                      Transform.translate(
                        offset: const Offset(0, -20),
                        child: ArcText(
                          radius: 65,
                          text: "My Button",
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 40,
                            color: Color.fromARGB(255, 53, 64, 112),
                          ),
                          startAngle: -2.8 / 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Align(
              //   alignment: Alignment.center,
              //   child: SizedBox(
              //     width: 542,
              //     child: const TextField(
              //       decoration: InputDecoration(
              //         labelText: "Full Name",
              //         labelStyle: TextStyle(fontWeight: FontWeight.w900 ),
              //         enabledBorder: UnderlineInputBorder(
              //           borderSide: BorderSide(color: Colors.black),
              //         ),
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
              const SizedBox(height: 16),

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

              const SizedBox(height: 32),

              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 281,
                  height: 47,
                  child: ElevatedButton(
                    onPressed: _continueAsGuest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color.fromARGB(255, 100, 122, 220),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Let's begin",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: RichText(
                  text: const TextSpan(
                    text: "Already have an account? ",
                    style: TextStyle(color: Colors.black, fontSize: 14),
                    children: [
                      TextSpan(
                        text: "Login",
                        style: TextStyle(
                          color: Color.fromARGB(255, 251, 211, 103),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
