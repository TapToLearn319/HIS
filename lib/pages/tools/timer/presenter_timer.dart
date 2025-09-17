import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../main.dart';

import '../../../sidebar_menu.dart';

class TimerPage extends StatefulWidget {
  @override
  _TimerPageState createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  // === 튜닝용 상수 ===
  static const double _baseWidth = 680; // 카드 폭
  static const double _birdSize = 200; // 새 크기

  static const double _buttonDrop = 40;
  // static const double _birdRight = -60;
  // static const double _birdBottom = -50;

  // 아이콘/간격/숫자 이동량
  static const double _iconLeftInset = 36;
  static const double _iconBoxSize = 124;
  static const double _iconSize = 68;
  static const double _gapAfterIcon = 22;
  static const double _digitsShiftX = -48;

  int minutes = 0;
  int seconds = 0;
  bool isRunning = false;
  int _initialTotalSeconds = 0;
  Timer? _timer;

  String get _birdAsset =>
      isRunning ? "logo_bird_stop.png" : "logo_bird_start.png";

  @override
  void initState() {
    super.initState();
    channel.postMessage(jsonEncode({'type': 'tool_mode', 'mode': 'timer'}));
  }

  void _broadcastTimerState() {
    channel.postMessage(
      jsonEncode({
        'type': 'timer',
        'minutes': minutes,
        'seconds': seconds,
        'isRunning': isRunning,
        'totalSeconds': _initialTotalSeconds,
      }),
    );
  }

