import 'dart:math';
import 'package:flutter/material.dart';
import 'package:project/widgets/help_badge.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Providers
import '../../provider/students_provider.dart';
import '../../provider/hub_provider.dart';
import '../../sidebar_menu.dart';

const _kAppBg = Color(0xFFF6FAFF);

// ===== 카드/스타일 =====
const _kCardW = 1011.0;
const _kCardH = 544.0;
const _kCardRadius = 10.0;
const _kCardBorder = Color(0xFFD2D2D2);

const _kAttendedBlue = Color(0xFFCEE6FF);
const _kAssignedDashed = Color(0xFFCBD5E1);
const _kTextDark = Color(0xFF0B1324);
const _kTextNum = Color(0xFF1F2937);

class _DragSeatPayload {
  final int seatNo;       // 드래그한 좌석 번호 (1-based)
  final String? sid;      // 드래그한 좌석의 학생 ID (없으면 null)
  const _DragSeatPayload({required this.seatNo, required this.sid});
}

/* ===================== 규칙/배치 헬퍼 ===================== */

class _SeatRules {
  _SeatRules({
    required this.cols,
    required this.rows,
    required this.pairGroups,
    required this.sepGroups,
  });
  final int cols;
  final int rows;
  /// 같이 앉히기(붙이기) 그룹들 – 각 원소는 ["Mark","Anna"] 같은 이름/ID 배열
  final List<List<String>> pairGroups;
  /// 떼어놓기 그룹들 – 각 원소는 ["Tom","Jerry"] 같은 이름/ID 배열
  final List<List<String>> sepGroups;
}

/// Firestore에 저장된 규칙을 불러온다(새 구조 + 예전 문자열 모두 지원).
Future<_SeatRules> _loadSeatRules(String hubId, String fileId) async {
  final fs = FirebaseFirestore.instance;
  final doc = await fs.doc('hubs/$hubId/randomSeatFiles/$fileId').get();
  final data = doc.data() ?? {};

  final cols = (data['cols'] as num?)?.toInt() ?? 6;
  final rows = (data['rows'] as num?)?.toInt() ?? 4;

  final constraints = (data['constraints'] as Map?) ?? const {};

  // 새 구조: [{members:[...]}] → [[...],[...]]
  List<List<String>> _readGroupList(dynamic v) {
    final out = <List<String>>[];
    if (v is List) {
      for (final e in v) {
        if (e is Map && e['members'] is List) {
          final members = (e['members'] as List)
              .map((x) => x.toString().trim())
              .where((x) => x.isNotEmpty)
              .toList();
          if (members.length >= 2) out.add(members);
        }
      }
    }
    return out;
  }

  // 예전 문자열 "A-B, C-D" → [[A,B],[C,D]]
  List<List<String>> _parsePairs(String s) {
    final out = <List<String>>[];
    for (final seg in s.split(',')) {
      final t = seg.trim();
      if (t.isEmpty) continue;
      final parts = t.split('-').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parts.length >= 2) out.add(parts);
    }
    return out;
  }

  final pg = _readGroupList(constraints['pairingGroups']) +
      _parsePairs((constraints['pairing'] ?? '').toString());
  final sg = _readGroupList(constraints['separationGroups']) +
      _parsePairs((constraints['separation'] ?? '').toString());

  // 중복/1인 그룹 제거
  List<List<String>> _clean(List<List<String>> src) {
    return src
        .map((g) => g.map((e) => e.trim()).toSet().toList())
        .where((g) => g.length >= 2)
        .toList();
  }

  return _SeatRules(
    cols: cols,
    rows: rows,
    pairGroups: _clean(pg),
    sepGroups: _clean(sg),
  );
}

/// students 컬렉션에서 name → id 매핑(소문자 key) 생성
Future<Map<String, String>> _buildNameToIdMap(String hubId) async {
  final fs = FirebaseFirestore.instance;
  final snap = await fs.collection('hubs/$hubId/students').get();
  final map = <String, String>{}; // nameLower -> sid
  for (final d in snap.docs) {
    final data = d.data();
    final raw = (data['name'] ?? d.id).toString().trim();
    if (raw.isNotEmpty) map[raw.toLowerCase()] = d.id;
  }
  return map;
}

/// 규칙 멤버 토큰(이름 or ID)을 seatMap에 실제 배정 중인 SID로 매핑
List<List<String>> _mapTokensToAssignedSids({
  required List<List<String>> groups,
  required Map<String, String> nameToId,
  required Set<String> assignedSids,
}) {
  String? _tokenToSid(String token) {
    final t = token.trim();
    if (t.isEmpty) return null;
    if (assignedSids.contains(t)) return t; // 이미 ID
    final sid = nameToId[t.toLowerCase()];
    if (sid == null) return null;
    return assignedSids.contains(sid) ? sid : null;
  }

  final out = <List<String>>[];
  for (final g in groups) {
    final mapped = <String>{};
    for (final m in g) {
      final sid = _tokenToSid(m);
      if (sid != null) mapped.add(sid);
    }
    if (mapped.length >= 2) out.add(mapped.toList());
  }
  return out;
}

