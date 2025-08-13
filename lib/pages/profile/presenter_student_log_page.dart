// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../provider/all_logs_provider.dart';
// import '../../models/log_entry.dart';

// class StudentLogPage extends StatelessWidget {
//   final String studentName;
//   final int? seatIndex;

//   const StudentLogPage({
//     super.key,
//     required this.studentName,
//     this.seatIndex,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final allLogs = context.watch<AllLogsProvider>().allLogs;

//     // ✅ 로그는 "이름 그대로" 필터 (스키마/저장 방식 변경 없음)
//     final List<LogEntry> logs = allLogs
//         .where((e) => e.studentName == studentName)
//         .toList()
//       ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // 최신 우선

//     // 타입별 카운트 (옵션)
//     final Map<String, int> byType = {};
//     for (final l in logs) {
//       byType[l.clickType] = (byType[l.clickType] ?? 0) + 1;
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(studentName),
//             if (seatIndex != null)
//               Text(
//                 'Student ${seatIndex! + 1}',
//                 style: Theme.of(context).textTheme.bodySmall,
//               ),
//           ],
//         ),
//       ),
//       body: logs.isEmpty
//           ? const Center(child: Text('No logs yet'))
//           : Column(
//               children: [
//                 // 상단 요약 (옵션)
//                 Padding(
//                   padding: const EdgeInsets.all(12),
//                   child: Wrap(
//                     spacing: 8,
//                     runSpacing: 8,
//                     children: [
//                       _chip('Total', logs.length.toString()),
//                       ...byType.entries.map((e) => _chip(e.key, '${e.value}')),
//                       _chip('Latest', _fmtTime(logs.first.timestamp)),
//                     ],
//                   ),
//                 ),
//                 const Divider(height: 1),

//                 // 로그 리스트
//                 Expanded(
//                   child: ListView.separated(
//                     itemCount: logs.length,
//                     separatorBuilder: (_, __) => const Divider(height: 1),
//                     itemBuilder: (_, i) {
//                       final l = logs[i];
//                       return ListTile(
//                         dense: true,
//                         title: Text(l.clickType.isEmpty ? 'event' : l.clickType),
//                         subtitle: Text(_fmtTime(l.timestamp)),
//                         trailing: Text(l.buttonSerial), // 어떤 버튼에서 온 로그인지
//                       );
//                     },
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }

//   Widget _chip(String label, String value) {
//     return Chip(
//       label: Text('$label: $value'),
//       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//       padding: const EdgeInsets.symmetric(horizontal: 8),
//     );
//   }

//   String _fmtTime(DateTime t) =>
//       '${t.year}-${_2(t.month)}-${_2(t.day)} ${_2(t.hour)}:${_2(t.minute)}:${_2(t.second)}';

//   String _2(int n) => n.toString().padLeft(2, '0');
// }
