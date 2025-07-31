import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../sidebar_menu.dart';
import '../../models/log_entry.dart';
import '../../provider/all_logs_provider.dart';
import '../../provider/seat_provider.dart';

class PresenterHomePage extends StatefulWidget {
  @override
  State<PresenterHomePage> createState() => _PresenterHomePageState();
}

class _PresenterHomePageState extends State<PresenterHomePage> {
  bool _showLogs = false;

  @override
  Widget build(BuildContext context) {
    final allLogsProvider = context.watch<AllLogsProvider>();
    final logs = allLogsProvider.allLogs;
    final isLoading = allLogsProvider.isClearing;

    final seatProvider = context.watch<SeatProvider>();
    final seatAssignments = seatProvider.seatAssignments;

    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final Map<String, String> studentClickTypeMap = {};
    for (final log in logs) {
      studentClickTypeMap.putIfAbsent(log.studentName, () => log.clickType);
    }

    return AppScaffold(
      body: Stack(
        children: [
          Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단 Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Class : 3B",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            // OutlinedButton(
                            //   onPressed: () {
                            //     _showSeatConfigDialog(context);
                            //   },
                            //   child: Text("좌석 설정"),
                            // ),
                            // SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                await allLogsProvider.clearLogs();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("로그가 초기화되었습니다.")),
                                );
                              },
                              child: Text(AppLocalizations.of(context)!.resetLogs),
                            ),
                            SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text(AppLocalizations.of(context)!.logout),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Mathematics",
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 24),

                    // 좌석 그리드
                    Expanded(
                      child: GridView.builder(
                        itemCount: 24,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.8,
                        ),
                        itemBuilder: (context, index) {
                          String seatName =
                              seatAssignments[index] ?? "이름 설정";
                          String? clickType = studentClickTypeMap[seatName];

                          Color seatColor = const Color(0xFF6063C6);
                          if (clickType == 'click') {
                            seatColor = Colors.lightGreenAccent;
                          } else if (clickType == 'double_click') {
                            seatColor = Colors.redAccent;
                          } else if (clickType == 'hold') {
                            seatColor = Colors.orangeAccent;
                          }

                          return GestureDetector(
                            onTap: () =>
                                _showSeatConfigDialog(context, seatIndex: index),
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
                    SizedBox(height: 12),

                    // 로그 보기 토글 버튼
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showLogs = !_showLogs;
                          });
                        },
                        icon: Icon(_showLogs ? Icons.expand_more : Icons.expand_less),
                        label: Text(_showLogs ? AppLocalizations.of(context)!.hideLogs : AppLocalizations.of(context)!.showLogs),
                      ),
                    ),

                    // 로그 리스트
                    if (_showLogs)
                      SizedBox(
                        height: 160,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: logs.isEmpty
                              ? Center(child: Text(AppLocalizations.of(context)!.noLog))
                              : ListView.builder(
                                  itemCount: logs.length,
                                  itemBuilder: (context, index) {
                                    final LogEntry log = logs[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text("${log.studentName} (${log.clickType})"),
                                      subtitle: Text(
                                        "${log.buttonSerial} • ${log.timestamp}",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

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
      selectedIndex: 0,
    );
  }

  void _showSeatConfigDialog(BuildContext context, {int? seatIndex}) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(seatIndex != null ? "${AppLocalizations.of(context)!.seat} ${seatIndex + 1} ${AppLocalizations.of(context)!.setting}" : "좌석 설정"),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.enterName,
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (seatIndex != null && nameController.text.isNotEmpty) {
                  await context
                      .read<SeatProvider>()
                      .assignSeat(seatIndex, nameController.text);
                }
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        );
      },
    );
  }
}
