import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/log_entry.dart';

class AllLogsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<LogEntry> _allLogs = [];
  List<LogEntry> get allLogs => _allLogs;

  bool _isClearing = false;
  bool get isClearing => _isClearing;

  AllLogsProvider() {
    _init();
  }

  void _init() {
    Future.microtask(() => clearLogs());
    _sub = _firestore
        .collectionGroup('logs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snap) {
      _allLogs = snap.docs.map((doc) {
        final data = doc.data();
        final serial = doc.reference.parent.parent!.id;
        return LogEntry(
          id: doc.id,
          buttonSerial: serial,
          studentName: data['studentName'] as String? ?? '',
          clickType: data['clickType'] as String? ?? '',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
        );
      }).toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('⚠️ AllLogsProvider error: $e');
    });
  }

  Future<void> clearLogs() async {
  _isClearing = true;
  notifyListeners();

  try {
    final snap = await _firestore.collectionGroup('logs').get();

    // 모든 삭제 Future를 동시에 처리
    final deleteFutures = snap.docs.map((doc) => doc.reference.delete());
    await Future.wait(deleteFutures);

    _allLogs.clear();
  } catch (e) {
    debugPrint('❌ Firestore 로그 삭제 오류: $e');
  } finally {
    _isClearing = false;
    notifyListeners();
  }
}


  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}


