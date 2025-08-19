// lib/provider/debug_events_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventLog {
  final String id;
  final String deviceId;
  final String clickType;
  final String? studentId;
  final String? slotIndex; // "1" | "2"
  final Timestamp? ts;
  final int? hubTs;

  EventLog({
    required this.id,
    required this.deviceId,
    required this.clickType,
    this.studentId,
    this.slotIndex,
    this.ts,
    this.hubTs,
  });

  factory EventLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
  final x = d.data() ?? const <String, dynamic>{};

  String? normalizeSlot(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s == '1' || s == '2') return s;
    return null; // 그 외 값은 무시
  }

  return EventLog(
    id: d.id,
    deviceId: (x['deviceId'] ?? '').toString(),
    clickType: (x['clickType'] ?? '').toString().toLowerCase(),
    studentId: (x['studentId'] as String?) ?? (x['studentId']?.toString()),
    slotIndex: normalizeSlot(x['slotIndex']),        // ✅ 핵심 수정
    ts: x['ts'] is Timestamp ? x['ts'] as Timestamp : null,
    hubTs: (x['hubTs'] as num?)?.toInt(),
  );
}
}

class DebugEventsProvider extends ChangeNotifier {
  final FirebaseFirestore _fs;
  DebugEventsProvider(this._fs, {this.limit = 300});

  String? _sessionId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  final int limit;

  final List<EventLog> _events = [];
  List<EventLog> get events => _events;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get hasMore => false; // 스트림 방식은 페이지네이션 없음

  /// 세션에 바인딩. 기존 스트림 정리 후 새 스트림 구독.
  void bindSession(String? sessionId) {
    if (_sessionId == sessionId) return;
    _sessionId = sessionId;

    // 기존 스트림 해제
    _sub?.cancel();
    _sub = null;

    // 목록 초기화
    _events.clear();
    notifyListeners();

    if (_sessionId == null) return;

    _isLoading = true;
    notifyListeners();

    // ⚠️ 정렬 필드는 ts(서버 타임스탬프)로 통일
    //   - hubTs는 숫자형이어도 타입 섞이면 정렬 에러 발생 가능성↑
    final q = _fs
        .collection('sessions/$_sessionId/events')
        .orderBy('ts', descending: true)
        .limit(limit);

    _sub = q.snapshots().listen((snap) {
      try {
        _events
          ..clear()
          ..addAll(snap.docs.map((d) => EventLog.fromDoc(d)));
        _isLoading = false;
        notifyListeners();
      } catch (e, st) {
        debugPrint('[DEBUG_EVENTS] parse error: $e\n$st');
        _isLoading = false;
        notifyListeners();
      }
    }, onError: (e, st) {
      debugPrint('[DEBUG_EVENTS] snapshots error: $e\n$st');
      _isLoading = false;
      notifyListeners();
    });
  }

  /// 스트림 방식에서는 의미 없음. (호출돼도 아무 일 안 함)
  Future<void> loadMore() async {}

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
