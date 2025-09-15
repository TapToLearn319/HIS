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
      final path = html.window.location.pathname;
      final displayUrl = '$origin$path?view=display&route=/tools';
      html.window.open(displayUrl, 'displayWindow', 'width=1024,height=768');
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
          TextField(obscureText: obscure, decoration: _dec(label)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: 1440, height: 720, child: _buildFixedUI()),
        ),
      ),
    );
  }

  // 원 도형
  Widget _buildFixedUI() {
    return Stack(
      children: [
        Positioned(
          left: -98,
          top: 175,
          child: Container(
            width: 563,
            height: 563,
            decoration: const BoxDecoration(
              color: Color(0XFFDCFE83),
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

        Align(
          alignment: Alignment.center,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth, h = c.maxHeight;
              final scale =
                  (w / 1440.0 < h / 720.0) ? (w / 1440.0) : (h / 720.0);

              final logoW = 647 * scale;
              final logoH = 509 * scale;
              final gap = 12 * scale;
              final btnW = 320 * scale;
              final btnH = 54 * scale;
              final radius = 28 * scale;
              final fontZ = 18 * scale;

              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고
                  ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: 0.80,
                      child: Image.asset(
                        'assets/logo_bird_main.png',
                        width: logoW,
                        height: logoH,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: gap),

                  // 시작 버튼
                  SizedBox(
                    width: btnW,
                    height: btnH,
                    child: ElevatedButton(
                      onPressed: _continueAsGuest,
                      style: ButtonStyle(
                        backgroundColor: const WidgetStatePropertyAll(
                          Color(0xFF9370F7),
                        ),
                        foregroundColor: const WidgetStatePropertyAll(
                          Colors.white,
                        ),
                        shadowColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        overlayColor: WidgetStatePropertyAll(
                          Colors.white.withOpacity(0.08),
                        ),
                        elevation: const WidgetStatePropertyAll(0),

                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius),
                          ),
                        ),
                        side: const WidgetStatePropertyAll(BorderSide.none),
                      ),
                      child: Text(
                        "Let's begin",
                        style: TextStyle(
                          fontSize: fontZ,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 10 * scale),

                  // 하단 저작권
                  Opacity(
                    opacity: 0.85,
                    child: Text(
                      "© 2025 Team MyButton. All rights reserved.",
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
