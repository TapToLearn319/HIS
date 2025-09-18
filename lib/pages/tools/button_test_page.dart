// lib/pages/tools/button_test_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../sidebar_menu.dart';
import '../../provider/session_provider.dart';

const _kAppBg = Color(0xFFF6FAFF);
const _kCardW = 1011.0;
const _kCardH = 544.0;
const _kCardRadius = 10.0;
const _kCardBorder = Color(0xFFD2D2D2);

// 학생 카드 색상 (요구사항)
const _kSeatBase = Color(0xFFF6FAFF); // 기본
const _kSeatDone = Color(0xFFCEE6FF); // 단계 완료 시

const _kDateFontSize = 16.0;
const _kDateLineHeight = 34.0 / 16.0;
const _weekdayTextStyle = TextStyle(
  color: Colors.black,
  fontSize: _kDateFontSize,
  fontWeight: FontWeight.w400,
  height: _kDateLineHeight,
);
const _dateNumTextStyle = TextStyle(
  color: Colors.black,
  fontSize: _kDateFontSize,
  fontWeight: FontWeight.w400,
  height: _kDateLineHeight,
);

// ===== 테스트 단계 정의 ===== (1번 single, 2번 single, 1번 hold, 2번 hold, 1-2-1 single)
enum _StepKind { single1st, single2nd, hold1st, hold2nd, onetwoone }
String stepKey(_StepKind s) {
  switch (s) {
    case _StepKind.single1st: return 'single1st';
    case _StepKind.single2nd: return 'single2nd';
    case _StepKind.hold1st:   return 'hold1st';
    case _StepKind.hold2nd:   return 'hold2nd';
    case _StepKind.onetwoone: return 'onetwoone';
  }
}


String _headlineOf(_StepKind step) {
  switch (step) {
    case _StepKind.single1st:
      return 'Press the 1st Button shortly';
    case _StepKind.single2nd:
      return 'Press the 2nd Button shortly';
    case _StepKind.hold1st:
      return 'Press the 1st Button for more than 2 seconds';
    case _StepKind.hold2nd:
      return 'Press the 2nd Button for more than 2 seconds';
    case _StepKind.onetwoone:
      return 'Press the [1st - 2nd - 1st]';
  }
}

class ButtonTestPage extends StatefulWidget {
  const ButtonTestPage({super.key});
  @override
  State<ButtonTestPage> createState() => _ButtonTestPageState();
}

class _ButtonTestPageState extends State<ButtonTestPage> {
  _StepKind _step = _StepKind.single1st; // 시작 단계

