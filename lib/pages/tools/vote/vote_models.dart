// vote_models.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum VoteType { binary, multiple }

enum VoteStatus { draft, active, closed }

enum ShowResultMode { realtime, afterEnd }

@immutable
class Vote {
  final String id;
  final String title;
  final VoteType type;

  /// UI 편집 모델에선 문자열만 들고 다니되,
  /// Firestore 저장/로드 시엔 Map 옵션도 지원(타이틀만 추출)합니다.
  final List<String> options;

  final VoteStatus status;

  /// ▼ Poll Settings
  final ShowResultMode showResult;
  final bool anonymous;
  final bool multiSelect;

  const Vote({
    required this.id,
    required this.title,
    required this.type,
    required this.options,
    required this.status,
    this.showResult = ShowResultMode.realtime,
    this.anonymous = true,
    this.multiSelect = false,
  });

  /// -------- JSON <-> MODEL ----------
  factory Vote.fromJson(Map<String, dynamic> j) {
    final settings = (j['settings'] as Map?) ?? const {};
    final show = (settings['show'] ?? 'realtime').toString();

    return Vote(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      type: (j['type'] == 'multiple') ? VoteType.multiple : VoteType.binary,
      options:
          ((j['options'] as List?)?.map((e) => e.toString()).toList() ??
              const []),
      status: switch ((j['status'] ?? '').toString()) {
        'active' => VoteStatus.active,
        'closed' => VoteStatus.closed,
        _ => VoteStatus.draft,
      },
      showResult:
          (show == 'after') ? ShowResultMode.afterEnd : ShowResultMode.realtime,
      anonymous: settings['anonymous'] == true,
      multiSelect: settings['multi'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type == VoteType.multiple ? 'multiple' : 'binary',
    'options': options,
    'status': switch (status) {
      VoteStatus.active => 'active',
      VoteStatus.closed => 'closed',
      _ => 'draft',
    },
    'settings': {
      'show': showResult == ShowResultMode.afterEnd ? 'after' : 'realtime',
      'anonymous': anonymous,
      'multi': (type == VoteType.binary) ? false : multiSelect,
    },
  };

  /// -------- 편의 메서드 ----------
  Vote copyWith({
    String? id,
    String? title,
    VoteType? type,
    List<String>? options,
    VoteStatus? status,
    ShowResultMode? showResult,
    bool? anonymous,
    bool? multiSelect,
  }) {
    return Vote(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      options: options ?? this.options,
      status: status ?? this.status,
      showResult: showResult ?? this.showResult,
      anonymous: anonymous ?? this.anonymous,
      multiSelect: multiSelect ?? this.multiSelect,
    );
  }

  /// Firestore에 저장할 Map (업데이트용)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': _voteTypeToString(type),
      'options': options,
      'status': _voteStatusToString(status),
      'settings': {
        'show': showResult == ShowResultMode.afterEnd ? 'after' : 'realtime',
        'anonymous': anonymous,
        'multi': (type == VoteType.binary) ? false : multiSelect,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Firestore 문서에서 모델 복원
  static Vote fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};

    // options: 문자열/맵 혼재 시 타이틀만 추출
    final rawOptions = (d['options'] as List?) ?? const [];
    final parsedTitles = <String>[];
    for (final item in rawOptions) {
      if (item is String) {
        final t = item.trim();
        if (t.isNotEmpty) parsedTitles.add(t);
      } else if (item is Map) {
        final t = (item['title'] ?? '').toString().trim();
        if (t.isNotEmpty) parsedTitles.add(t);
      }
    }

    // status: 문자열 우선, 과거 active(bool) 폴백
    final String? rawStatus = d['status']?.toString();
    final bool? activeBool = (d['active'] is bool) ? d['active'] as bool : null;
    final VoteStatus status =
        (rawStatus != null)
            ? _voteStatusFromString(rawStatus)
            : (activeBool == true ? VoteStatus.active : VoteStatus.draft);

    // settings
    final settings = (d['settings'] as Map?) ?? const {};
    final show = (settings['show'] ?? 'realtime').toString();

    return Vote(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      type: _voteTypeFromString(d['type']?.toString()),
      options: parsedTitles,
      status: status,
      showResult:
          (show == 'after') ? ShowResultMode.afterEnd : ShowResultMode.realtime,
      anonymous: settings['anonymous'] == true,
      multiSelect: settings['multi'] == true,
    );
  }
}

/// ===== Store (리스트/CRUD) =====
class VoteStore extends ChangeNotifier {
  final String sessionId;
  final CollectionReference<Map<String, dynamic>> _col;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  final List<Vote> _items = [];
  List<Vote> get items => List.unmodifiable(_items);

