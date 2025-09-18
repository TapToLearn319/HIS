// lib/pages/tools/button_test_display_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String kHubId = 'hub-001';

// ===== 카드/스타일 상수 (ButtonTestPage와 톤을 맞춤) =====
const _kAppBg = Color(0xFFF6FAFF);
const _kCardW = 1011.0;
const _kCardH = 544.0;
const _kCardRadius = 10.0;
const _kCardBorder = Color(0xFFD2D2D2);

// 학생 카드 색
const _kSeatBase = Color(0xFFF6FAFF); // 기본
const _kSeatDone = Color(0xFFCEE6FF); // 단계 완료 시

// 날짜 폰트
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
enum _StepKind { single1st, single2nd, hold1st, hold2nd, onetwoone }

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

_StepKind _parseStep(dynamic raw) {
  final s = raw?.toString().trim().toLowerCase();
  switch (s) {
    case 'single2nd':
      return _StepKind.single2nd;
    case 'hold1st':
      return _StepKind.hold1st;
    case 'hold2nd':
      return _StepKind.hold2nd;
    case 'onetwoone':
      return _StepKind.onetwoone;
    case 'single1st':
    default:
      return _StepKind.single1st;
  }
}

class ButtonTestDisplayPage extends StatelessWidget {
  const ButtonTestDisplayPage({super.key});

