import 'package:cloud_firestore/cloud_firestore.dart';

class LogEntry {
  final String id;
  final String buttonSerial;  // 어느 버튼에서 왔는지 (필요 없으면 지워도 됩니다)
  final String studentName;
  final String clickType;
  final DateTime timestamp;

  LogEntry({
    required this.id,
    required this.buttonSerial,
    required this.studentName,
    required this.clickType,
    required this.timestamp,
  });
}
