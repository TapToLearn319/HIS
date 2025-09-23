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
      slotIndex: normalizeSlot(x['slotIndex']),
      ts: x['ts'] is Timestamp ? x['ts'] as Timestamp : null,
      hubTs: (x['hubTs'] as num?)?.toInt(),
    );
  }
}

class DebugEventsProvider extends ChangeNotifier {
  final FirebaseFirestore _fs;
  DebugEventsProvider(this._fs, {this.limit = 300});

  final int limit;

  String? _hubId;
  String? _sessionId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  final List<EventLog> _events = [];
  List<EventLog> get events => _events;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? get hubId => _hubId;
  String? get sessionId => _sessionId;

  bool get hasMore => false; // 스트림 방식은 페이지네이션 없음

  /// 허브/세션에 바인딩. 기존 스트림 정리 후 새 스트림 구독.
  void bindHubSession({required String hubId, required String? sessionId}) {
    final same = (_hubId == hubId) && (_sessionId == sessionId);
    if (same) return;

    _hubId = hubId;
    _sessionId = sessionId;

    _sub?.cancel();
    _sub = null;

    _events.clear();
    notifyListeners();

    if (_sessionId == null) return;

    _isLoading = true;
    notifyListeners();

    final q = _fs
        .collection('hubs/$hubId/sessions/$sessionId/events')
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

  /// (하위 호환) 예전 API: 세션만 받는 버전.
  /// 새 구조에서는 hubId가 필요하므로, 반드시 [bindHubSession]을 사용하세요.
  @Deprecated('Use bindHubSession(hubId: ..., sessionId: ...) instead.')
  void bindSession(String? sessionId) {
    bindHubSession(hubId: _hubId ?? 'hub-001', sessionId: sessionId);
  }

  /// 스트림 방식에서는 의미 없음. (호출돼도 아무 일 안 함)
  Future<void> loadMore() async {}

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
