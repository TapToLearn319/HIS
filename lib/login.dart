// lib/login_page.dart
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';                // ★ 추가
import 'provider/hub_provider.dart';                    // ★ 추가
import 'package:flutter_arc_text/flutter_arc_text.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _selectedHubId; // ★ 선택된 허브

  Future<void> _continueAsGuest() async {
    if (_selectedHubId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('허브를 먼저 선택하세요.')),
      );
      return;
    }
    final hubId = _selectedHubId!;

    // ★ HubProvider에 허브 값 전달
    context.read<HubProvider>().setHub(hubId);

    // 웹: 선택한 허브를 로컬에 저장 + 디스플레이 창에도 쿼리로 전달
    if (kIsWeb) {
      final origin = html.window.location.origin;
      final path = html.window.location.pathname;

      // 선택값 저장(프리젠터 탭에서 사용)
      html.window.localStorage['hubId'] = hubId;

      // 디스플레이 창에도 허브 전달
      final displayUrl = '$origin$path?view=display&route=/tools&hub=$hubId';
      html.window.open(displayUrl, 'displayWindow', 'width=1024,height=768');
    }

    // 프리젠터 라우팅 (메인 앱은 localStorage / query에서 허브를 읽어 사용)
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

  // 고정 UI + 허브 선택 드롭다운 추가
  Widget _buildFixedUI() {
    return Stack(
      children: [
        Positioned(
          left: -98, top: 175,
          child: Container(width: 563, height: 563,
            decoration: const BoxDecoration(color: Color(0XFFDCFE83), shape: BoxShape.circle),
          ),
        ),
        Positioned(
          right: -192, top: -262,
          child: Container(width: 667, height: 667,
            decoration: const BoxDecoration(color: Color(0xFFC4F6FE), shape: BoxShape.circle),
          ),
        ),

        Align(
          alignment: Alignment.center,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth, h = c.maxHeight;
              final scale = (w / 1440.0 < h / 720.0) ? (w / 1440.0) : (h / 720.0);

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
                        width: logoW, height: logoH, fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: gap),

                  // 허브 선택 드롭다운 (고정: hub-001 / hub-002)
                  SizedBox(
                    width: btnW,
                    child: DropdownButtonFormField<String>(
                      value: _selectedHubId,
                      items: const [
                        DropdownMenuItem(value: 'hub-001', child: Text('hub-001')),
                        DropdownMenuItem(value: 'hub-002', child: Text('hub-002')),
                      ],
                      onChanged: (v) => setState(() => _selectedHubId = v),
                      decoration: const InputDecoration(
                        labelText: '허브 선택',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(height: gap),

                  // 시작 버튼
                  SizedBox(
                    width: btnW, height: btnH,
                    child: ElevatedButton(
                      onPressed: _continueAsGuest,
                      style: ButtonStyle(
                        backgroundColor: const WidgetStatePropertyAll(Color(0xFF9370F7)),
                        foregroundColor: const WidgetStatePropertyAll(Colors.white),
                        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                        overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.08)),
                        elevation: const WidgetStatePropertyAll(0),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
                        ),
                        side: const WidgetStatePropertyAll(BorderSide.none),
                      ),
                      child: Text("Let's begin",
                        style: TextStyle(fontSize: fontZ, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  SizedBox(height: 10 * scale),

                  Opacity(
                    opacity: 0.85,
                    child: Text(
                      "© 2025 Team MyButton. All rights reserved.",
                      style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
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
