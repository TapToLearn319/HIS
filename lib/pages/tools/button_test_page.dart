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

// ===== 테스트 단계 정의 =====
enum _StepKind { only1st, only2nd, first6Times, seq1121 }

String _headlineOf(_StepKind step) {
  switch (step) {
    case _StepKind.only1st:
      return 'Press the 1st Button';
    case _StepKind.only2nd:
      return 'Press the 2nd Button';
    case _StepKind.first6Times:
      return 'Press the 1st Button 6 Times';
    case _StepKind.seq1121:
      return 'Press the [1st - 1st - 2nd - 1st]';
  }
}

class ButtonTestPage extends StatefulWidget {
  const ButtonTestPage({super.key});
  @override
  State<ButtonTestPage> createState() => _ButtonTestPageState();
}

class _ButtonTestPageState extends State<ButtonTestPage> {
  _StepKind _step = _StepKind.only1st; // 시작 단계

  void _goNext() {
    setState(() {
      switch (_step) {
        case _StepKind.only1st:
          _step = _StepKind.only2nd;
          break;
        case _StepKind.only2nd:
          _step = _StepKind.first6Times;
          break;
        case _StepKind.first6Times:
          _step = _StepKind.seq1121;
          break;
        case _StepKind.seq1121:
          break;
      }
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
  bool _isStudentDoneForStep({
    required _StepKind step,
    required List<String> slotHistoryAsc, // '1','2' 시간 오름차순
  }) {
    switch (step) {
      case _StepKind.only1st:
        // 1을 1번이라도 누름
        return slotHistoryAsc.contains('1');
      case _StepKind.only2nd:
        // 2를 1번이라도 누름
        return slotHistoryAsc.contains('2');
      case _StepKind.first6Times:
        // 1을 6번 이상 누름 (전체 합산)
        final c1 = slotHistoryAsc.where((s) => s == '1').length;
        return c1 >= 6;
      case _StepKind.seq1121:
        // 마지막 4번이 [1,1,2,1]인지 확인
        if (slotHistoryAsc.length < 4) return false;
        final last4 = slotHistoryAsc.sublist(slotHistoryAsc.length - 4);
        const target = ['1', '1', '2', '1'];
        for (int i = 0; i < 4; i++) {
          if (last4[i] != target[i]) return false;
        }
        return true;
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
                    : _Body(sessionId: sessionId, step: _step, onNext: _goNext),
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
  });
  final String sessionId;
  final _StepKind step;
  final VoidCallback onNext;

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
      case _StepKind.only1st:
        return slotsAsc.contains('1');
      case _StepKind.only2nd:
        return slotsAsc.contains('2');
      case _StepKind.first6Times:
        return slotsAsc.where((s) => s == '1').length >= 6;
      case _StepKind.seq1121:
        if (slotsAsc.length < 4) return false;
        final last4 = slotsAsc.sublist(slotsAsc.length - 4);
        const target = ['1', '1', '2', '1'];
        for (int i = 0; i < 4; i++) {
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
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      fs
                          .collection('sessions/$sessionId/events')
                          .orderBy('ts', descending: false) // ↑ 오름차순으로 모으기 쉬움
                          .limit(1000)
                          .snapshots(),
                  builder: (context, evSnap) {
                    // 학생별 슬롯 히스토리(오름차순)
                    final Map<String, List<String>> slotsOf = {};
                    for (final d in (evSnap.data?.docs ?? const [])) {
                      final x = d.data();
                      final sid = (x['studentId'] as String?)?.trim();
                      if (sid == null || sid.isEmpty) continue;
                      final slot = _extractSlot(
                        x['slotIndex'],
                        triggerKey: x['triggerKey'],
                      );
                      if (slot != '1' && slot != '2') continue;
                      (slotsOf[sid] ??= []).add(slot!);
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

                    // 카드 레이아웃
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

                            final isLastStep = step == _StepKind.seq1121;

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
                                      // 상단: 날짜 • (가운데 지시문) • (우측 버튼 이미지 자리)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          // 날짜(요일+숫자)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                weekdayStr,
                                                style: _weekdayTextStyle,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                dateNumStr,
                                                style: _dateNumTextStyle,
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          // 가운데: 지시문 (Board 대신)
                                          Flexible(
                                            flex: 0,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minWidth:
                                                    320 * scale.clamp(0.7, 1.2),
                                                maxWidth:
                                                    544 * scale.clamp(0.7, 1.2),
                                                minHeight: 40,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  _headlineOf(step),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 36,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Align(
                                              alignment:
                                                  Alignment
                                                      .centerRight, // ← 오른쪽 끝으로 붙임
                                              child: InkWell(
                                                onTap: () {
                                                  if (isLastStep) {
                                                    Navigator.pushNamedAndRemoveUntil(
                                                      context,
                                                      '/tools',
                                                      (route) => false,
                                                    );
                                                  } else {
                                                    onNext();
                                                  }
                                                },
                                                child: SizedBox(
                                                  width: 400,
                                                  height: 120,
                                                  child: FittedBox(
                                                    fit: BoxFit.contain,
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

                                      // 좌석 그리드 (완료 여부에 따라 색상 변경)
                                      Expanded(
                                        child: _SeatGridTestUI(
                                          cols: cols,
                                          rows: rows,
                                          seatMap: seatMap,
                                          nameOf: nameOf,
                                          isDoneBuilder: (studentId) {
                                            final slotsAsc =
                                                slotsOf[studentId] ??
                                                const <String>[];
                                            return _doneForStep(step, slotsAsc);
                                          },
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