class _RC {
  final int r;
  final int c;
  const _RC(this.r, this.c);
}

_RC _rcOfSeat(int seatNo, int cols) {
  final idx = seatNo - 1;
  return _RC(idx ~/ cols, idx % cols);
}

bool _adjacentH(int a, int b, int cols) {
  final A = _rcOfSeat(a, cols), B = _rcOfSeat(b, cols);
  return A.r == B.r && (A.c - B.c).abs() == 1;
}

List<List<int>> _contiguousRunsInRow(List<int> rowSeats) {
  if (rowSeats.isEmpty) return const [];
  final seats = [...rowSeats]..sort();
  final runs = <List<int>>[];
  var cur = <int>[seats.first];
  for (int i = 1; i < seats.length; i++) {
    if (seats[i] == seats[i - 1] + 1) {
      cur.add(seats[i]);
    } else {
      runs.add(cur);
      cur = <int>[seats[i]];
    }
  }
  runs.add(cur);
  return runs;
}

bool _checkAssignment(
  Map<int, String> seatToSid,
  int cols,
  List<List<String>> pairGroups,
  List<List<String>> sepGroups,
) {
  final sidToSeat = <String, int>{};
  seatToSid.forEach((seat, sid) {
    if (sid.isNotEmpty) sidToSeat[sid] = seat;
  });

  // 붙이기: 같은 행 + 연속 좌석
  for (final g in pairGroups) {
    final seats = g.map((s) => sidToSeat[s]).whereType<int>().toList();
    if (seats.length <= 1) continue;
    final rows = seats.map((x) => _rcOfSeat(x, cols).r).toSet();
    if (rows.length != 1) return false;
    seats.sort();
    for (int i = 1; i < seats.length; i++) {
      if (seats[i] != seats[i - 1] + 1) return false;
    }
  }

  // 떼기: 같은 행 인접 금지
  for (final g in sepGroups) {
    final seats = g.map((s) => sidToSeat[s]).whereType<int>().toList();
    for (int i = 0; i < seats.length; i++) {
      for (int j = i + 1; j < seats.length; j++) {
        if (_adjacentH(seats[i], seats[j], cols)) return false;
      }
    }
  }
  return true;
}

/// 규칙을 고려해 배치 시도 (실패 시 null)
Map<int, String>? _tryAssignWithRules({
  required List<int> seatNos,
  required List<String> students, // SIDs
  required int cols,
  required int rows,
  required List<List<String>> pairGroups, // SIDs
  required List<List<String>> sepGroups,  // SIDs
  int trials = 500,
}) {
  final rnd = Random();

  // 행별 좌석 + 연속 run 계산
  final seatsByRow = <int, List<int>>{};
  for (final s in seatNos) {
    final r = _rcOfSeat(s, cols).r;
    (seatsByRow[r] ??= <int>[]).add(s);
  }
  final rowRuns = <int, List<List<int>>>{};
  seatsByRow.forEach((r, list) {
    rowRuns[r] = _contiguousRunsInRow(list);
  });

  final inPair = <String>{};
  for (final g in pairGroups) {
    inPair.addAll(g);
  }
  final singles = students.where((s) => !inPair.contains(s)).toList();

  // 큰 블록부터 먼저
  final filteredPairs = [...pairGroups]..sort((a, b) => b.length.compareTo(a.length));

  for (int t = 0; t < trials; t++) {
    final seatToSid = <int, String>{};
    final freeRuns = <int, List<List<int>>>{};
    rowRuns.forEach((r, runs) => freeRuns[r] = runs.map((x) => [...x]).toList());

    bool fail = false;

    // 1) 붙이기 그룹 배치
    for (final g in filteredPairs) {
      final need = g.length;
      final candidates = <({int r, int ri, int si})>[];
      freeRuns.forEach((r, runs) {
        for (int ri = 0; ri < runs.length; ri++) {
          final run = runs[ri];
          for (int si = 0; si + need <= run.length; si++) {
            candidates.add((r: r, ri: ri, si: si));
          }
        }
      });
      if (candidates.isEmpty) { fail = true; break; }

      final pick = candidates[rnd.nextInt(candidates.length)];
      final run = freeRuns[pick.r]![pick.ri];
      final chosenSeats = run.sublist(pick.si, pick.si + need);

      for (int i = 0; i < need; i++) {
        seatToSid[chosenSeats[i]] = g[i];
      }
      run.removeRange(pick.si, pick.si + need);
      if (run.isEmpty) {
        freeRuns[pick.r]!.removeAt(pick.ri);
      }
    }
    if (fail) continue;

    // 2) 나머지 학생 랜덤
    final remainingSeats = seatNos.where((s) => !seatToSid.containsKey(s)).toList()..shuffle(rnd);
    final remainingStudents = [...singles]..shuffle(rnd);
    if (remainingStudents.length != remainingSeats.length) {
      continue;
    }
    for (int i = 0; i < remainingSeats.length; i++) {
      seatToSid[remainingSeats[i]] = remainingStudents[i];
    }

    // 3) 최종 검증 (떼기 포함)
    if (_checkAssignment(seatToSid, cols, pairGroups, sepGroups)) {
      return seatToSid;
    }
  }
  return null;
}

