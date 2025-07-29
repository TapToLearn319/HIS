// import 'dart:async';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';

// import '../models/log_entry.dart';

// class LogsProvider extends ChangeNotifier {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

//   List<LogEntry> _logs = [];
//   List<LogEntry> get logs => _logs;

//   /// 새로운 버튼 시리얼로 구독 전환
//   void subscribeToLogs(String buttonSerial) {
//     // 이전 구독 취소
//     _sub?.cancel();

//     _sub = _firestore
//         .collection('buttons')
//         .doc(buttonSerial)
//         .collection('logs')
//         .orderBy('timestamp', descending: true)
//         .snapshots()
//         .listen((snapshot) {
//           for (var doc in snapshot.docs) {
//     print('🔥 RAW FIRESTORE DATA for ${doc.id}: ${doc.data()}');
//   }
//       _logs = snapshot.docs
//           .map((doc) => LogEntry.fromDoc(doc))
//           .toList();
//       notifyListeners();
//     });
//   }

//   @override
//   void dispose() {
//     _sub?.cancel();
//     super.dispose();
//   }
// }
