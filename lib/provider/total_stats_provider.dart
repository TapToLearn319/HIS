// lib/provider/total_stats_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TotalStatsProvider extends ChangeNotifier {
  final FirebaseFirestore _fs;
  TotalStatsProvider(this._fs);

  String? _hubId;
  String? _sessionId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  int total = 0;

  String? get hubId => _hubId;
  String? get sessionId => _sessionId;

  String? get _summaryDocPath {
    if (_hubId == null || _sessionId == null) return null;
    return 'hubs/$_hubId/sessions/$_sessionId/stats/summary';
    // (함수에서 stats/summary 도큐먼트를 갱신합니다)
  }

  /// 허브/세션 바인딩 (세션이 null이면 구독만 해제)
  Future<void> bindHubSession({
    required String hubId,
    required String? sessionId,
  }) async {
    final same = (_hubId == hubId) && (_sessionId == sessionId);
    if (same) return;

    // 기존 스트림 해제
    final prev = _sub;
    _sub = null;
    if (prev != null) {
      try {
        await prev.cancel();
      } catch (_) {}
    }

    _hubId = hubId;
    _sessionId = sessionId;

    // 초기화
    total = 0;
    notifyListeners();

    if (sessionId == null) return;

    // 프레임 한 박자 양보 후 새 구독 시작
    await Future<void>.delayed(Duration.zero);

    final docPath = _summaryDocPath!;
    final docRef = _fs.doc(docPath);
    _sub = docRef.snapshots().listen(
      (snap) {
        final data = snap.data() ?? const <String, dynamic>{};
        total = (data['total'] as num?)?.toInt() ?? 0;
        notifyListeners();
      },
      onError: (e, st) {
        debugPrint('TotalStatsProvider snapshots error: $e');
      },
    );
  }

  /// (하위 호환) 예전 API: 세션만 받는 버전.
  /// 새 구조에서는 hubId가 필요하므로, 반드시 [bindHubSession]을 사용하세요.
  @Deprecated('Use bindHubSession(hubId: ..., sessionId: ...) instead.')
  Future<void> bindSession(String? sid) async {
    await bindHubSession(hubId: _hubId ?? 'hub-001', sessionId: sid);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
