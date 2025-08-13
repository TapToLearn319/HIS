

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../main.dart';
import 'grouping_service.dart';

enum GroupingMode { byGroups, bySize }

class GroupingController extends ChangeNotifier {
  GroupingController({FirebaseFirestore? firestore, GroupingService? service})
    : _fs = firestore ?? FirebaseFirestore.instance,
      _service = service ?? const GroupingService();

  final FirebaseFirestore _fs;
  final GroupingService _service;

  // config
  final bool useFirestoreHistory = true;    // 히스토리 안남길거면 false
  static const int _historyLimit = 20;

  // state
  final List<String> allStudents = <String>[];
  final Set<String> selected = <String>{};
  String query = '';

  GroupingMode mode = GroupingMode.byGroups;
  int groupsCount = 4;
  int sizePerGroup = 3;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _studentsSub;
  bool _firstStudentsLoad = true;

  // lifecycle
  void init() {
    _studentsSub = _fs
        .collection('students')
        .orderBy('name')
        .snapshots()
        .listen(
          _onStudents,
          onError: (e, st) {
            dev.log('[Grouping] students listener error: $e', stackTrace: st);
          },
        );

    // 학생 화면에 "grouping 모드" 브로드캐스트
    channel.postMessage(jsonEncode({'type': 'tool_mode', 'mode': 'grouping'}));
  }

  void disposeAll() {
    _studentsSub?.cancel();
  }

  void _onStudents(QuerySnapshot<Map<String, dynamic>> snap) {
    final names =
        snap.docs
            .map((d) {
              final data = d.data();
              final n = (data['name'] ?? d.id).toString().trim();
              return n.isEmpty ? d.id : n;
            })
            .where((n) => n.isNotEmpty)
            .toList();

    allStudents
      ..clear()
      ..addAll(names);

    if (_firstStudentsLoad) {
      selected
        ..clear()
        ..addAll(names);
      _firstStudentsLoad = false;
    } else {
      selected.removeWhere((s) => !names.contains(s));
    }

    dev.log('[Grouping] students loaded: ${names.length}');
    notifyListeners();
  }

  void setQuery(String v) {
    query = v;
    notifyListeners();
  }

  void toggleName(String name) {
    if (selected.contains(name)) {
      selected.remove(name);
    } else {
      selected.add(name);
    }
    notifyListeners();
  }

  void setMode(GroupingMode m) {
    mode = m;
    notifyListeners();
  }

  void setGroupsCount(int v) {
    groupsCount = v;
    notifyListeners();
  }

  void setSizePerGroup(int v) {
    sizePerGroup = v;
    notifyListeners();
  }

  void addName(String name) {
    final t = name.trim();
    if (t.isEmpty) return;
    if (!allStudents.contains(t)) {
      allStudents.add(t);
    }
    selected.add(t);
    notifyListeners();
  }

  List<String> get filtered =>
      allStudents
          .where((s) => s.toLowerCase().contains(query.toLowerCase()))
          .toList();

  // ===== 그룹 만들기 =====
  Future<void> makeGroups() async {
    final selectedList = allStudents.where(selected.contains).toList();

    if (selectedList.length < 2) {
      channel.postMessage(
        jsonEncode({'type': 'toast', 'message': '선택된 학생이 2명 이상이어야 합니다.'}),
      );
      return;
    }

    // 1) 그룹 생성 (히스토리 최적화 on/off)
    List<List<String>> groups;
    if (useFirestoreHistory) {
      groups = await _makeBestGroupsWithHistory(selectedList);
    } else {
      groups = _service.generate(
        selected: selectedList,
        byGroups: mode == GroupingMode.byGroups,
        groupsCount: groupsCount,
        sizePerGroup: sizePerGroup,
      );
    }

    // 2) 학생 화면 브로드캐스트
    channel.postMessage(
      jsonEncode({
        'type': 'grouping_result',
        'title': 'Find your Team !',
        'groups': groups,
      }),
    );

    // 3) Firestore 세션 저장 (옵션)
    if (useFirestoreHistory) {
      try {
        await _fs.collection('groupingSessions').add({
          'createdAt': FieldValue.serverTimestamp(),
          'mode': mode == GroupingMode.byGroups ? 'byGroups' : 'bySize',
          // ⬇️ 배열 안에 배열을 직접 넣지 말고, 배열 안에 Map을 넣습니다.
          'groups':
              groups
                  .asMap()
                  .entries
                  .map(
                    (e) => {
                      'index': e.key, // 선택 (가독성/정렬용)
                      'members':
                          e.value, // 여기는 List<String> 이어도 OK (Map의 필드이므로)
                    },
                  )
                  .toList(),
          'selected': selectedList, // 이건 List<String>이라 그대로 OK
        });
      } catch (e, st) {
        dev.log('[Grouping] save session failed: $e', stackTrace: st);
      }
    }
  }