  void _startTimer() {
    if ((minutes == 0 && seconds == 0) || isRunning) return;
    setState(() {
      isRunning = true;
      _initialTotalSeconds = minutes * 60 + seconds;
    });
    _broadcastTimerState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (minutes == 0 && seconds == 0) {
        _finishTimer();
      } else {
        setState(() {
          if (seconds > 0) {
            seconds--;
          } else {
            if (minutes > 0) {
              minutes--;
              seconds = 59;
            }
          }
        });
        _broadcastTimerState();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => isRunning = false);
    _broadcastTimerState();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      isRunning = false;
      minutes = 0;
      seconds = 0;
      _initialTotalSeconds = 0;
    });
    _broadcastTimerState();
  }

  void _finishTimer() {
    _timer?.cancel();
    setState(() => isRunning = false);
    _broadcastTimerState();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Time is up!')));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setByPreset(int totalSec) {
    if (isRunning) return;
    setState(() {
      minutes = totalSec ~/ 60;
      seconds = totalSec % 60;
      _initialTotalSeconds = totalSec;
    });
    _broadcastTimerState();
  }

  void _adjustDigit({
    required String unit,
    required int place,
    required int delta,
  }) {
    if (isRunning) return;

    int m = minutes.clamp(0, 99);
    int s = seconds.clamp(0, 59);
    int mT = (m ~/ 10) % 10, mO = m % 10;
    int sT = (s ~/ 10) % 10, sO = s % 10;

    setState(() {
      if (unit == 'm') {
        if (place == 10) {
          mT = (mT + delta) % 10;
          if (mT < 0) mT += 10;
        } else {
          mO = (mO + delta) % 10;
          if (mO < 0) mO += 10;
        }
        m = (mT * 10 + mO).clamp(0, 99);
        minutes = m;
      } else {
        if (place == 10) {
          sT = (sT + delta) % 6;
          if (sT < 0) sT += 6;
        } else {
          sO = (sO + delta) % 10;
          if (sO < 0) sO += 10;
        }
        s = (sT * 10 + sO).clamp(0, 59);
        seconds = s;
      }
      _initialTotalSeconds = minutes * 60 + seconds;
    });
    _broadcastTimerState();
  }

  Widget _digitColumn({
    required String unit,
    required int place,
    required String text,
  }) {
    final disabled = isRunning;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 20,
          onPressed:
              disabled
                  ? null
                  : () => _adjustDigit(unit: unit, place: place, delta: 1),
          icon: const Icon(Icons.expand_less, color: Color(0xFF1D1B20)),
          splashRadius: 18,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Colors.black,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        IconButton(
          iconSize: 20,
          onPressed:
              disabled
                  ? null
                  : () => _adjustDigit(unit: unit, place: place, delta: -1),
          icon: const Icon(Icons.expand_more, color: Color(0xFF1D1B20)),
          splashRadius: 18,
        ),
      ],
    );
  }

  double _uiScale(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final targetWidth = size.width / 3; // 화면 가로의 1/3
    return (targetWidth / _baseWidth)
        .clamp(0.5, 2.0) // 과도한 확대/축소 방지
        .toDouble();
  }

  Widget _presetChip(String label, int sec, double scale) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 8 * scale,
        ),
        foregroundColor: Colors.black,
        textStyle: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600),
      ),
      onPressed: () => _setByPreset(sec),
      child: Text(label),
    );
  }

  Widget _timerCardInner() {
    return SizedBox(
      width: _baseWidth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: _iconLeftInset),
            Container(
              width: _iconBoxSize,
              height: _iconBoxSize,
              decoration: BoxDecoration(
                color: const Color(0xFFEDEAFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.alarm,
                color: const Color(0xFF7C69FF),
                size: _iconSize,
              ),
            ),
            SizedBox(width: _gapAfterIcon),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _digitColumn(
                    unit: 'm',
                    place: 10,
                    text: ((minutes ~/ 10) % 10).toString(),
                  ),
                  _digitColumn(
                    unit: 'm',
                    place: 1,
                    text: (minutes % 10).toString(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    ':',
                    style: TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _digitColumn(
                    unit: 's',
                    place: 10,
                    text: ((seconds ~/ 10) % 10).toString(),
                  ),
                  _digitColumn(
                    unit: 's',
                    place: 1,
                    text: (seconds % 10).toString(),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 28,
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        isRunning ? Colors.redAccent : const Color(0xFFDADFE8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timerWithButton(double scale) {
    // 크기 계산
    const double cardH = 124 + 40.0; // 아이콘 124 + 패딩 40
    final double cardWScaled = _baseWidth * scale;
    final double cardHScaled = cardH * scale;

    final double btnSize = _birdSize * scale;

    // 카드 우하단 밖으로 살짝 겹치게 보일 여유(버튼의 60% 정도)
    final double extraW = btnSize * 0.60;
    final double extraH = btnSize * 0.60;

    // 버튼이 카드 모서리에 약간 겹치도록(겹침 비율 조절용)
    const double overlapRatio = 0.15; // 0.0=모서리 딱, 0.3=더 겹치게
    final double dx = btnSize * overlapRatio;
    final double dy = btnSize * overlapRatio;

    return SizedBox(
      // ★ Stack 자체를 버튼까지 포함하도록 크게 잡음 (히트영역 문제 해결)
      width: cardWScaled + extraW,
      height: cardHScaled + extraH,
      child: Stack(
        clipBehavior: Clip.none, // 그려주기만, 히트는 부모 크기 내에서 처리
        children: [
          // 카드: (0,0) 기준으로 스케일 적용해서 그림
          Positioned(
            left: 0,
            top: 0,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: _timerCardInner(),
            ),
          ),

          // 버튼: 카드의 우하단 기준 양수 좌표로 배치 (화면/히트영역 일치)
          Positioned(
            left: cardWScaled - dx,
            top: cardHScaled - dy,
            child: _startButton(scale), // 내부에서 히트영역 넉넉히 잡음
          ),
        ],
      ),
    );
  }

  Widget _responsiveTimerCard() {
    final size = MediaQuery.of(context).size;
    final targetWidth = size.width / 3;
    final scale = (targetWidth / _baseWidth).clamp(0.5, 2.0).toDouble();

    return Transform.scale(
      scale: scale,
      alignment: Alignment.center,
      child: SizedBox(
        width: _baseWidth,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: _iconLeftInset),
              Container(
                width: _iconBoxSize,
                height: _iconBoxSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEAFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.alarm,
                  color: const Color(0xFF7C69FF),
                  size: _iconSize,
                ),
              ),
              SizedBox(width: _gapAfterIcon),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _digitColumn(
                      unit: 'm',
                      place: 10,
                      text: ((minutes ~/ 10) % 10).toString(),
                    ),
                    _digitColumn(
                      unit: 'm',
                      place: 1,
                      text: (minutes % 10).toString(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      ':',
                      style: TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _digitColumn(
                      unit: 's',
                      place: 10,
                      text: ((seconds ~/ 10) % 10).toString(),
                    ),
                    _digitColumn(
                      unit: 's',
                      place: 1,
                      text: (seconds % 10).toString(),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 28,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          isRunning
                              ? Colors.redAccent
                              : const Color(0xFFDADFE8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _startButton(double scale) {
    final size = _birdSize * scale;
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 투명영역도 클릭
      onTap: () => isRunning ? _pauseTimer() : _startTimer(),
      child: SizedBox(
        width: size + 48, // 히트영역 넉넉하게
        height: size + 48,
        child: Center(
          child: SizedBox(
            width: size,
            height: size,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
              child: Image.asset(
                _birdAsset,
                key: ValueKey(_birdAsset),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);

    return AppScaffold(
      // 사이드바에서 선택된 탭 인덱스 (홈/Tools가 0이었음)
      selectedIndex: 0,
      // 필요하면 header 전달 가능: header: YourHeader(),
      body: Container(
        color: const Color(0xFFF4F8FF),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _timerWithButton(scale), // 타이머 + 버튼 (기존 그대로)
                SizedBox(height: 48 * scale),

                const SizedBox(height: 60),

                // ===== 프리셋 (기존 그대로, 반응형 유지) =====
                Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _baseWidth,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10 * scale,
                      runSpacing: 8 * scale,
                      children: [
                        _presetChip('30s', 30, scale),
                        _presetChip('1m', 60, scale),
                        _presetChip('5m', 300, scale),
                        _presetChip('10m', 600, scale),
                        _presetChip('30m', 1800, scale),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12 * scale,
                              vertical: 6 * scale,
                            ),
                          ),
                          onPressed:
                              isRunning
                                  ? null
                                  : () {
                                    _setByPreset(minutes * 60 + seconds + 60);
                                  },
                          child: Icon(Icons.add, size: 18 * scale),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _resetTimer,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
