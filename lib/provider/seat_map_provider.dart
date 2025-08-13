// lib/provider/seat_map_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SeatMapProvider extends ChangeNotifier {
  final FirebaseFirestore _fs;
  SeatMapProvider(this._fs);

  String? _sessionId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Map<String, String?> seatMap = {};

  /// 세션 바인딩 (기존 그대로)
  Future<void> bindSession(String? sid) async {
    if (_sessionId == sid) return;

    // 1) 기존 구독 안전 해제
    final prev = _sub;
    _sub = null;
    if (prev != null) {
      try { await prev.cancel(); } catch (_) {}
    }

    // 2) 상태 초기화
    _sessionId = sid;
    seatMap = {};
    notifyListeners();

    if (sid == null) return;

    // 3) 프레임 한 박자 양보 후 새 구독 시작
    await Future<void>.delayed(Duration.zero);

    final col = _fs.collection('sessions/$sid/seatMap');
    _sub = col.snapshots().listen((snap) {
      final next = <String, String?>{};
      for (final d in snap.docs) {
        final data = d.data();
        next[d.id] = data['studentId'] as String?;
      }
      seatMap = next;
      notifyListeners();
    }, onError: (e, st) {
      debugPrint('SeatMapProvider snapshots error: $e');
    });
  }

  /// 좌석 배정/해제
  /// [seatNo]는 "1".."24" 형태의 문자열, [studentId]는 null이면 '빈 좌석'
  Future<void> assignSeat(String seatNo, String? studentId) async {
    final sid = _sessionId;
    if (sid == null) {
      throw StateError('No session bound. Call bindSession() first.');
    }

    try {
      final doc = _fs.doc('sessions/$sid/seatMap/$seatNo');
      // null을 쓰면 Firestore에 studentId:null로 저장됩니다.
      // (필드를 완전히 지우고 싶다면 FieldValue.delete()를 사용하세요)
      await doc.set(
        {'studentId': studentId},
        SetOptions(merge: true),
      );

      // 낙관적 업데이트(실시간 스냅샷이 곧 다시 갱신하지만 UI 반응성을 위해)
      seatMap[seatNo] = studentId;
      notifyListeners();
    } catch (e, st) {
      debugPrint('assignSeat error: $e\n$st');
      rethrow;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