  Future<List<List<String>>> _makeBestGroupsWithHistory(
    List<String> selectedList,
  ) async {
    final penalty = await _buildPairPenalty(selectedList.toSet());
    const int trials = 120;
    List<List<String>> best = [];
    int bestScore = 1 << 30;

    for (int t = 0; t < trials; t++) {
      final candidate = _service.generate(
        selected: selectedList,
        byGroups: mode == GroupingMode.byGroups,
        groupsCount: groupsCount,
        sizePerGroup: sizePerGroup,
      );
      final s = _service.scoreGroups(candidate, penalty);
      if (s < bestScore) {
        best = candidate;
        bestScore = s;
      }
    }

    dev.log(
      '[Grouping] bestScore=$bestScore (lower is better), historyUsed=${penalty.isNotEmpty}',
    ); // 테스트 후 주석 처리 할 것
    return best;
  }

  Future<Map<String, int>> _buildPairPenalty(Set<String> population) async {
    try {
      final q =
          await _fs
              .collection('groupingSessions')
              .orderBy('createdAt', descending: true)
              .limit(_historyLimit)
              .get();

      const int maxW = 10;
      const int minW = 1;

      // clamp()는 num을 반환하므로 반드시 int로 캐스팅
      final int steps =
          q.docs.isEmpty ? 1 : (q.docs.length.clamp(1, maxW) as int);

      final int step = ((maxW - minW) ~/ steps);
      final int clampedStep = (step.clamp(0, maxW - 1) as int);

      final Map<String, int> penalty = <String, int>{};

      int idx = 0;
      for (final doc in q.docs) {
        final data = doc.data();
        final int weight = (maxW - idx * clampedStep).clamp(minW, maxW) as int;
        final List<dynamic> groupsRaw = (data['groups'] as List?) ?? const [];

        for (final g in groupsRaw) {
          List<String> members = const [];

          // ✅ 새 구조: [{ index: n, members: [..] }, ...]
          if (g is Map && g['members'] is List) {
            members = (g['members'] as List).map((e) => e.toString()).toList();
          }
          // ✅ 예전 구조(혹시 이미 들어간 데이터가 있다면): [[..], [..], ...]
          else if (g is List) {
            members = g.map((e) => e.toString()).toList();
          } else {
            continue;
          }

          // population(현재 선택된 학생들)만 고려
          members = members.where((name) => population.contains(name)).toList();

          for (int i = 0; i < members.length; i++) {
            for (int j = i + 1; j < members.length; j++) {
              final k = _pairKey(members[i], members[j]);
              final prev = penalty[k] ?? 0;
              penalty[k] = prev + weight;
            }
          }
        }
      }

      dev.log(
        '[Grouping] history docs=${q.docs.length}, steps=$steps, step=$step, clampedStep=$clampedStep, pairs=${penalty.length}',
      );
      return penalty;
    } catch (e, st) {
      dev.log('[Grouping] buildPairPenalty failed: $e', stackTrace: st);
      return <String, int>{};
    }
  }

  String _pairKey(String a, String b) =>
      (a.compareTo(b) <= 0) ? '$a|$b' : '$b|$a';
}
