// lib/provider/seat_map_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 허브 스코프(hubs/{hubId}) 안의 세션 좌석맵을 구독/갱신하는 Provider
class SeatMapProvider extends ChangeNotifier {
  final FirebaseFirestore _fs;
  SeatMapProvider(this._fs);

  String? _hubId;
  String? _sessionId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  /// seatNo -> studentId? (null이면 빈 좌석)
  Map<String, String?> seatMap = {};

  String? get hubId => _hubId;
  String? get sessionId => _sessionId;

  String? get _seatMapColPath {
    if (_hubId == null || _sessionId == null) return null;
    return 'hubs/$_hubId/sessions/$_sessionId/seatMap';
  }

  /// 허브/세션 바인딩 (세션이 null이면 구독 해제 + 초기화만 수행)
  Future<void> bindHubSession({
    required String hubId,
    required String? sessionId,
  }) async {
    // 동일 바인딩이면 스킵
    if (_hubId == hubId && _sessionId == sessionId) return;

    // 1) 기존 구독 안전 해제
    final prev = _sub;
    _sub = null;
    if (prev != null) {
      try {
        await prev.cancel();
      } catch (_) {}
    }

    // 2) 상태 갱신 & 초기화
    _hubId = hubId;
    _sessionId = sessionId;
    seatMap = {};
    notifyListeners();

    // 세션이 없으면 여기서 종료
    if (sessionId == null) return;

    // 3) 한 프레임 양보 후 새 구독 시작
    await Future<void>.delayed(Duration.zero);

    final path = _seatMapColPath!;
    final col = _fs.collection(path);
    _sub = col.snapshots().listen(
      (snap) {
        final next = <String, String?>{};
        for (final d in snap.docs) {
          final data = d.data();
          next[d.id] = data['studentId'] as String?;
        }
        seatMap = next;
        notifyListeners();
      },
      onError: (e, st) {
        debugPrint('SeatMapProvider snapshots error: $e');
      },
    );
  }

  /// (하위 호환) 예전 API: 세션만 받는 버전.
  /// 새 구조에서는 hubId가 필요하므로, 반드시 위의 [bindHubSession]을 사용하세요.
  @Deprecated('Use bindHubSession(hubId: ..., sessionId: ...) instead.')
  Future<void> bindSession(String? sid) async {
    // 안전하게 no-op 처리 (허브 모름)
    await bindHubSession(hubId: _hubId ?? 'hub-001', sessionId: sid);
  }

  /// 좌석 배정/해제
  /// [seatNo]는 "1".."24" 형태의 문자열, [studentId]는 null이면 '빈 좌석'
  Future<void> assignSeat(String seatNo, String? studentId) async {
    final path = _seatMapColPath;
    if (path == null) {
      throw StateError('No hub/session bound. Call bindHubSession() first.');
    }

    try {
      final doc = _fs.doc('$path/$seatNo');
      await doc.set({'studentId': studentId}, SetOptions(merge: true));

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
