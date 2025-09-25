// lib/login_page.dart
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'provider/hub_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _selectedHubId;

  // 드롭다운/필드 공통 색(시스템 테마 무시, 항상 밝게/선명하게)
  static const _labelColor = Color(0xFF0F172A); // slate-900
  static const _textColor = Color(0xFF111827); // neutral-900
  static const _hintColor = Color(0xFF6B7280); // gray-500
  static const _bgColor = Colors.white;
  static const _borderColor = Color(0xFFBFD6FF); // 밝은 파랑 보더
  static const _focusBorderColor = Color(0xFF7CA6FF); // 포커스 파랑
  static const _dropdownIconColor = Color(0xFF1F2937); // gray-800
  static const _menuItemHover = Color(0xFFF2F6FF); // 아주 옅은 파랑

  // 버튼 색 유지
  static const _ctaColor = Color(0xFF9370F7);

  Future<void> _continueAsGuest() async {
    if (_selectedHubId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('허브를 먼저 선택하세요.')));
      return;
    }
    final hubId = _selectedHubId!;

    context.read<HubProvider>().setHub(hubId);

    if (kIsWeb) {
      final origin = html.window.location.origin;
      final path = html.window.location.pathname;

      html.window.localStorage['hubId'] = hubId;

      final displayUrl = '$origin$path?view=display&route=/tools&hub=$hubId';
      html.window.open(displayUrl, 'displayWindow', 'width=1024,height=768');
    }

    Navigator.pushReplacementNamed(context, '/tools');
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

  // 고정 UI + 허브 선택 드롭다운
  Widget _buildFixedUI() {
    return Stack(
      children: [
        // 좌측 큰 원
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
        // 우측 큰 원
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

              // 필드/드롭다운만 로컬 테마로 강제(항상 밝은 톤)
              final localTheme = Theme.of(context).copyWith(
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: _bgColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  labelStyle: const TextStyle(
                    color: _labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                  hintStyle: const TextStyle(color: _hintColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _borderColor,
                      width: 1.4,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _borderColor,
                      width: 1.4,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _focusBorderColor,
                      width: 1.8,
                    ),
                  ),
                ),
                // 드롭다운 메뉴(팝업)도 밝은 톤으로 강제
                canvasColor: _bgColor, // 구형 위젯 호환
                dropdownMenuTheme: const DropdownMenuThemeData(
                  menuStyle: MenuStyle(
                    backgroundColor: WidgetStatePropertyAll(_bgColor),
                    surfaceTintColor: WidgetStatePropertyAll(_bgColor),
                    elevation: WidgetStatePropertyAll(8),
                    shadowColor: WidgetStatePropertyAll(Colors.black26),
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: _bgColor,
                  ),
                ),
              );

              return Theme(
                data: localTheme,
                child: Column(
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

                    // 허브 선택 드롭다운
                    SizedBox(
                      width: btnW,
                      child: DropdownButtonFormField<String>(
                        value: _selectedHubId,
                        items: const [
                          DropdownMenuItem(
                            value: 'hub-001',
                            child: Text(
                              'hub-001',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'hub-002',
                            child: Text(
                              'hub-002',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedHubId = v),
                        icon: const Icon(
                          Icons.expand_more,
                          color: _dropdownIconColor,
                        ),
                        dropdownColor: _bgColor, // 메뉴 배경을 항상 밝게
                        style: const TextStyle(
                          color: _textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          labelText: '허브 선택',
                          // hintText: '허브를 선택하세요',
                        ),
                        menuMaxHeight: 220,
                        borderRadius: BorderRadius.circular(14),
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
                            _ctaColor,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