  VoteStore({required this.sessionId})
    : _col = FirebaseFirestore.instance.collection(
        'sessions/$sessionId/votes',
      ) {
    _sub = _col.orderBy('createdAt', descending: true).snapshots().listen((
      snap,
    ) {
      _items
        ..clear()
        ..addAll(snap.docs.map(Vote.fromDoc));
      notifyListeners();
    });
  }

  /// 생성: 기본 settings 포함(필요시 파라미터로 조정 가능)
  Future<void> createVote({
    required String title,
    required VoteType type,
    required List<String> options,
    ShowResultMode showResult = ShowResultMode.realtime,
    bool anonymous = true,
    bool multiSelect = false,
  }) async {
    final normalizedOptions =
        (type == VoteType.binary)
            ? const ['찬성', '반대']
            : options
                .map((e) => e.toString())
                .where((s) => s.trim().isNotEmpty)
                .toList();

    final data =
        Vote(
            id: '_new',
            title: title,
            type: type,
            options: normalizedOptions,
            status: VoteStatus.draft,
            showResult: showResult,
            anonymous: anonymous,
            multiSelect: (type == VoteType.binary) ? false : multiSelect,
          ).toMap()
          ..putIfAbsent('createdAt', () => FieldValue.serverTimestamp());

    await _col.add(data);
  }

  /// 전체 필드 업데이트(설정 포함)
  Future<void> updateVote(Vote updated) async {
    await _col.doc(updated.id).update(updated.toMap());
  }

  Future<void> deleteVote(String id) async {
    await _col.doc(id).delete();
  }

  /// 시작: 웹 집계용 startedAtMs도 같이 기록
  Future<void> startVote(String id) async {
    await _col.doc(id).set({
      'status': _voteStatusToString(VoteStatus.active),
      'startedAt': FieldValue.serverTimestamp(),
      'startedAtMs': DateTime.now().millisecondsSinceEpoch, // ★ 웹/허브 타임라인용
      'endedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> closeVote(String id) async {
    await _col.doc(id).set({
      'status': _voteStatusToString(VoteStatus.closed),
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// active 상태에서 문항 텍스트가 바뀐 경우, 기존 votes/binding을 최대한 보존하여 options 재구성
  Future<void> syncActiveIfNeeded(String id) async {
    final snap = await _col.doc(id).get();
    final data = snap.data();
    if (data == null) return;
    if (data['status'] != 'active') return;

    final raw = (data['options'] as List?) ?? const [];
    final existing = <Map<String, dynamic>>[];
    for (final it in raw) {
      if (it is Map) {
        existing.add({
          'id': (it['id'] ?? '').toString(),
          'title': (it['title'] ?? '').toString(),
          'votes': (it['votes'] is num) ? (it['votes'] as num).toInt() : 0,
          'binding': (it['binding'] is Map) ? (it['binding'] as Map) : const {},
        });
      } else if (it is String) {
        existing.add({'id': it, 'title': it, 'votes': 0});
      }
    }

    final edited = items.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('vote not found'),
    );

    final desired =
        edited.options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final mapByNorm = {
      for (final o in existing) _norm((o['title'] ?? '').toString()): o,
    };
    final rebuilt = <Map<String, dynamic>>[];
    for (var i = 0; i < desired.length; i++) {
      final t = desired[i];
      final k = _norm(t);
      if (mapByNorm.containsKey(k)) {
        final keep = mapByNorm[k]!;
        rebuilt.add({
          'id': (keep['id'] ?? 'opt_$i').toString(),
          'title': (keep['title'] ?? t).toString(),
          'votes': (keep['votes'] is num) ? (keep['votes'] as num).toInt() : 0,
          if (keep['binding'] != null) 'binding': keep['binding'],
        });
      } else {
        rebuilt.add({'id': 'opt_$i', 'title': t, 'votes': 0});
      }
    }

    await _col.doc(id).update({
      'options': rebuilt,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// ---- helpers ----
String _voteTypeToString(VoteType t) =>
    t == VoteType.binary ? 'binary' : 'multiple';

VoteType _voteTypeFromString(String? s) {
  switch (s) {
    case 'binary':
      return VoteType.binary;
    case 'multiple':
      return VoteType.multiple;
    default:
      return VoteType.binary;
  }
}

String _voteStatusToString(VoteStatus s) {
  switch (s) {
    case VoteStatus.draft:
      return 'draft';
    case VoteStatus.active:
      return 'active';
    case VoteStatus.closed:
      return 'closed';
  }
}

VoteStatus _voteStatusFromString(String? s) {
  switch (s) {
    case 'draft':
      return VoteStatus.draft;
    case 'active':
      return VoteStatus.active;
    case 'closed':
      return VoteStatus.closed;
    default:
      return VoteStatus.draft;
  }
}

String _norm(String s) => s.trim().toLowerCase();
