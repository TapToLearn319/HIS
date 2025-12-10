import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../main.dart';
import 'package:audioplayers/audioplayers.dart';
// import 'package:project/main.dart' as app show channel;

class TimerPage extends StatefulWidget {
  @override
  _TimerPageState createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  // === 튜닝용 상수 ===
  static const double _cardWidth   = 680;   // 카드 폭
  static const double _birdSize    = 200;   // 새 크기
  static const double _birdRight   = -60;
  static const double _birdBottom  = -60;

  // 아이콘/간격/숫자 이동량
  static const double _iconLeftInset = 36;
  static const double _iconBoxSize   = 124;
  static const double _iconSize      = 68;
  static const double _gapAfterIcon  = 22;
  static const double _digitsShiftX  = -48;

  int minutes = 0;
  int seconds = 0;
  bool isRunning = false;
  int _initialTotalSeconds = 0;
  Timer? _timer;

  late final AudioPlayer _player;
  bool _warningPlayed = false;

  String get _birdAsset => isRunning ? "assets/logo_bird_stop.png" : "assets/logo_bird_start.png";

  @override
  void initState() {
    super.initState();
    channel.postMessage(jsonEncode({'type': 'tool_mode', 'mode': 'timer'}));

    _player = AudioPlayer();
  }

  void _broadcastTimerState() {
    channel.postMessage(jsonEncode({
      'type': 'timer',
      'minutes': minutes,
      'seconds': seconds,
      'isRunning': isRunning,
      'totalSeconds': _initialTotalSeconds,
    }));
  }

  void _startTimer() {
    if ((minutes == 0 && seconds == 0) || isRunning) return;

    final total = minutes * 60 + seconds;
    
    setState(() {
      isRunning = true;
      if (total > 10) {
        _warningPlayed = false;
      }

      _initialTotalSeconds = total;
    });
    
    _broadcastTimerState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final total = minutes * 60 + seconds;

      if (isRunning && total <= 10 && total > 0 && !_warningPlayed) {
        _warningPlayed = true;
        _player.play(AssetSource("sound/timer_warning.mp3"));
      }

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
      _warningPlayed = false;
    });
    _broadcastTimerState();
  }

  void _finishTimer() {
    _timer?.cancel();
    setState(() {
      isRunning = false;
      _warningPlayed = false;
    });

    _player.play(AssetSource("sound/timer_finish.mp3"));
    _broadcastTimerState();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Time is up!')),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
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

  void _adjustDigit({required String unit, required int place, required int delta}) {
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
      _warningPlayed = false;
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
          onPressed: disabled ? null : () => _adjustDigit(unit: unit, place: place, delta: 1),
          icon: const Icon(Icons.expand_less),
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
            ),
          ),
        ),
        IconButton(
          iconSize: 20,
          onPressed: disabled ? null : () => _adjustDigit(unit: unit, place: place, delta: -1),
          icon: const Icon(Icons.expand_more),
          splashRadius: 18,
        ),
      ],
    );
  }

  Widget _presetChip(String label, int sec) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        foregroundColor: Colors.black,
      ),
      onPressed: () => _setByPreset(sec),
      child: Text(label),
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

      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F8FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.black,
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: '뒤로가기',
        ),
      ),

      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ====== TIMER CARD ======
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: _cardWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: _iconLeftInset),
                        // 보라 아이콘
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
                        // 숫자 영역
                        Expanded(
                          child: Transform.translate(
                            offset: Offset(_digitsShiftX, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _digitColumn(unit: 'm', place: 10, text: mT.toString()),
                                _digitColumn(unit: 'm', place: 1, text: mO.toString()),
                                const SizedBox(width: 8),
                                const Text(':', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w700, color: Colors.black)),
                                const SizedBox(width: 8),
                                _digitColumn(unit: 's', place: 10, text: sT.toString()),
                                _digitColumn(unit: 's', place: 1, text: sO.toString()),
                              ],
                            ),
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
                                color: isRunning ? Colors.redAccent : const Color(0xFFDADFE8),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ====== START/PAUSE 새 버튼 (이미지 토글) ======
                  Positioned(
                    right: _birdRight,
                    bottom: _birdBottom,
                    child: _MakeButton(
                      scale: _birdSize / 195.0, // 기본 크기 기준으로 스케일 조정
                      imageAsset: _birdAsset,
                      onTap: () {
                        if (isRunning) {
                          _pauseTimer();
                        } else {
                          _startTimer();
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 프리셋
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  _presetChip('30s', 30),
                  _presetChip('1m', 60),
                  _presetChip('5m', 300),
                  _presetChip('10m', 600),
                  _presetChip('30m', 1800),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: isRunning ? null : () {
                      _setByPreset(minutes * 60 + seconds + 60);
                    },
                    child: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
                onPressed: _resetTimer,
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────
// 공통 Bird Button (Hover/Click Scale 애니메이션)
// ─────────────────────────────────────────────
class _MakeButton extends StatefulWidget {
  const _MakeButton({
    required this.scale,
    required this.imageAsset,
    required this.onTap,
    this.enabled = true,
  });

  final double scale;
  final String imageAsset;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_MakeButton> createState() => _MakeButtonState();
}

class _MakeButtonState extends State<_MakeButton> {
  bool _hover = false;
  bool _down = false;

  static const _baseW = 195.0;
  static const _baseH = 172.0;

  @override
  Widget build(BuildContext context) {
    final w = _baseW * widget.scale;
    final h = _baseH * widget.scale;
    final scaleAnim = _down
        ? 0.96
        : (_hover ? 1.05 : 1.0);

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.enabled) setState(() => _hover = true);
      },
      onExit: (_) {
        if (widget.enabled) setState(() => _hover = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enabled) setState(() => _down = true);
        },
        onTapUp: (_) {
          if (widget.enabled) setState(() => _down = false);
        },
        onTapCancel: () {
          if (widget.enabled) setState(() => _down = false);
        },
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: scaleAnim,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Opacity(
            opacity: widget.enabled ? 1.0 : 0.5,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Image.asset(
                widget.imageAsset,
                key: ValueKey<String>(widget.imageAsset),
                width: w,
                height: h,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

