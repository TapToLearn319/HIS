// students_provider.dart — hubs/{hubId}/students 기준
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentsProvider extends ChangeNotifier {
  final FirebaseFirestore _fs;
  StreamSubscription? _sub;

  String? _hubId;
  String? get hubId => _hubId;

  // studentId -> { name, ... }
  Map<String, Map<String, dynamic>> _students = {};
  Map<String, Map<String, dynamic>> get students => _students;

  StudentsProvider(this._fs, {String? initialHubId}) {
    if (initialHubId != null) listenHub(initialHubId);
  }

  /// hubs/{hubId}/students 구독 시작(허브 변경 시 재구독)
  void listenHub(String hubId) {
    if (_hubId == hubId) return;
    _hubId = hubId;

    _sub?.cancel();
    _students = {};
    notifyListeners();

    _sub = _fs
        .collection('hubs')
        .doc(hubId)
        .collection('students')
        // 필요하면 .orderBy('name') 추가
        .snapshots()
        .listen((snap) {
      final m = <String, Map<String, dynamic>>{};
      for (final d in snap.docs) {
        m[d.id] = d.data();
      }
      _students = m;
      notifyListeners();
    });
  }

  String displayName(String studentId) {
    return _students[studentId]?['name'] as String? ?? studentId;
  }

  /// 구독 중지
  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
