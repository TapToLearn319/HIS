import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/log_entry.dart';
import '../../../provider/all_logs_provider.dart';
import 'package:provider/provider.dart';

class FcfsGamePage extends StatefulWidget {
  @override
  _FcfsGamePageState createState() => _FcfsGamePageState();
}

class _FcfsGamePageState extends State<FcfsGamePage> {
  List<Color> lightColors = List.filled(4, Colors.grey);
  DateTime? greenLightTime; // 실제 로그 집계 기준
  List<LogEntry> firstThree = [];
  Set<String> processedStudents = {}; // ✅ 학생 이름 중복 방지
  Timer? pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AllLogsProvider>().clearLogs();
    });
  }

  @override
  void dispose() {
    pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> startGame() async {
    context.read<AllLogsProvider>().clearLogs();
    setState(() {
      lightColors = List.filled(4, Colors.grey);
      greenLightTime = null;
      firstThree = [];
      processedStudents.clear();
    });

    // 🔴 Firestore에 startTime 저장
    final startTime = DateTime.now();
    await FirebaseFirestore.instance.collection('games').doc('fcfs').set({
      'startTime': Timestamp.fromDate(startTime),
    });

    // 기준 시간 분리
    final greenLightVisibleTime = startTime.add(Duration(seconds: 5)); // UI용
    greenLightTime = startTime.add(Duration(seconds: 8)); // 집계용

    // 🔴 빨간불 점등
    for (int i = 0; i < 4; i++) {
      await Future.delayed(Duration(seconds: 1));
      setState(() {
        lightColors[i] = Colors.red;
      });
    }

    // 🟢 초록불 UI 표시
    final delay = greenLightVisibleTime.difference(DateTime.now());
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    setState(() {
      lightColors = List.generate(4, (_) => Colors.green);
    });

    // ⏱ 초록불 보인 후, 실제 집계 시작은 3초 뒤
    final waitForGreenThreshold = greenLightTime!.difference(DateTime.now());
    if (waitForGreenThreshold > Duration.zero) {
      await Future.delayed(waitForGreenThreshold);
    }
    pollLogs();
  }

  void pollLogs() {
    pollingTimer?.cancel();
    pollingTimer = Timer.periodic(Duration(milliseconds: 300), (_) {
      final logs = context.read<AllLogsProvider>().allLogs;
      if (greenLightTime == null || firstThree.length >= 3) return;

      final newLogs = logs.where((log) {
        return log.timestamp.isAfter(greenLightTime!) &&
            !processedStudents.contains(log.studentName);
      }).toList();

      newLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (final log in newLogs) {
        if (firstThree.length < 3) {
          processedStudents.add(log.studentName); // ✅ 이름으로 중복 방지
          firstThree.add(log);
        }
      }

      setState(() {});
      if (firstThree.length >= 3) {
        pollingTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('FCFS Game')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 불빛 표시
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                return Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: lightColors[i],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                );
              }),
            ),

            // 시작 버튼
            ElevatedButton(
              onPressed: startGame,
              child: Text('게임 시작하기'),
            ),

            // 순위 표시
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(firstThree.length, (index) {
                final log = firstThree[index];
                final diff = log.timestamp.difference(greenLightTime!).inMilliseconds;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${index + 1}등: ${log.studentName}',
                    style: TextStyle(fontSize: 18),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
