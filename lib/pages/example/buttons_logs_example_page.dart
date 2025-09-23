import 'package:flutter/material.dart';
import 'package:project/provider/all_logs_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../models/log_entry.dart';

class GroupedByStudentPage extends StatelessWidget {
  const GroupedByStudentPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<AllLogsProvider>().allLogs;

    // studentName 을 키로 그룹핑
    final Map<String, List<LogEntry>> byStudent =
        groupBy(logs, (LogEntry e) => e.studentName);

    if (byStudent.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('학생별 로그')),
        body: const Center(child: Text('로그가 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('학생별 로그')),
      body: ListView(
        children: byStudent.entries.map((entry) {
          final student = entry.key;
          final studentLogs = entry.value;

          return ExpansionTile(
            title: Text('$student (${studentLogs.length}건)'),
            children: studentLogs.map((log) {
              return ListTile(
                leading: Icon(
                  log.clickType == 'single'
                      ? Icons.touch_app
                      : Icons.touch_app_outlined,
                ),
                subtitle: Text(DateFormat('yyyy-MM-dd HH:mm:ss')
                    .format(log.timestamp)),
                // 클릭 타입이나 buttonSerial 표시가 필요하면 title 에 추가
                title: Text('${log.clickType} (버튼: ${log.buttonSerial})'),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