/* ===================== 페이지 위젯 ===================== */

class RandomSeatPage extends StatefulWidget {
  const RandomSeatPage({super.key});
  @override
  State<RandomSeatPage> createState() => _RandomSeatPageState();
}

class _RandomSeatPageState extends State<RandomSeatPage> {
  bool _hidOnEnter = false; 
  bool _working = false;
  bool _didBootstrap = false;

  @override
void initState() {
  super.initState();

  // 첫 프레임 이후에 한 번만 강제로 show=false
  WidgetsBinding.instance.addPostFrameCallback((_) => _hideDisplayOnEnter());

  // 🔥 Safety Guard: 웹에서 _working이 True로 남을 경우 자동 해제
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_working) {
        // 혹시 초기 Firestore 요청이 실패하거나 중단되어도
        // UI가 덮이지 않도록 자동으로 해제
        setState(() => _working = false);
      }
    });
  });
}

  Future<void> _hideDisplayOnEnter() async {
    if (_hidOnEnter || !mounted) return;
    _hidOnEnter = true;

    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null || hubId.isEmpty) return;

    // UI를 즉시 반영(토글 이미지가 바로 'SHOW'로 보이게)
    setState(() => _showOverride = false);

    await FirebaseFirestore.instance.doc('hubs/$hubId').set({
      'randomSeat': {'show': false}
    }, SetOptions(merge: true));

    // (선택) 완전 대기 보장을 원하면 아래 활성화: activeFileId도 비우기
    // await FirebaseFirestore.instance.doc('hubs/$hubId')
    //   .update({'randomSeat.activeFileId': FieldValue.delete()}).catchError((_) {});
  }

  String _seatKey(int index) => '${index + 1}';
  bool? _showOverride;     // 스냅샷 오기 전, 로컬에서 먼저 토글 반영
  bool _updatingShow = false; 
  String? get _fileId {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['fileId'] is String) return args['fileId'] as String;
    return null;
  }

  Future<void> _applyDragDrop({
  required int fromSeat,
  required String? fromSid,
  required int toSeat,
  required String? toSid,
}) async {
  if (fromSeat == toSeat) return; // 같은 칸 드롭 방지
  final hubId = context.read<HubProvider>().hubId;
  final fileId = _fileId;
  if (hubId == null || hubId.isEmpty || fileId == null) return;

  final fs = FirebaseFirestore.instance;
  final seatCol = fs.collection('hubs/$hubId/randomSeatFiles/$fileId/seatMap');

  final batch = fs.batch();
  // from 자리에 toSid(있을 수도/없을 수도)
  batch.set(seatCol.doc(fromSeat.toString()), {'studentId': toSid}, SetOptions(merge: true));
  // to 자리에 fromSid(있을 수도/없을 수도)
  batch.set(seatCol.doc(toSeat.toString()), {'studentId': fromSid}, SetOptions(merge: true));
  // 메타 업데이트
  batch.set(
    fs.doc('hubs/$hubId/randomSeatFiles/$fileId'),
    {'updatedAt': FieldValue.serverTimestamp()},
    SetOptions(merge: true),
  );
  await batch.commit();
}

  Future<void> _bootstrapFileSeatMapIfEmpty({
    required String hubId,
    required String fileId,
  }) async {
    if (_didBootstrap) return;
    final fs = FirebaseFirestore.instance;

    // 1) 파일 seatMap이 비었는지 확인
    final seatCol = fs.collection('hubs/$hubId/randomSeatFiles/$fileId/seatMap');
    final cur = await seatCol.limit(1).get();
    if (cur.size > 0) {
      _didBootstrap = true;
      return;
    }

    // 2) 복사할 원본 세션 결정
    final fileDoc = await fs.doc('hubs/$hubId/randomSeatFiles/$fileId').get();
    final hubDoc = await fs.doc('hubs/$hubId').get();
    final baseSid = (fileDoc.data()?['baseSessionId'] as String?)?.trim();
    final hubSid = (hubDoc.data()?['currentSessionId'] as String?)?.trim();
    final sid = (baseSid?.isNotEmpty == true ? baseSid : hubSid);

    if (sid == null || sid.isEmpty) {
      _didBootstrap = true;
      return;
    }

    // 3) 원본 세션 seatMap 복사
    final src = await fs.collection('hubs/$hubId/sessions/$sid/seatMap').get();
    final batch = fs.batch();
    for (final d in src.docs) {
      final data = d.data();
      batch.set(seatCol.doc(d.id), {
        'studentId': data['studentId'],
      }, SetOptions(merge: true));
    }
    // rows/cols 채우기
    final sessMeta = await fs.doc('hubs/$hubId/sessions/$sid').get();
    final cols = (sessMeta.data()?['cols'] as num?)?.toInt();
    final rows = (sessMeta.data()?['rows'] as num?)?.toInt();
    batch.set(fs.doc('hubs/$hubId/randomSeatFiles/$fileId'), {
      if (cols != null) 'cols': cols,
      if (rows != null) 'rows': rows,
      'updatedAt': FieldValue.serverTimestamp(),
      'baseSessionId': sid,
    }, SetOptions(merge: true));

    await batch.commit();
    _didBootstrap = true;
  }

  // === MIX: 규칙 반영 셔플 ===
  Future<void> _randomize() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final hubId = context.read<HubProvider>().hubId;
      final fileId = _fileId;
      if (hubId == null || hubId.isEmpty || fileId == null) {
        _snack('파일 정보를 찾지 못했습니다.');
        return;
      }

      final fs = FirebaseFirestore.instance;
      final seatCol = fs.collection('hubs/$hubId/randomSeatFiles/$fileId/seatMap');
      final snap = await seatCol.get();

      // 좌석번호 오름차순
      final docs = [...snap.docs]..sort((a, b) {
        int ai = int.tryParse(a.id) ?? 0;
        int bi = int.tryParse(b.id) ?? 0;
        return ai.compareTo(bi);
      });

      // 배정된 좌석/학생
      final assignedSeatNos = <int>[];
      final assignedStudentSet = <String>{};
      for (final d in docs) {
        final sid = (d.data()['studentId'] as String?)?.trim();
        if (sid != null && sid.isNotEmpty) {
          assignedSeatNos.add(int.tryParse(d.id) ?? 0);
          assignedStudentSet.add(sid);
        }
      }
      if (assignedStudentSet.isEmpty) {
        _snack('배정된 학생이 없습니다.');
        return;
      }
      

      // 규칙 로드
      final rules = await _loadSeatRules(hubId, fileId);

      // 이름→ID 매핑 만들고, 규칙 토큰을 실제 배정 SID로 매핑
      final nameToId = await _buildNameToIdMap(hubId);
      final pairMapped = _mapTokensToAssignedSids(
        groups: rules.pairGroups,
        nameToId: nameToId,
        assignedSids: assignedStudentSet,
      );
      final sepMapped = _mapTokensToAssignedSids(
        groups: rules.sepGroups,
        nameToId: nameToId,
        assignedSids: assignedStudentSet,
      );

      final hasRules = pairMapped.isNotEmpty || sepMapped.isNotEmpty;

      Map<int, String>? plan;
      final students = assignedStudentSet.toList();

      if (hasRules) {
        plan = _tryAssignWithRules(
          seatNos: assignedSeatNos,
          students: students,
          cols: rules.cols,
          rows: rules.rows,
          pairGroups: pairMapped,
          sepGroups: sepMapped,
          trials: 500,
        );
      }

      // 규칙 실패 또는 규칙 없음 → 랜덤
      plan ??= () {
        final shuffled = [...students]..shuffle(Random());
        final map = <int, String>{};
        for (int i = 0; i < assignedSeatNos.length; i++) {
          map[assignedSeatNos[i]] = shuffled[i % shuffled.length];
        }
        return map;
      }();

      // Firestore 반영
      final batch = fs.batch();
      for (final d in docs) {
        final seatNo = int.tryParse(d.id) ?? 0;
        final newSid = plan[seatNo];
        batch.set(d.reference, {'studentId': newSid}, SetOptions(merge: true));
      }
      batch.set(
        fs.doc('hubs/$hubId/randomSeatFiles/$fileId'),
        {'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await batch.commit();

      if (hasRules && plan == null) {
        _snack('규칙을 모두 만족하지 못해 무작위로 MIX 했습니다.');
      } else if (hasRules) {
        _snack('규칙을 반영하여 MIX 완료!');
      } else {
        _snack('MIX 완료!');
      }
    } catch (e) {
      _snack('MIX 실패: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // === SAVE: 이 카드 seatMap에 저장 ===
  Future<void> _saveToCard() async {
  if (_working) return;
  setState(() => _working = true);
  try {
    final hubId = context.read<HubProvider>().hubId;
    final fileId = _fileId;
    if (hubId == null || hubId.isEmpty || fileId == null) {
      _snack('파일 정보를 찾지 못했습니다.');
      return;
    }

    final fs = FirebaseFirestore.instance;

    // 1) 카드 seatMap 보수적 저장 + 파일 updatedAt 갱신 (기존 동작 유지)
    final seatCol = fs.collection('hubs/$hubId/randomSeatFiles/$fileId/seatMap');
    final cur = await seatCol.get();
    final batch = fs.batch();
    for (final d in cur.docs) {
      final data = d.data();
      batch.set(seatCol.doc(d.id), {
        'studentId': data['studentId'],
      }, SetOptions(merge: true));
    }
    batch.set(
      fs.doc('hubs/$hubId/randomSeatFiles/$fileId'),
      {'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    await batch.commit();

    // 2) 현재 세션으로도 복사 (있을 때만)
    final hubDoc = await fs.doc('hubs/$hubId').get();
    final sid = (hubDoc.data()?['currentSessionId'] as String?)?.trim();

    if (sid == null || sid.isEmpty) {
      _snack('이 카드에만 저장했습니다. (현재 세션이 설정되어 있지 않습니다)');
      return;
    }

    // 세션 seatMap 초기화 후 파일 seatMap 내용으로 채우기
    final sessionSeatCol = fs.collection('hubs/$hubId/sessions/$sid/seatMap');
    final oldSession = await sessionSeatCol.get();

    final batch2 = fs.batch();
    for (final d in oldSession.docs) {
      batch2.delete(d.reference);
    }
    for (final d in cur.docs) {
      final data = d.data();
      batch2.set(sessionSeatCol.doc(d.id), {
        'studentId': data['studentId'],
      }, SetOptions(merge: true));
    }

    // 파일 메타(rows/cols) → 세션 메타로 반영
    final fileMeta = await fs.doc('hubs/$hubId/randomSeatFiles/$fileId').get();
    final cols = (fileMeta.data()?['cols'] as num?)?.toInt();
    final rows = (fileMeta.data()?['rows'] as num?)?.toInt();
    batch2.set(
      fs.doc('hubs/$hubId/sessions/$sid'),
      {
        if (cols != null) 'cols': cols,
        if (rows != null) 'rows': rows,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // (선택) 어떤 파일에서 보낸건지 허브 상태에 표시만 해 둠 — show 토글은 별도 버튼에서
    batch2.set(
      fs.doc('hubs/$hubId'),
      {
        'randomSeat': {
          'byFileId': fileId,
        }
      },
      SetOptions(merge: true),
    );

    await batch2.commit();

    _snack('저장 완료: 카드 + 현재 세션에 반영했습니다.');
  } catch (e) {
    _snack('저장 실패: $e');
  } finally {
    if (mounted) setState(() => _working = false);
  }
}

Future<void> _setDisplayShow(bool value) async {
  final hubId = context.read<HubProvider>().hubId;
  final fileId = _fileId;
  if (hubId == null || hubId.isEmpty || fileId == null) return;

  final hubRef = FirebaseFirestore.instance.doc('hubs/$hubId');

  final randomSeat = <String, dynamic>{'show': value};
  if (value) {
    randomSeat['activeFileId'] = fileId;
  } else {
    randomSeat['activeFileId'] = FieldValue.delete();
  }

  await hubRef.set({'randomSeat': randomSeat}, SetOptions(merge: true));
}

  Future<void> _showToDisplay() async {
  if (_working) return;
  setState(() => _working = true);
  try {
    final hubId = context.read<HubProvider>().hubId;
    final fileId = _fileId;
    if (hubId == null || hubId.isEmpty || fileId == null) {
      _snack('파일 정보를 찾지 못했습니다.');
      return;
    }

    final fs = FirebaseFirestore.instance;
    final hubRef = fs.doc('hubs/$hubId');
    final fileRef = fs.doc('hubs/$hubId/randomSeatFiles/$fileId');

    // 1) currentSessionId 확보(없으면 생성)
    final hubDoc = await hubRef.get();
    String? sid = (hubDoc.data()?['currentSessionId'] as String?)?.trim();

    // 파일 메타에서 rows/cols 읽어오기
    final fileMeta = await fileRef.get();
    final cols = (fileMeta.data()?['cols'] as num?)?.toInt() ?? 6;
    final rows = (fileMeta.data()?['rows'] as num?)?.toInt() ?? 4;

    if (sid == null || sid.isEmpty) {
      final sessRef = fs.collection('hubs/$hubId/sessions').doc();
      sid = sessRef.id;
      await sessRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'cols': cols,
        'rows': rows,
        'source': {'type': 'randomSeatFile', 'fileId': fileId},
      }, SetOptions(merge: true));
      await hubRef.set({'currentSessionId': sid}, SetOptions(merge: true));
    } else {
      // 기존 세션 메타도 파일 메타로 맞춰주기(옵션)
      await fs.doc('hubs/$hubId/sessions/$sid').set({
        'cols': cols,
        'rows': rows,
        'updatedAt': FieldValue.serverTimestamp(),
        'source': {'type': 'randomSeatFile', 'fileId': fileId},
      }, SetOptions(merge: true));
    }

    // 2) 파일 seatMap → 세션 seatMap 으로 복사(기존 세션 seatMap은 모두 삭제 후 덮어쓰기)
    final srcCol = fs.collection('hubs/$hubId/randomSeatFiles/$fileId/seatMap');
    final dstCol = fs.collection('hubs/$hubId/sessions/$sid/seatMap');

    final prev = await dstCol.get();
    final src  = await srcCol.get();

    final batch = fs.batch();
    for (final d in prev.docs) {
      batch.delete(d.reference);
    }
    for (final d in src.docs) {
      final data = d.data();
      batch.set(dstCol.doc(d.id), {
        'studentId': data['studentId'],
      }, SetOptions(merge: true));
    }
    await batch.commit();

    _snack('디스플레이에 표시했습니다.');
  } catch (e) {
    _snack('표시 실패: $e');
  } finally {
    if (mounted) setState(() => _working = false);
  }
}


  void _snack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    (m ?? ScaffoldMessenger.of(context))
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final studentsProvider = context.watch<StudentsProvider>();
    final hubId = context.watch<HubProvider>().hubId;
    final fileId = _fileId;

    return AppScaffold(
      selectedIndex: 0,
      body: Scaffold(
        backgroundColor: _kAppBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF6FAFF),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: (hubId == null || fileId == null)
            ? const Center(child: Text('파일을 찾을 수 없습니다.'))
            : Stack(
                children: [
                  // === 파일 메타(rows/cols) + seatMap 구독 ===
                  _FileSeatBoard(
                    hubId: hubId,
                    fileId: fileId,
                    studentsProvider: studentsProvider,
                    onMix: _randomize,
                    onDrop: (fromSeat, fromSid, toSeat, toSid) {
    _applyDragDrop(fromSeat: fromSeat, fromSid: fromSid, toSeat: toSeat, toSid: toSid);
  },
                  ),

                  Positioned(
                    right: 180,
                    bottom: 20,
                    child: SafeArea(
                      top: false,
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .doc('hubs/${context.read<HubProvider>().hubId}')
                            .snapshots(),
                        builder: (context, snap) {
                          final snapshotShow = (snap.data?.data()?['randomSeat']?['show'] as bool?) ?? false;

                          // 로컬 오버라이드가 있으면 그 값을 우선 사용 → 즉시 이미지 전환
                          final effectiveShow = _showOverride ?? snapshotShow;

                          return _ShowHideFab(
                            show: effectiveShow,
                            disabled: _updatingShow,
                            onToggle: () async {
                              if (_updatingShow) return;
                              setState(() {
                                _updatingShow = true;
                                _showOverride = !effectiveShow; // ← 로컬로 즉시 뒤집어 이미지 변경
                              });
                              try {
                                await _setDisplayShow(!effectiveShow); // 서버 반영
                              } finally {
                                if (!mounted) return;
                                setState(() => _updatingShow = false);
                                // 스냅샷이 곧 따라오므로 굳이 _showOverride를 바로 null로 되돌릴 필요는 없음
                                // (원하면: if (_showOverride == snapshotShow) _showOverride = null;)
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  // 우측 하단: SAVE (→ 카드에 저장)
                  _SaveFabImage(onTap: _saveToCard),

                  if (_working)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/* ------------------------ Seat Board (파일 스코프) ------------------------ */

class _FileSeatBoard extends StatelessWidget {
  const _FileSeatBoard({
    required this.hubId,
    required this.fileId,
    required this.studentsProvider,
    required this.onMix,
    required this.onDrop, 
  });

  final String hubId;
  final String fileId;
  final StudentsProvider studentsProvider;
  final VoidCallback onMix;
  final void Function(int fromSeat, String? fromSid, int toSeat, String? toSid) onDrop;

  String _seatKey(int index) => '${index + 1}';

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    final fileDocStream = fs.doc('hubs/$hubId/randomSeatFiles/$fileId').snapshots();
    final seatMapStream = fs
        .collection('hubs/$hubId/randomSeatFiles/$fileId/seatMap')
        .snapshots();
    final studentsStream = fs.collection('hubs/$hubId/students').snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fileDocStream,
      builder: (context, metaSnap) {
        final meta = metaSnap.data?.data();
        final int cols = (meta?['cols'] as num?)?.toInt() ?? 6;
        final int rows = (meta?['rows'] as num?)?.toInt() ?? 4;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: seatMapStream,
          builder: (context, seatSnap) {
            // ★ 비어 있으면 한 번만 초기화 시도
            if ((seatSnap.data?.size ?? 0) == 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final state = context.findAncestorStateOfType<_RandomSeatPageState>();
                state?._bootstrapFileSeatMapIfEmpty(
                  hubId: hubId,
                  fileId: fileId,
                );
              });
            }

            final Map<String, String?> seatMap = {};
            if (seatSnap.data != null) {
              for (final d in seatSnap.data!.docs) {
                seatMap[d.id] = (d.data()['studentId'] as String?)?.trim();
              }
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: studentsStream,
              builder: (context, stuSnap) {
                // 화면 타이틀 왼쪽 총원 계산
                final assignedCount =
                    seatMap.values.where((v) => (v?.isNotEmpty ?? false)).length;

                final child = _DesignSurfaceRandom(
                  cols: cols,
                  rows: rows,
                  seatMap: seatMap,
                  studentsProvider: studentsProvider,
                  assignedCount: assignedCount,
                  onMix: onMix,
                  onDrop: onDrop, 
                );

                // 1280×720 스케일/클리핑 래퍼
                return LayoutBuilder(
                  builder: (context, box) {
                    const designW = 1280.0;
                    const designH = 720.0;
                    final scaleW = box.maxWidth / designW;
                    final scaleH = box.maxHeight / designH;
                    final scaleFit = scaleW < scaleH ? scaleW : scaleH;

                    if (scaleFit < 1) {
                      return ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          minWidth: 0,
                          minHeight: 0,
                          maxWidth: double.infinity,
                          maxHeight: double.infinity,
                          child: SizedBox(
                            width: designW,
                            height: designH,
                            child: child,
                          ),
                        ),
                      );
                    }
                    return ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        minWidth: 0,
                        minHeight: 0,
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        child: Transform.scale(
                          scale: scaleFit,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: designW,
                            height: designH,
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/* ------------------------ 디자인 ------------------------ */

class _DesignSurfaceRandom extends StatelessWidget {
  const _DesignSurfaceRandom({
    required this.seatMap,
    required this.studentsProvider,
    required this.cols,
    required this.rows,
    required this.assignedCount,
    required this.onMix,
    required this.onDrop,
  });

  final Map<String, String?> seatMap;
  final StudentsProvider studentsProvider;
  final int cols;
  final int rows;
  final int assignedCount;
  final VoidCallback onMix;
   final void Function(int fromSeat, String? fromSid, int toSeat, String? toSid) onDrop;
   
  String _seatKey(int index) => '${index + 1}';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: _kCardW,
        height: _kCardH,
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: _kCardBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 좌(총원/배치정보) • 중(Board) • 우(MIX)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: const HelpBadge(
                      tooltip: 'Select the space that will be left empty.',
                      placement: HelpPlacement.left, // 말풍선이 왼쪽으로 펼쳐지게
                      // gap: 2, // 네가 쓰는 HelpBadge가 gap 지원하면 켜줘서 더 가깝게
                      size: 32,
                    ),
                  ),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total $assignedCount',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$cols column / $rows row',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFD3FF6E),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Board',
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: onMix,
                        icon: const Icon(Icons.shuffle, size: 18),
                        label: const Text(
                          'MIX',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFFF96F1),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          fixedSize: const Size(106, 40),
                          backgroundColor: const Color(0x33FF96F1),
                          foregroundColor: const Color(0xFFFF96F1),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 좌석 그리드
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    const crossSpacing = 24.0;
                    const mainSpacing = 24.0;

                    final gridW = c.maxWidth;
                    final gridH = c.maxHeight - 2;
                    final tileW = (gridW - crossSpacing * (cols - 1)) / cols;
                    final tileH = (gridH - mainSpacing * (rows - 1)) / rows;
                    final ratio = (tileW / tileH).isFinite ? tileW / tileH : 1.0;

                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cols * rows,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: crossSpacing,
                        mainAxisSpacing: mainSpacing,
                        childAspectRatio: ratio,
                      ),
                      itemBuilder: (context, index) {
  final seatNo = index + 1; // 1-based
  final key = _seatKey(index);
  final sid = seatMap[key]?.trim();
  final hasStudent = sid != null && sid.isNotEmpty;
  final name = hasStudent ? studentsProvider.displayName(sid!) : null;

  final tile = _SeatTileLikeHome(
    index: index,
    hasStudent: hasStudent,
    name: name,
  );

  // 이 좌석 자체가 드롭 타겟
  return DragTarget<_DragSeatPayload>(
    onWillAccept: (payload) {
      if (payload == null) return false;
      // 같은 좌석으로 드롭 방지
      return payload.seatNo != seatNo;
    },
    onAccept: (payload) {
      onDrop(payload.seatNo, payload.sid, seatNo, sid);
    },
    builder: (context, candidate, rejected) {
      // 드롭 오버 시 살짝 하이라이트
      final highlight = candidate.isNotEmpty;
      final child = Container(
        decoration: highlight
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(blurRadius: 8, spreadRadius: 1, color: Color(0x22000000))],
              )
            : null,
        child: tile,
      );

      // 학생이 있는 좌석만 드래그 소스
      if (!hasStudent) return child;

      return Draggable<_DragSeatPayload>(
      data: _DragSeatPayload(seatNo: seatNo, sid: sid),
      dragAnchorStrategy: childDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        elevation: 6,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 90, maxWidth: 140),
          child: _DragGhost(name: name ?? 'Seat $seatNo'),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  },
);
},
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ========== 타일 ========== */
class _SeatTileLikeHome extends StatelessWidget {
  const _SeatTileLikeHome({
    required this.index,
    required this.hasStudent,
    required this.name,
  });

  final int index; // 0-based
  final bool hasStudent;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cc) {
        const baseH = 76.0;
        final s = (cc.maxHeight / baseH).clamp(0.6, 2.2);

        final radius = 12.0 * s;
        final padH = (6.0 * s).clamp(2.0, 10.0);
        final padV = (4.0 * s).clamp(1.0, 8.0);
        final fsSeat = (12.0 * s).clamp(9.0, 16.0);
        final fsName = (14.0 * s).clamp(10.0, 18.0);
        final gap = (2.0 * s).clamp(1.0, 8.0);

        final Color fillColor = hasStudent ? _kAttendedBlue : Colors.white;
        final isDark = fillColor.computeLuminance() < 0.5;
        final nameColor = isDark ? Colors.white : _kTextDark;
        final seatNoColor = isDark ? Colors.white70 : _kTextNum;

        final box = Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(radius),
            border: hasStudent ? Border.all(color: Colors.transparent) : null,
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: hasStudent
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${index + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fsSeat,
                          height: 1.0,
                          color: seatNoColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: gap),
                      Text(
                        name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fsName,
                          height: 1.0,
                          color: nameColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        );

        if (hasStudent) return box;

        return CustomPaint(
          foregroundPainter: _DashedBorderPainter(
            radius: radius + 4,
            color: _kAssignedDashed,
            strokeWidth: (2.0 * s).clamp(1.2, 3.0),
            dash: (8.0 * s).clamp(5.0, 12.0),
            gap: (6.0 * s).clamp(3.0, 10.0),
          ),
          child: box,
        );
      },
    );
  }
}

/* ---------- dashed painter ---------- */
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.radius,
    required this.color,
    this.strokeWidth = 1.0,
    this.dash = 6.0,
    this.gap = 4.0,
  });

  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = distance + dash > metric.length ? metric.length - distance : dash;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) {
    return radius != old.radius ||
        strokeWidth != old.strokeWidth ||
        dash != old.dash ||
        gap != old.gap ||
        color != old.color;
  }
}

class _SaveFabImage extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveFabImage({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: SafeArea(
        top: false,
        child: _MakeButton(
          imageAsset: 'assets/logo_bird_save.png',
          onTap: onTap,
          scale: 1.0,
          tooltip: 'Save seat layout (this card)',
        ),
      ),
    );
  }
}
class _ShowHideFab extends StatelessWidget {
  final bool show;
  final bool disabled;
  final VoidCallback onToggle;
  const _ShowHideFab({
    Key? key,
    required this.show,
    required this.onToggle,
    this.disabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 180,
      bottom: 20,
      child: SafeArea(
        top: false,
        child: _MakeButton(
          imageAsset: show
              ? 'assets/logo_bird_hide.png'
              : 'assets/logo_bird_show.png',
          onTap: onToggle,
          enabled: !disabled,
          scale: 1.0,
          tooltip: show ? 'Hide on display' : 'Show on display',
        ),
      ),
    );
  }
}

class _DragGhost extends StatelessWidget {
  final String name;
  const _DragGhost({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_indicator, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────
// 공통 Bird Button (Hover/Click Scale 애니메이션)
// ─────────────────────────────────────────────────────────────
class _MakeButton extends StatefulWidget {
  const _MakeButton({
    required this.imageAsset,
    required this.onTap,
    this.scale = 1.0,
    this.enabled = true,
    this.tooltip,
  });

  final String imageAsset;
  final VoidCallback onTap;
  final double scale;
  final bool enabled;
  final String? tooltip;

  @override
  State<_MakeButton> createState() => _MakeButtonState();
}

class _MakeButtonState extends State<_MakeButton> {
  bool _hover = false;
  bool _down = false;

  static const _baseW = 195.0;
  static const _baseH = 172.0;

  @override
  Widget build(BuildContext context) {
    final w = _baseW * widget.scale;
    final h = _baseH * widget.scale;
    final scaleAnim = _down
        ? 0.96
        : (_hover ? 1.05 : 1.0);

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.enabled) setState(() => _hover = true);
      },
      onExit: (_) {
        if (widget.enabled) setState(() => _hover = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enabled) setState(() => _down = true);
        },
        onTapUp: (_) {
          if (widget.enabled) setState(() => _down = false);
        },
        onTapCancel: () {
          if (widget.enabled) setState(() => _down = false);
        },
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: scaleAnim,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Opacity(
            opacity: widget.enabled ? 1.0 : 0.5,
            child: Tooltip(
              message: widget.tooltip ?? '',
              child: SizedBox(
                width: w,
                height: h,
                child: Image.asset(
                  widget.imageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.error, size: 48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
