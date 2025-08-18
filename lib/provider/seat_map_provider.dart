// lib/provider/seat_map_provider.dart (일부 발췌)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SeatMapProvider with ChangeNotifier {
  final FirebaseFirestore _fs;
  String? _sessionId;
  final Map<String, String?> _seatMap = {}; // "1".."24" -> studentId or null

  SeatMapProvider(this._fs);

  Map<String, String?> get seatMap => _seatMap;
  String? get sessionId => _sessionId;

  Future<void> bindSession(String sid) async {
    _sessionId = sid;
    // ... 기존 바인딩/리스너 코드 ...
  }

  /// 기존 단일 업데이트가 있다면 유지
  Future<void> assignSeat(String seatKey, String? studentId) async {
    final sid = _sessionId;
    if (sid == null) return;
    await _fs.doc('sessions/$sid/seatMap/$seatKey')
        .set({'studentId': studentId}, SetOptions(merge: true));
    _seatMap[seatKey] = studentId;
    notifyListeners();
  }

  /// ✅ 새로 추가: 여러 좌석을 한꺼번에 갱신하고 마지막에 한 번만 notify
  Future<void> assignSeatsBulk(Map<String, String?> updates) async {
    final sid = _sessionId;
    if (sid == null || updates.isEmpty) return;

    final batch = _fs.batch();
    updates.forEach((seatKey, studentId) {
      final ref = _fs.doc('sessions/$sid/seatMap/$seatKey');
      batch.set(ref, {'studentId': studentId}, SetOptions(merge: true));
      _seatMap[seatKey] = studentId; // 로컬 상태도 미리 반영
    });

    await batch.commit();
    notifyListeners(); // ✔️ 한 번만 알림 → UI가 동시에 갱신
  }
}
