import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../main.dart'; // channel, slideIndex
import '../../models/log_entry.dart';
import '../../provider/all_logs_provider.dart';
import '../../provider/seat_provider.dart';

class DisplayHomePage extends StatefulWidget {
  @override
  _DisplayHomePageState createState() => _DisplayHomePageState();
}

class _DisplayHomePageState extends State<DisplayHomePage> {
  @override
  void initState() {
    super.initState();
    channel.onMessage.listen((msg) {
      final data = jsonDecode(msg.data as String);
      if (data['type'] == 'route') {
        final route = data['route'] as String?;
        if (route != null &&
            route != ModalRoute.of(context)!.settings.name) {
          Navigator.pushReplacementNamed(context, route);
        }
        slideIndex.value = data['slide'] as int;
      } else if (data['type'] == 'slide') {
        slideIndex.value = data['slide'] as int;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allLogsProvider = context.watch<AllLogsProvider>();
    final logs = allLogsProvider.allLogs;
    final isLoading = allLogsProvider.isClearing;
    final seatAssignments = context.watch<SeatProvider>().seatAssignments;

    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final Map<String, String> studentClickTypeMap = {};
    for (final log in logs) {
      studentClickTypeMap.putIfAbsent(log.studentName, () => log.clickType);
    }

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                itemCount: 24,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.8,
                ),
                itemBuilder: (context, index) {
                  String seatName = seatAssignments[index] ?? "이름 설정";
                  String? clickType = studentClickTypeMap[seatName];

                  Color seatColor = const Color(0xFF6063C6);
                  if (clickType == 'click') {
                    seatColor = Colors.lightGreenAccent;
                  } else if (clickType == 'double') {
                    seatColor = Colors.redAccent;
                  } else if (clickType == 'hold') {
                    seatColor = Colors.orangeAccent;
                  }

                  int col = index % 6;
                  double extraRightPadding = (col == 1 || col == 3) ? 12 : 0;

                  return Padding(
                    padding: EdgeInsets.only(right: extraRightPadding),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: seatColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        seatName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ✅ 로딩 오버레이
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