  // 이벤트에서 (slot, action) 추출: slot '1'|'2', action 'single'|'hold'
  (String slot, String action)? _parseSlotAction(Map<String, dynamic> x) {
    // 1) 슬롯
    String? slot;
    final s = x['slotIndex']?.toString().trim().toUpperCase();
    if (s == '1' || s == 'SLOT1' || s == 'S1' || s == 'LEFT') slot = '1';
    if (s == '2' || s == 'SLOT2' || s == 'S2' || s == 'RIGHT') slot = '2';

    // 2) 액션
    String act = 'single';
    final clickType = x['clickType']?.toString().trim().toLowerCase();
    if (clickType != null) {
      if (clickType == 'hold' || clickType == 'long' || clickType == 'long_press') {
        act = 'hold';
      } else if (clickType == 'click' || clickType == 'single' || clickType == 'short') {
        act = 'single';
      }
    } else {
      final trig = x['triggerKey']?.toString().trim().toLowerCase();
      final actionStr = x['action']?.toString().trim().toLowerCase();
      final gestureStr = x['gesture']?.toString().trim().toLowerCase();
      final typeStr = x['type']?.toString().trim().toLowerCase();
      final combined = [
        trig,
        actionStr,
        gestureStr,
        typeStr,
      ].where((e) => e != null && e!.isNotEmpty).join('|');

      if (combined.contains('hold') ||
          combined.contains('long') ||
          combined.contains('long_press') ||
          combined.contains('longpress') ||
          combined.contains('press_and_hold') ||
          combined.contains('lp')) {
        act = 'hold';
      } else {
        num? durationMs = x['durationMs'] as num?;
        durationMs ??= x['pressMs'] as num?;
        durationMs ??= x['holdMs'] as num?;
        if (durationMs != null && durationMs >= 1800) act = 'hold';
      }
    }

    if (slot == '1' || slot == '2') return (slot!, act);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    // 허브 -> 현재 세션
    final hubStream = fs.doc('hubs/$kHubId').snapshots();

    return Scaffold(
      backgroundColor: _kAppBg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: hubStream,
          builder: (context, hubSnap) {
            if (hubSnap.connectionState == ConnectionState.waiting) {
              return const _WaitingSeatScreen();
            }
            final hub = hubSnap.data?.data();
            final sid = hub?['currentSessionId'] as String?;
            if (sid == null || sid.isEmpty) return const _WaitingSeatScreen();

            // 세션 메타(행/열, testStep), 좌석, 학생, 이벤트
            final sessionMeta = fs.doc('sessions/$sid').snapshots();
            final seatMapStream = fs.collection('sessions/$sid/seatMap').snapshots();
            final eventsStream = fs
                .collection('sessions/$sid/events')
                .orderBy('ts', descending: false) // 오래된 → 최신
                .limit(1000)
                .snapshots();
            final studentsStream = fs.collection('students').snapshots();

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: sessionMeta,
              builder: (context, sessSnap) {
                final meta = sessSnap.data?.data() ?? const {};
                final int cols = (meta['cols'] as num?)?.toInt() ?? 6;
                final int rows = (meta['rows'] as num?)?.toInt() ?? 4;
                final _StepKind step = _parseStep(meta['testStep']); // 없으면 single1st

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: seatMapStream,
                  builder: (context, seatSnap) {
                    final Map<String, String?> seatMap = {};
                    for (final d in (seatSnap.data?.docs ?? const [])) {
                      seatMap[d.id] = (d.data()['studentId'] as String?)?.trim();
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: studentsStream,
                      builder: (context, stuSnap) {
                        final Map<String, String> nameOf = {};
                        for (final d in (stuSnap.data?.docs ?? const [])) {
                          final n = (d.data()['name'] as String?)?.trim();
                          if (n != null && n.isNotEmpty) nameOf[d.id] = n;
                        }

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: eventsStream,
                          builder: (context, evSnap) {
                            // 달성 플래그
                            final hasSingle1 = <String, bool>{};
                            final hasSingle2 = <String, bool>{};
                            final hasHold1 = <String, bool>{};
                            final hasHold2 = <String, bool>{};
                            final singlesSeqOf = <String, List<String>>{};

                            for (final d in (evSnap.data?.docs ?? const [])) {
                              final x = d.data();
                              final sidStu = (x['studentId'] as String?)?.trim();
                              if (sidStu == null || sidStu.isEmpty) continue;
                              final parsed = _parseSlotAction(x);
                              if (parsed == null) continue;
                              final slot = parsed.$1;
                              final action = parsed.$2;

                              if (action == 'single') {
                                if (slot == '1') hasSingle1[sidStu] = true;
                                if (slot == '2') hasSingle2[sidStu] = true;
                                (singlesSeqOf[sidStu] ??= []).add(slot);
                              } else if (action == 'hold') {
                                if (slot == '1') hasHold1[sidStu] = true;
                                if (slot == '2') hasHold2[sidStu] = true;
                              }
                            }

                            bool isDone(String studentId) {
                              switch (step) {
                                case _StepKind.single1st:
                                  return hasSingle1[studentId] == true;
                                case _StepKind.single2nd:
                                  return hasSingle2[studentId] == true;
                                case _StepKind.hold1st:
                                  return hasHold1[studentId] == true;
                                case _StepKind.hold2nd:
                                  return hasHold2[studentId] == true;
                                case _StepKind.onetwoone:
                                  final seq = singlesSeqOf[studentId] ?? const <String>[];
                                  if (seq.length < 3) return false;
                                  final last3 = seq.sublist(seq.length - 3);
                                  return last3[0] == '1' && last3[1] == '2' && last3[2] == '1';
                              }
                            }

                            // 날짜 표기
                            final now = DateTime.now();
                            final weekdayStr = const ['SUN','MON','TUE','WED','THU','FRI','SAT'][now.weekday % 7];
                            final dateNumStr =
                                '${now.month.toString().padLeft(2, "0")}.${now.day.toString().padLeft(2, "0")}';

                            // 카드 + 그리드 (Next 이미지 없음, 사이드바 없음)
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

                                    return SizedBox(
                                      width: cardW,
                                      height: cardH,
                                      child: Container(
                                        padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(_kCardRadius),
                                          border: Border.all(color: _kCardBorder, width: 1),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // 상단: 날짜 + 현재 단계 안내(Next 이미지 제거)
                                            Row(
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(weekdayStr, style: _weekdayTextStyle),
                                                    const SizedBox(width: 8),
                                                    Text(dateNumStr, style: _dateNumTextStyle),
                                                  ],
                                                ),
                                                const SizedBox(width: 8),
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
                                              ],
                                            ),
                                            SizedBox(height: (24.0 * scale).clamp(12.0, 28.0)),

                                            // 좌석 그리드
                                            Expanded(
                                              child: _SeatGridTestUI(
                                                cols: cols,
                                                rows: rows,
                                                seatMap: seatMap,
                                                nameOf: nameOf,
                                                isDoneBuilder: isDone,
                                              ),
                                            ),
                                          ],
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
          },
        ),
      ),
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
                  padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                  child: hasStudent
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

/* --------------------- Waiting Screen ---------------------- */
class _WaitingSeatScreen extends StatelessWidget {
  const _WaitingSeatScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kAppBg,
      width: double.infinity,
      height: double.infinity,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_seat, size: 100, color: Colors.black38),
            SizedBox(height: 20),
            Text(
              '세션을 준비 중입니다…',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
