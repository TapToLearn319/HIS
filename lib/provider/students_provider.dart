// students_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentsProvider extends ChangeNotifier {
  final FirebaseFirestore _fs;
  StreamSubscription? _sub;

  // studentId -> { name, ... }
  Map<String, Map<String, dynamic>> _students = {};
  Map<String, Map<String, dynamic>> get students => _students;

  StudentsProvider(this._fs);

  // 필요하다면 classId, schoolId 기준으로 범위를 좁혀도 됨
  void listenAll() {
    _sub?.cancel();
    _students = {};
    notifyListeners();

    _sub = _fs.collection('students').snapshots().listen((snap) {
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
