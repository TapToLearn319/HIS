import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../main.dart'; // 채널 참조용

class BombGamePage extends StatefulWidget {
  const BombGamePage({Key? key}) : super(key: key);

  @override
  State<BombGamePage> createState() => _BombGamePageState();
}

class _BombGamePageState extends State<BombGamePage> {
  int targetCount = 10; // 초기 목표 카운트
  int pressCount = 0;
  bool exploded = false;

  void _handlePress() {
    if (exploded) return;

    setState(() {
      pressCount++;
      if (pressCount >= targetCount) {
        exploded = true;

        // 폭발 알림 전송
        channel.postMessage(jsonEncode({'type': 'bomb_explode'}));
      } else {
        // 진행상황 알림 전송
        channel.postMessage(
          jsonEncode({
            'type': 'bomb_progress',
            'pressCount': pressCount,
            'targetCount': targetCount,
          }),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // 게임 시작 시 mode 설정 및 초기값 전송
    channel.postMessage(jsonEncode({'type': 'game_mode', 'mode': 'bomb'}));

    channel.postMessage(
      jsonEncode({
        'type': 'bomb_progress',
        'pressCount': pressCount,
        'targetCount': targetCount,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bomb Game')),
      body: Center(
        child:
            exploded
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, size: 100, color: Colors.red),
                    const SizedBox(height: 20),
                    const Text(
                      '💥 Bomb Exploded!',
                      style: TextStyle(fontSize: 32, color: Colors.red),
                    ),
                  ],
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Set Explosion Threshold:',
                      style: TextStyle(fontSize: 20),
                    ),
                    Slider(
                      value: targetCount.toDouble(),
                      min: 3,
                      max: 20,
                      divisions: 17,
                      label: '$targetCount',
                      onChanged: (val) {
                        setState(() {
                          targetCount = val.toInt();
                          // 변경 시 실시간으로 display에 전달
                          channel.postMessage(
                            jsonEncode({
                              'type': 'bomb_progress',
                              'pressCount': pressCount,
                              'targetCount': targetCount,
                            }),
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Current Count: $pressCount / $targetCount',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _handlePress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 20,
                        ),
                      ),
                      child: const Text(
                        '폭탄 넘기기',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