  Future<void> _clearEventsForCurrentSession(BuildContext context) async {
    final sid = context.read<SessionProvider>().sessionId;
    if (sid == null) return;
    final fs = FirebaseFirestore.instance;

    const batchSize = 300;
    Query<Map<String, dynamic>> q = fs
        .collection('sessions/$sid/events')
        .limit(batchSize);

    while (true) {
      final snap = await q.get();
      if (snap.docs.isEmpty) break;
      final batch = fs.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) break;
    }
  }

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) return;
    await _clearEventsForCurrentSession(context);

    // 🔹 현재 단계도 Firestore에 반영해서 display와 초기에 맞춰줌
    final sid = context.read<SessionProvider>().sessionId;
    if (sid != null) {
      await FirebaseFirestore.instance.doc('sessions/$sid').set({
        'testStep': stepKey(_step),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Logs have been reset!')));
  });
}

  Future<void> _goNext() async {
  final sid = context.read<SessionProvider>().sessionId;
  if (sid == null) return;

  // 1) 다음 단계 계산
  _StepKind next;
  switch (_step) {
    case _StepKind.single1st: next = _StepKind.single2nd; break;
    case _StepKind.single2nd: next = _StepKind.hold1st;   break;
    case _StepKind.hold1st:   next = _StepKind.hold2nd;   break;
    case _StepKind.hold2nd:   next = _StepKind.onetwoone; break;
    case _StepKind.onetwoone: next = _StepKind.onetwoone; break; // 마지막은 유지
  }

  // 2) 이전 단계 로그 비우기(디스플레이에서 잘못 판정되는 것 방지)
  await _clearEventsForCurrentSession(context);

  // 3) Firestore에 다음 단계 올리기 → display가 즉시 반영
  await FirebaseFirestore.instance.doc('sessions/$sid').set({
    'testStep': stepKey(next),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  if (!mounted) return;

  // 4) 로컬 상태도 동기화
  setState(() {
    _step = next;
  });
}

  // Firestore 이벤트의 슬롯 추출 (Attendance 로직 재사용)
  String? _extractSlot(dynamic raw, {String? triggerKey}) {
    final s = raw?.toString().trim().toUpperCase();
    if (s == '1' || s == 'SLOT1' || s == 'S1' || s == 'LEFT') return '1';
    if (s == '2' || s == 'SLOT2' || s == 'S2' || s == 'RIGHT') return '2';
    final t = triggerKey?.toString().trim().toUpperCase();
    if (t?.startsWith('S1_') == true) return '1';
    if (t?.startsWith('S2_') == true) return '2';
    return null;
  }

  // 현재 단계 완료 여부 계산
  // eventsAsc: 오래된 → 최신 순서의 (slot, action) 목록
  // slot: '1' | '2', action: 'single' | 'hold'
  bool _isStudentDoneForStep({
    required _StepKind step,
    required List<({String slot, String action})> eventsAsc,
  }) {
    switch (step) {
      case _StepKind.single1st:
        // 슬롯 1 + single 1회 이상
        return eventsAsc.any((e) => e.slot == '1' && e.action == 'single');

      case _StepKind.single2nd:
        // 슬롯 2 + single 1회 이상
        return eventsAsc.any((e) => e.slot == '2' && e.action == 'single');

      case _StepKind.hold1st:
        // 슬롯 1 + hold 1회 이상
        return eventsAsc.any((e) => e.slot == '1' && e.action == 'hold');

      case _StepKind.hold2nd:
        // 슬롯 2 + hold 1회 이상
        return eventsAsc.any((e) => e.slot == '2' && e.action == 'hold');

      case _StepKind.onetwoone:
        // single 이벤트만 추려서 "마지막 3개"가 [1,2,1]인지 확인
        final singles = <String>[];
        for (final e in eventsAsc) {
          if (e.action == 'single') singles.add(e.slot);
        }
        if (singles.length < 3) return false;
        final last3 = singles.sublist(singles.length - 3);
        return last3[0] == '1' && last3[1] == '2' && last3[2] == '1';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = context.watch<SessionProvider>().sessionId;

    return AppScaffold(
      selectedIndex: 2,
      body: Scaffold(
        backgroundColor: _kAppBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child:
                sessionId == null
                    ? const Center(
                      child: Text('No session. Open "Session" and select one.'),
                    )
                    : _Body(
                      sessionId: sessionId,
                      step: _step,
                      onNext: _goNext,
                      onReset: () => _clearEventsForCurrentSession(context),
                    ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.sessionId,
    required this.step,
    required this.onNext,
    required this.onReset,
  });

  final String sessionId;
  final _StepKind step;
  final Future<void> Function() onNext;
  final Future<void> Function() onReset;

  // Firestore 슬롯 파서 (Stateless에 복사)
  String? _extractSlot(dynamic raw, {String? triggerKey}) {
    final s = raw?.toString().trim().toUpperCase();
    if (s == '1' || s == 'SLOT1' || s == 'S1' || s == 'LEFT') return '1';
    if (s == '2' || s == 'SLOT2' || s == 'S2' || s == 'RIGHT') return '2';
    final t = triggerKey?.toString().trim().toUpperCase();
    if (t?.startsWith('S1_') == true) return '1';
    if (t?.startsWith('S2_') == true) return '2';
    return null;
  }

  bool _doneForStep(_StepKind step, List<String> slotsAsc) {
    switch (step) {
      case _StepKind.single1st:
        return slotsAsc.contains('1');
      case _StepKind.single2nd:
        return slotsAsc.contains('2');
      case _StepKind.hold1st:
        return slotsAsc.where((s) => s == '1').length >= 6;
      case _StepKind.hold2nd:
      case _StepKind.onetwoone:
        if (slotsAsc.length < 3) return false;
        final last4 = slotsAsc.sublist(slotsAsc.length - 3);
        const target = ['1', '2', '1'];
        for (int i = 0; i < 3; i++) {
          if (last4[i] != target[i]) return false;
        }
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    // 세션 메타(좌석 수)
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fs.doc('sessions/$sessionId').snapshots(),
      builder: (context, sessSnap) {
        final meta = sessSnap.data?.data() ?? const {};
        final int cols = (meta['cols'] as num?)?.toInt() ?? 6;
        final int rows = (meta['rows'] as num?)?.toInt() ?? 4;

        // 좌석 맵
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fs.collection('sessions/$sessionId/seatMap').snapshots(),
          builder: (context, seatSnap) {
            final Map<String, String?> seatMap = {};
            for (final d in (seatSnap.data?.docs ?? const [])) {
              seatMap[d.id] = (d.data()['studentId'] as String?)?.trim();
            }

            // 학생 이름
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: fs.collection('students').snapshots(),
              builder: (context, stuSnap) {
                final Map<String, String> nameOf = {};
                for (final d in (stuSnap.data?.docs ?? const [])) {
                  final n = (d.data()['name'] as String?)?.trim();
                  if (n != null && n.isNotEmpty) nameOf[d.id] = n;
                }

                // 이벤트(슬롯 히스토리 만들기)
                // 이벤트(슬롯 히스토리 만들기)
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      fs
                          .collection('sessions/$sessionId/events')
                          .orderBy('ts', descending: false) // 오래된 → 최신
                          .limit(1000)
                          .snapshots(),
                  builder: (context, evSnap) {
                    // slot: '1'|'2', action: 'single'|'hold'
                    (String slot, String action)? parseSlotAction(
                      Map<String, dynamic> x,
                    ) {
                      // 1) 슬롯 추출
                      String? slot;
                      final s = x['slotIndex']?.toString().trim().toUpperCase();
                      if (s == '1' || s == 'SLOT1' || s == 'S1' || s == 'LEFT')
                        slot = '1';
                      if (s == '2' || s == 'SLOT2' || s == 'S2' || s == 'RIGHT')
                        slot = '2';

                      // 2) 액션 추출: clickType 최우선, 없으면 보조 키워드/시간
                      String act = 'single'; // 기본값

                      final clickType =
                          x['clickType']?.toString().trim().toLowerCase();
                      if (clickType != null) {
                        if (clickType == 'hold' ||
                            clickType == 'long' ||
                            clickType == 'long_press') {
                          act = 'hold';
                        } else if (clickType == 'click' ||
                            clickType == 'single' ||
                            clickType == 'short') {
                          act = 'single';
                        }
                      } else {
                        // 보조 신호들 (혹시 다른 필드로 들어오는 경우 대비)
                        final trig =
                            x['triggerKey']?.toString().trim().toLowerCase();
                        final actionStr =
                            x['action']?.toString().trim().toLowerCase();
                        final gestureStr =
                            x['gesture']?.toString().trim().toLowerCase();
                        final typeStr =
                            x['type']?.toString().trim().toLowerCase();
                        final combined = [
                          trig,
                          actionStr,
                          gestureStr,
                          typeStr,
                        ].where((e) => e != null && e.isNotEmpty).join('|');

                        if (combined.contains('hold') ||
                            combined.contains('long') ||
                            combined.contains('long_press') ||
                            combined.contains('longpress') ||
                            combined.contains('press_and_hold') ||
                            combined.contains('lp')) {
                          act = 'hold';
                        } else {
                          // 시간 기반: 1.8s 이상이면 hold 간주
                          num? durationMs = x['durationMs'] as num?;
                          durationMs ??= x['pressMs'] as num?;
                          durationMs ??= x['holdMs'] as num?;
                          if (durationMs != null && durationMs >= 1800) {
                            act = 'hold';
                          }
                        }
                      }

                      if (slot == '1' || slot == '2') return (slot!, act);
                      return null;
                    }

                    // ----- 2) 학생별 달성 상태 집계 -----
                    // single/hold 각각 슬롯별 달성 여부
                    final hasSingle1 = <String, bool>{};
                    final hasSingle2 = <String, bool>{};
                    final hasHold1 = <String, bool>{};
                    final hasHold2 = <String, bool>{};

                    // onetwoone(1-2-1) 판정용: single 이벤트만 모은 순차 슬롯 목록
                    final singlesSeqOf = <String, List<String>>{};

                    for (final d in (evSnap.data?.docs ?? const [])) {
                      final x = d.data();
                      final sid = (x['studentId'] as String?)?.trim();
                      if (sid == null || sid.isEmpty) continue;

                      final parsed = parseSlotAction(x); // ✅ x 전체 Map 전달
                      if (parsed == null) continue;
                      final slot = parsed.$1;
                      final action = parsed.$2;

                      // 달성 플래그
                      if (action == 'single') {
                        if (slot == '1') hasSingle1[sid] = true;
                        if (slot == '2') hasSingle2[sid] = true;
                        // onetwoone 시퀀스용으로 single만 누적
                        (singlesSeqOf[sid] ??= []).add(slot);
                      } else if (action == 'hold') {
                        if (slot == '1') hasHold1[sid] = true;
                        if (slot == '2') hasHold2[sid] = true;
                      }
                    }

                    bool isDone(String studentId) {
                      switch (step) {
                        case _StepKind.single1st:
                          return hasSingle1[studentId] == true;
                        case _StepKind.single2nd:
                          return hasSingle2[studentId] == true;
                        case _StepKind.hold1st:
                          return hasHold1[studentId] ==
                              true; // ← Hold(슬롯1) 1회 이상
                        case _StepKind.hold2nd:
                          return hasHold2[studentId] ==
                              true; // ← Hold(슬롯2) 1회 이상
                        case _StepKind.onetwoone:
                          final seq =
                              singlesSeqOf[studentId] ?? const <String>[];
                          if (seq.length < 3) return false;
                          final last3 = seq.sublist(seq.length - 3);
                          return last3[0] == '1' &&
                              last3[1] == '2' &&
                              last3[2] == '1';
                      }
                    }

                    // 상단 날짜
                    final now = DateTime.now();
                    final weekdayStr =
                        const [
                          'SUN',
                          'MON',
                          'TUE',
                          'WED',
                          'THU',
                          'FRI',
                          'SAT',
                        ][now.weekday % 7];
                    final dateNumStr =
                        '${now.month.toString().padLeft(2, "0")}.${now.day.toString().padLeft(2, "0")}';

                    // 카드 레이아웃 (기존 그대로, isDoneBuilder만 변경)
                    return Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.9,
                        heightFactor: 0.9,
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final scaleW = c.maxWidth / _kCardW;
                            final scaleH = c.maxHeight / _kCardH;
                            final scale = (scaleW < scaleH) ? scaleW : scaleH;

                            final cardW = _kCardW * scale;
                            final cardH = _kCardH * scale;
                            final padH = 28.0 * scale;
                            final padV = 24.0 * scale;

                            final isLastStep = step == _StepKind.onetwoone;

                            return Center(
                              child: SizedBox(
                                width: cardW,
                                height: cardH,
                                child: Container(
                                  padding: EdgeInsets.fromLTRB(
                                    padH,
                                    padV,
                                    padH,
                                    padV,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      _kCardRadius,
                                    ),
                                    border: Border.all(
                                      color: _kCardBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // --- 상단 바 (기존 코드 유지) ---
                                      Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    // 날짜(좌) — 필요한 만큼만 차지
    Flexible(
      flex: 0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(weekdayStr, style: _weekdayTextStyle),
          const SizedBox(width: 8),
          Text(dateNumStr, style: _dateNumTextStyle),
        ],
      ),
    ),

    const SizedBox(width: 8),

    // 안내 문구(가운데) — 좁아지면 … 으로 잘림
    Expanded(
      child: Center(
        child: Text(
          _headlineOf(step),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
    ),

    const SizedBox(width: 8),

    // Next 이미지(우) — 가용 공간에 맞춰 축소, 비율 유지
    Flexible(
      flex: 0,
      child: InkWell(
        onTap: () async {
          if (isLastStep) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/tools',
              (route) => false,
            );
          } else {
            await onNext();
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            // 디자인 최대치만 지정 (필요 시 더 작아질 수 있음)
            maxWidth: 400,
            maxHeight: 120,
          ),
          child: AspectRatio(
            aspectRatio: 400 / 120, // 원본 비율 유지
            child: FittedBox(
              fit: BoxFit.contain,   // 공간에 맞춰 축소/확대
              child: Image.asset(
                isLastStep
                  ? 'assets/test/logo_bird_done.png'
                  : 'assets/test/logo_bird_next.png',
              ),
            ),
          ),
        ),
      ),
    ),
  ],
),
                                      SizedBox(
                                        height: (24.0 * scale).clamp(
                                          12.0,
                                          28.0,
                                        ),
                                      ),

                                      // 좌석 그리드: 완료 여부는 isDone(studentId)로 판정
                                      Expanded(
                                        child: _SeatGridTestUI(
                                          cols: cols,
                                          rows: rows,
                                          seatMap: seatMap,
                                          nameOf: nameOf,
                                          isDoneBuilder:
                                              (studentId) => isDone(studentId),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
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

/// 좌석 그리드: 현재 단계 완료 여부에 따라 색상 변경 (#F6FAFF → #CEE6FF)
class _SeatGridTestUI extends StatelessWidget {
  const _SeatGridTestUI({
    required this.cols,
    required this.rows,
    required this.seatMap,
    required this.nameOf,
    required this.isDoneBuilder,
  });

  final int cols;
  final int rows;
  final Map<String, String?> seatMap; // seatNo -> studentId?
  final Map<String, String> nameOf; // studentId -> name
  final bool Function(String studentId) isDoneBuilder;

  String _seatKey(int index) => '${index + 1}';

  @override
  Widget build(BuildContext context) {
    final seatCount = cols * rows;

    return LayoutBuilder(
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
          itemCount: seatCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: crossSpacing,
            mainAxisSpacing: mainSpacing,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) {
            final seatNo = _seatKey(index);
            final studentId = seatMap[seatNo]?.trim();
            final hasStudent = (studentId != null && studentId.isNotEmpty);
            final name = hasStudent ? (nameOf[studentId] ?? studentId) : null;

            final fillColor =
                hasStudent && isDoneBuilder(studentId!)
                    ? _kSeatDone
                    : _kSeatBase;

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

                return Container(
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: Colors.transparent),
                  ),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: padH,
                    vertical: padV,
                  ),
                  child:
                      hasStudent
                          ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  seatNo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: fsSeat,
                                    height: 1.0,
                                    color: const Color(0xFF1F2937),
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
                                    color: const Color(0xFF0B1324),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : const SizedBox.shrink(),
                );
              },
            );
          },
        );
      },
    );
  }
}
