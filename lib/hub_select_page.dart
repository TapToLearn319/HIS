// lib/hub_select_page.dart
// 로그인 후 허브 선택 화면 (기존 첫 페이지)
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'provider/hub_provider.dart';
import 'provider/students_provider.dart';

class HubSelectPage extends StatefulWidget {
  const HubSelectPage({super.key});

  @override
  State<HubSelectPage> createState() => _HubSelectPageState();
}

class _HubSelectPageState extends State<HubSelectPage> {
  String? _selectedHubId;

  static const _labelColor = Color(0xFF0F172A);
  static const _textColor = Color(0xFF111827);
  static const _hintColor = Color(0xFF6B7280);
  static const _bgColor = Colors.white;
  static const _borderColor = Color(0xFFBFD6FF);
  static const _focusBorderColor = Color(0xFF7CA6FF);
  static const _dropdownIconColor = Color(0xFF1F2937);
  static const _ctaColor = Color(0xFF9370F7);

  Future<void> _continueToTools() async {
    if (_selectedHubId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('허브를 먼저 선택하세요.')),
      );
      return;
    }
    final hubId = _selectedHubId!;

    context.read<HubProvider>().setHub(hubId);
    context.read<StudentsProvider>().listenHub(hubId);

    if (kIsWeb) {
      final origin = html.window.location.origin;
      final path = html.window.location.pathname;
      html.window.localStorage['hubId'] = hubId;
      final displayUrl = '$origin$path?view=display&route=/tools&hub=$hubId';
      html.window.open(displayUrl, 'displayWindow', 'width=1024,height=768');
    }

    if (!mounted) return;
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
              final w = c.maxWidth;
              final h = c.maxHeight;
              final scale =
                  (w / 1440.0 < h / 720.0) ? (w / 1440.0) : (h / 720.0);
              final logoW = 647 * scale;
              final logoH = 509 * scale;
              final gap = 12 * scale;
              final btnW = 320 * scale;
              final btnH = 54 * scale;
              final radius = 28 * scale;
              final fontZ = 18 * scale;

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
                        dropdownColor: _bgColor,
                        style: const TextStyle(
                          color: _textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          labelText: '허브 선택',
                        ),
                        menuMaxHeight: 220,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    SizedBox(height: gap),
                    SizedBox(
                      width: btnW,
                      height: btnH,
                      child: ElevatedButton(
                        onPressed: _continueToTools,
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
