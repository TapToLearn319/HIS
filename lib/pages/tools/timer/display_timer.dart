import 'dart:convert';
import 'package:flutter/material.dart';
// 메인의 BroadcastChannel을 그대로 사용 (방식 유지)
import 'package:project/main.dart' as app show channel;

class DisplayTimerPage extends StatefulWidget {
  const DisplayTimerPage({super.key});

  @override
  State<DisplayTimerPage> createState() => _DisplayTimerPageState();
}

class _DisplayTimerPageState extends State<DisplayTimerPage> {
  // === 스타일(너가 쓰던 베이스) ===
  static const double _cardWidth   = 680;
  static const double _birdSize    = 200;
  static const double _birdRight   = -60;
  static const double _birdBottom  = -50;

  static const double _iconLeftInset = 36;
  static const double _iconBoxSize   = 124;
  static const double _iconSize      = 68;
  static const double _gapAfterIcon  = 22;
  static const double _digitsShiftX  = -48;

  // === 표시 상태 ===
  int minutes = 0;
  int seconds = 0;
  bool isRunning = false;

  String get _birdAsset => isRunning ? "logo_bird_stop.png" : "logo_bird_start.png";

  double _uiScale(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final targetWidth = size.width / 3;   // 목표: 화면 가로의 1/3
  return (targetWidth / _cardWidth).clamp(0.5, 2.0).toDouble();
}

  @override
  void initState() {
    super.initState();

    // 디스플레이 모드 힌트(선택)
    _postSafe({'type': 'tool_mode', 'mode': 'display_timer'});

    // 선생님 화면에 현재 상태 한번만 요청 (늦게 켜져도 즉시 싱크)
    _postSafe({'type': 'timer_status_request'});

    // 채널 수신
    app.channel.onMessage.listen((event) {
      try {
        final raw = event.data; // MessageEvent.data
        final Map<String, dynamic> msg = raw is String
            ? (jsonDecode(raw) as Map<String, dynamic>)
            : (raw as Map).cast<String, dynamic>();

        if (msg['type'] == 'timer') {
          final m = (msg['minutes'] ?? 0) as int;
          final s = (msg['seconds'] ?? 0) as int;
          final running = (msg['isRunning'] ?? false) as bool;
          if (!mounted) return;
          setState(() {
            minutes = m.clamp(0, 99);
            seconds = s.clamp(0, 59);
            isRunning = running;
          });
        }
        // route/slide 등 다른 메시지는 무시
      } catch (_) {
        // 무시
      }
    });
  }

  void _postSafe(Map<String, dynamic> data) {
    try {
      app.channel.postMessage(jsonEncode(data));
    } catch (_) {}
  }

  Widget _responsiveDisplayCard() {
  final scale = _uiScale(context);

  // 새 이미지가 카드 밖으로 나가므로, 잘리지 않게 여유 공간 확보
  const double cardHeight = 124 + 40.0;     // 아이콘 124 + 세로 패딩 40
  final double cardWScaled = _cardWidth * scale;
  final double cardHScaled = cardHeight * scale;

  final double birdSizeScaled = _birdSize * scale;

  // 우/하단 여유 (새가 살짝 겹치도록 음수 offset을 쓰고 있으므로 여유 필요)
  final double extraW = birdSizeScaled * 0.50;
  final double extraH = birdSizeScaled * 0.50;

  return SizedBox(
    width: cardWScaled + extraW,
    height: cardHScaled + extraH,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // 카드(스케일 적용)
        Positioned(
          left: 0,
          top: 0,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: Container(
              width: _cardWidth,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(width: _iconLeftInset),
                  Container(
                    width: _iconBoxSize,
                    height: _iconBoxSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEAFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.alarm, color: const Color(0xFF7C69FF), size: _iconSize),
                  ),
                  SizedBox(width: _gapAfterIcon),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(_digitsShiftX, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _digitText((minutes ~/ 10) % 10),
                          _digitText(minutes % 10),
                          const SizedBox(width: 8),
                          const Text(':', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w700, color: Colors.black)),
                          const SizedBox(width: 8),
                          _digitText((seconds ~/ 10) % 10),
                          _digitText(seconds % 10),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: isRunning ? Colors.redAccent : const Color(0xFFDADFE8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 새 이미지(표시만, 클릭 없음) — 카드와 동일 비율로 자연스럽게 이동/확대
        Positioned(
          // 기존 오프셋(_birdRight/_birdBottom)을 그대로 사용하되, 스케일에 따라 이동값도 함께 배수 처리
          right: _birdRight * scale,
          bottom: _birdBottom * scale,
          child: SizedBox(
            width: birdSizeScaled,
            height: birdSizeScaled,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: Image.asset(
                _birdAsset,
                key: ValueKey<String>(_birdAsset),
                width: birdSizeScaled,
                height: birdSizeScaled,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final mT = (minutes ~/ 10) % 10;
    final mO = minutes % 10;
    final sT = (seconds ~/ 10) % 10;
    final sO = seconds % 10;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _responsiveDisplayCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _digitText(int n) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          n.toString(),
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: Colors.black,
          ),
        ),
      );
}
