import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SlotInfo {
  final int count;
  final Timestamp? lastTs;
  const SlotInfo({required this.count, this.lastTs});
}

class StudentSlotStats {
  final String studentId;
  final int total;
  final Map<String, SlotInfo> bySlot; // "1" | "2"
  final String? lastAction;

  const StudentSlotStats({
    required this.studentId,
    required this.total,
    required this.bySlot,
    this.lastAction,
  });

  factory StudentSlotStats.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data() ?? const <String, dynamic>{};

    // total
    final total = (x['total'] as num?)?.toInt() ?? 0;

    // lastAction
    final String? lastAction = x['lastAction'] as String?;

    // bySlot: 방어적 파싱 (키를 모두 문자열화, 내부 값도 맵인지 확인)
    final Map<String, SlotInfo> bySlot = <String, SlotInfo>{};
    final dynamic rawBySlot = x['bySlot'];

    if (rawBySlot is Map) {
      rawBySlot.forEach((k, v) {
        final key = k.toString(); // "1", "2" 로 맞춤
        if (v is Map) {
          final cnt = (v['count'] as num?)?.toInt() ?? 0;
          final ts = v['lastTs'];
          final tsParsed = ts is Timestamp ? ts : null;
          bySlot[key] = SlotInfo(count: cnt, lastTs: tsParsed);
        }
      });
    } else if (rawBySlot is List) {
      // 혹시 예전에 배열로 저장된 적이 있다면 인덱스 1,2만 사용
      // [null, {count:..., lastTs:...}, {count:..., lastTs:...}]
      if (rawBySlot.length > 1 && rawBySlot[1] is Map) {
        final v = rawBySlot[1] as Map;
        final cnt = (v['count'] as num?)?.toInt() ?? 0;
        final ts = v['lastTs'];
        bySlot['1'] = SlotInfo(count: cnt, lastTs: ts is Timestamp ? ts : null);
      }
      if (rawBySlot.length > 2 && rawBySlot[2] is Map) {
        final v = rawBySlot[2] as Map;
        final cnt = (v['count'] as num?)?.toInt() ?? 0;
        final ts = v['lastTs'];
        bySlot['2'] = SlotInfo(count: cnt, lastTs: ts is Timestamp ? ts : null);
      }
    }

    return StudentSlotStats(
      studentId: d.id,
      total: total,
      bySlot: bySlot,
      lastAction: lastAction,
    );
  }
}

class StudentStatsProvider extends ChangeNotifier {
  final FirebaseFirestore _fs;
  StudentStatsProvider(this._fs);

  String? _sessionId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  // studentId -> stats
  final Map<String, StudentSlotStats> _stats = {};
  Map<String, StudentSlotStats> get stats => _stats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void bindSession(String? sessionId) {
    if (_sessionId == sessionId) return;
    _sessionId = sessionId;

    _sub?.cancel();
    _sub = null;

    _stats.clear();
    notifyListeners();

    if (_sessionId == null) return;

    _isLoading = true;
    notifyListeners();

    // 정렬기준은 total 내림차순(없으면 ts필요 없음)
    final q = _fs
        .collection('sessions/$_sessionId/studentStats')
        .orderBy('total', descending: true)
        .limit(500);

    _sub = q.snapshots().listen((snap) {
      try {
        _stats
          ..clear()
          ..addEntries(
            snap.docs.map((d) {
              final parsed = StudentSlotStats.fromDoc(d);
              return MapEntry(parsed.studentId, parsed);
            }),
          );
        _isLoading = false;
        notifyListeners();
      } catch (e, st) {
        debugPrint('[STUDENT_STATS] parse error: $e\n$st');
        _isLoading = false;
        notifyListeners();
      }
    }, onError: (e, st) {
      debugPrint('[STUDENT_STATS] snapshots error: $e\n$st');
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
