// lib/pages/tools/button_test_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../sidebar_menu.dart';
import '../../provider/session_provider.dart';

const String kHubId = 'hub-001'; // ✅ 허브 스코프

const _kAppBg = Color(0xFFF6FAFF);
const _kCardW = 1011.0;
const _kCardH = 544.0;
const _kCardRadius = 10.0;
const _kCardBorder = Color(0xFFD2D2D2);

// 학생 카드 색상
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
enum _StepKind { single1st, single2nd, hold1st, hold2nd }
String stepKey(_StepKind s) {
  switch (s) {
    case _StepKind.single1st:
      return 'single1st';
    case _StepKind.single2nd:
      return 'single2nd';
    case _StepKind.hold1st:
      return 'hold1st';
    case _StepKind.hold2nd:
      return 'hold2nd';
    // case _StepKind.onetwoone:
    //   return 'onetwoone';
  }
}

String _headlineOf(_StepKind step) {
  switch (step) {
    case _StepKind.single1st:
      return 'Press the Green Button shortly';
    case _StepKind.single2nd:
      return 'Press the Purple Button shortly';
    case _StepKind.hold1st:
      return 'Press the Green Button for more than 2 seconds';
    case _StepKind.hold2nd:
      return 'Press the Purple Button for more than 2 seconds';
    // case _StepKind.onetwoone:
    //   return 'Press the [1st - 2nd - 1st]';
  }
}

class ButtonTestPage extends StatefulWidget {
  const ButtonTestPage({super.key});
  @override
  State<ButtonTestPage> createState() => _ButtonTestPageState();
}

class _ButtonTestPageState extends State<ButtonTestPage> {
  _StepKind _step = _StepKind.single1st; // 시작 단계
  static const int kHoldThresholdMs = 1800;

  // 현재 단계의 기준 타임스탬프(ms) — Next 누를 때마다 갱신
  int? _sinceMs;

  @override
  void initState() {
    super.initState();
    // 페이지 진입 직후: 현재 단계와 기준 ts를 세션에 기록
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final sid = context.read<SessionProvider>().sessionId;
      if (sid == null) return;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      _sinceMs = nowMs;

      await FirebaseFirestore.instance.doc('hubs/$kHubId/sessions/$sid').set(
        {
          'testStep': stepKey(_step),
          'testSinceMs': nowMs, // 🔹 이 시각 이후 이벤트만 카운트
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Started button test (timestamp set).')),
      );
    });
  }

  Future<void> _goNext() async {
    final sid = context.read<SessionProvider>().sessionId;
    if (sid == null) return;

    // 1) 다음 단계 계산
    _StepKind next;
    switch (_step) {
      case _StepKind.single1st:
        next = _StepKind.single2nd;
        break;
      case _StepKind.single2nd:
        next = _StepKind.hold1st;
        break;
      case _StepKind.hold1st:
        next = _StepKind.hold2nd;
        break;
      case _StepKind.hold2nd:
        next = _StepKind.hold2nd;
        break;
      // case _StepKind.onetwoone:
      //   next = _StepKind.onetwoone; // 마지막은 유지
      //   break;
    }

    // 2) 이벤트 삭제 대신, 기준 ts 를 현재로 갱신
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _sinceMs = nowMs;

    // 3) Firestore에 다음 단계 + 기준 ts 올리기 → display/presenter가 동일 판단
    await FirebaseFirestore.instance.doc('hubs/$kHubId/sessions/$sid').set(
      {
        'testStep': stepKey(next),
        'testSinceMs': nowMs, // 🔹 Next 시점 이후로만 판정
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

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
  bool _isStudentDoneForStep({
    required _StepKind step,
    required List<({String slot, String action})> eventsAsc,
  }) {
    switch (step) {
      case _StepKind.single1st:
        return eventsAsc.any((e) => e.slot == '1' && e.action == 'single');
      case _StepKind.single2nd:
        return eventsAsc.any((e) => e.slot == '2' && e.action == 'single');
      case _StepKind.hold1st:
        return eventsAsc.any((e) => e.slot == '1' && e.action == 'hold');
      case _StepKind.hold2nd:
        return eventsAsc.any((e) => e.slot == '2' && e.action == 'hold');
      // case _StepKind.onetwoone:
      //   final singles = <String>[];
      //   for (final e in eventsAsc) {
      //     if (e.action == 'single') singles.add(e.slot);
      //   }
      //   if (singles.length < 3) return false;
      //   final last3 = singles.sublist(singles.length - 3);
      //   return last3[0] == '1' && last3[1] == '2' && last3[2] == '1';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = context.watch<SessionProvider>().sessionId;

    return AppScaffold(
      selectedIndex: 0,
      body: Scaffold(
        appBar: AppBar(
                  elevation: 0,
                  backgroundColor: const Color(0xFFF6FAFF),
                  leading: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
        backgroundColor: _kAppBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: sessionId == null
                ? const Center(
                    child: Text('No session. Open "Session" and select one.'),
                  )
                : _Body(
                    sessionId: sessionId,
                    step: _step,
                    holdThresholdMs: kHoldThresholdMs,
                    onNext: _goNext,
                    // 로그 초기화 제거 → 더이상 사용하지 않지만 인터페이스는 유지
                    onReset: () async {},
                    extractSlot: _extractSlot,
                    isStudentDoneForStep: _isStudentDoneForStep,
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
    required this.holdThresholdMs,
    required this.onNext,
    required this.onReset,
    required this.extractSlot,
    required this.isStudentDoneForStep,
  });

  final String sessionId;
  final _StepKind step;
  final int holdThresholdMs;
  final Future<void> Function() onNext;
  final Future<void> Function() onReset;

  // 주입: 상위 state의 슬롯/판정 함수(코드 구조는 그대로 유지)
  final String? Function(dynamic raw, {String? triggerKey}) extractSlot;
  final bool Function({
    required _StepKind step,
    required List<({String slot, String action})> eventsAsc,
  }) isStudentDoneForStep;

  // live/event 공통 타임스탬프 파싱
  int _eventMs(Map<String, dynamic> x) {
    final ts = x['ts'];
    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
    final hubTs = (x['hubTs'] as num?)?.toInt();
    if (hubTs != null && hubTs > 0) return hubTs;
    final ms = (x['ms'] as num?)?.toInt() ?? (x['lastMs'] as num?)?.toInt();
    if (ms != null && ms > 0) return ms;
    final upd = x['updatedAt'];
    if (upd is Timestamp) return upd.millisecondsSinceEpoch;
    return 0;
  }

  // 클릭 액션 파싱
  (String slot, String action, int ms)? _parseSlotAction(
      Map<String, dynamic> x) {
    // 1) 슬롯
    final slot = extractSlot(x['slotIndex'], triggerKey: x['triggerKey']);
    if (slot != '1' && slot != '2') return null;

    // 2) 액션
    String action = 'single';
    final clickType = x['clickType']?.toString().trim().toLowerCase();
    if (clickType != null) {
      if (clickType == 'hold' ||
          clickType == 'long' ||
          clickType == 'long_press') {
        action = 'hold';
      } else if (clickType == 'click' ||
          clickType == 'single' ||
          clickType == 'short') {
        action = 'single';
      }
    } else {
      final trig = x['triggerKey']?.toString().trim().toLowerCase();
      final actionStr = x['action']?.toString().trim().toLowerCase();
      final gestureStr = x['gesture']?.toString().trim().toLowerCase();
      final typeStr = x['type']?.toString().trim().toLowerCase();
      final combined = [trig, actionStr, gestureStr, typeStr]
          .where((e) => e != null && e.isNotEmpty)
          .join('|');
      if (combined.contains('hold') ||
          combined.contains('long') ||
          combined.contains('long_press') ||
          combined.contains('longpress') ||
          combined.contains('press_and_hold') ||
          combined.contains('lp')) {
        action = 'hold';
      } else {
        num? durationMs = x['durationMs'] as num?;
        durationMs ??= x['pressMs'] as num?;
        durationMs ??= x['holdMs'] as num?;
        if (durationMs != null && durationMs >= holdThresholdMs) {
          action = 'hold';
        }
      }
    }

    final ms = _eventMs(x);
    return (slot!, action, ms);
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    // 세션 메타(좌석 수, testSinceMs, testStep)
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fs.doc('hubs/$kHubId/sessions/$sessionId').snapshots(), // ✅ 허브 스코프
      builder: (context, sessSnap) {
        final meta = sessSnap.data?.data() ?? const {};
        final int cols = (meta['cols'] as num?)?.toInt() ?? 6;
        final int rows = (meta['rows'] as num?)?.toInt() ?? 4;

        // 🔹 이 시각 이후의 버튼만 인정
        final int sinceMs = (meta['testSinceMs'] as num?)?.toInt() ?? 0;

        // 좌석 맵
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fs
              .collection('hubs/$kHubId/sessions/$sessionId/seatMap') // ✅ 허브 스코프
              .snapshots(),
          builder: (context, seatSnap) {
            final Map<String, String?> seatMap = {};
            for (final d in (seatSnap.data?.docs ?? const [])) {
              seatMap[d.id] = (d.data()['studentId'] as String?)?.trim();
            }

            // 학생 이름 (허브 스코프)
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: fs.collection('hubs/$kHubId/students').snapshots(), // ✅ 허브 스코프
              builder: (context, stuSnap) {
                final Map<String, String> nameOf = {};
                for (final d in (stuSnap.data?.docs ?? const [])) {
                  final n = (d.data()['name'] as String?)?.trim();
                  if (n != null && n.isNotEmpty) nameOf[d.id] = n;
                }

                // ✅ events → devices + liveByDevice (sinceMs 이후만 사용)
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: fs.collection('hubs/$kHubId/devices').snapshots(),
                  builder: (context, devSnap) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: fs
                          .collection('hubs/$kHubId/liveByDevice')
                          .snapshots(),
                      builder: (context, liveSnap) {
                        // ---- liveByDevice 맵 구성 ----
                        final Map<String, Map<String, dynamic>> liveByDevice = {};
                        for (final d in (liveSnap.data?.docs ?? const [])) {
                          liveByDevice[d.id] = d.data();
                        }

                        // ---- 학생별 이벤트(오래된→최신) 합성 ----
                        final Map<String, List<({String slot, String action, int ms})>>
                            eventsAscOf = {};

                        for (final d in (devSnap.data?.docs ?? const [])) {
                          final devId = d.id;
                          final dev = d.data();
                          final sid = (dev['studentId'] as String?)?.trim();
                          if (sid == null || sid.isEmpty) continue;

                          final live = liveByDevice[devId];
                          if (live == null) continue;

                          List<Map<String, dynamic>> candidates = [];

                          // 1) 히스토리/최근 배열이 있는 경우 우선 사용
                          for (final key in const [
                            'history',
                            'events',
                            'recent',
                            'logs',
                            'sequence',
                            'lastEvents',
                          ]) {
                            final v = live[key];
                            if (v is List) {
                              for (final e in v) {
                                if (e is Map<String, dynamic>) {
                                  candidates.add(e);
                                } else if (e is Map) {
                                  candidates.add(Map<String, dynamic>.from(e));
                                } else if (e is String) {
                                  // 문자열만 있는 경우: 'S1','S2','1','2' → single 가정
                                  final m = <String, dynamic>{
                                    'slotIndex': e,
                                    'clickType': 'single'
                                  };
                                  candidates.add(m);
                                }
                              }
                            }
                          }

                          // 2) 배열이 없으면 루트 필드로 "마지막 1건"만 처리
                          if (candidates.isEmpty) {
                            candidates = [live];
                          }

                          // 파싱 + 시간 필터 (sinceMs 이후만)
                          final parsed = <({String slot, String action, int ms})>[];
                          for (final one in candidates) {
                            final p = _parseSlotAction(one);
                            if (p == null) continue;
                            if (sinceMs > 0 && p.$3 < sinceMs) continue; // 🔹 필터
                            parsed.add((slot: p.$1, action: p.$2, ms: p.$3));
                          }

                          if (parsed.isEmpty) continue;

                          // 시간순 정렬 후 학생별 누적
                          parsed.sort((a, b) => a.ms.compareTo(b.ms));
                          final list = (eventsAscOf[sid] ??= []);
                          list.addAll(parsed);
                        }

                        bool isDone(String studentId) {
                          final seq = eventsAscOf[studentId]
                                  ?.map((e) => (slot: e.slot, action: e.action))
                                  .toList() ??
                              const <({String slot, String action})>[];
                          return isStudentDoneForStep(
                              step: step, eventsAsc: seq);
                        }

                        // 상단 날짜
                        final now = DateTime.now();
                        final weekdayStr = const [
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

                        // 카드 레이아웃 (원본 유지)
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

                                final isLastStep = step == _StepKind.hold2nd;

                                return Center(
                                  child: SizedBox(
                                    width: cardW,
                                    height: cardH,
                                    child: Container(
                                      padding: EdgeInsets.fromLTRB(
                                          padH, padV, padH, padV),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(_kCardRadius),
                                        border: Border.all(
                                          color: _kCardBorder,
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // --- 상단 바 ---
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              // 날짜(좌)
                                              Flexible(
                                                flex: 0,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(weekdayStr,
                                                        style:
                                                            _weekdayTextStyle),
                                                    const SizedBox(width: 8),
                                                    Text(dateNumStr,
                                                        style:
                                                            _dateNumTextStyle),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // 안내 문구(가운데)
                                              Expanded(
                                                child: Center(
                                                  child: Text(
                                                    _headlineOf(step),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 36,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Next 이미지(우)
                                              Flexible(
                                                flex: 0,
                                                child: _MakeButton(
                                                  scale: 120 / 195, // 기존 높이(120)에 맞게 스케일 조정
                                                  imageAsset: isLastStep
                                                      ? 'assets/test/logo_bird_done.png'
                                                      : 'assets/test/logo_bird_next.png',
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
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: (24.0 * scale)
                                                .clamp(12.0, 28.0),
                                          ),

                                          // 좌석 그리드
                                          Expanded(
                                            child: _SeatGridTestUI(
                                              cols: cols,
                                              rows: rows,
                                              seatMap: seatMap,
                                              nameOf: nameOf,
                                              isDoneBuilder: (studentId) =>
                                                  isDone(studentId),
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
                hasStudent && isDoneBuilder(studentId!) ? _kSeatDone : _kSeatBase;

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
// ─────────────────────────────────────────────
// 공통 Bird Button (Hover/Click Scale 애니메이션)
// ─────────────────────────────────────────────
class _MakeButton extends StatefulWidget {
  const _MakeButton({
    required this.scale,
    required this.imageAsset,
    required this.onTap,
    this.enabled = true,
  });

  final double scale;
  final String imageAsset;
  final VoidCallback onTap;
  final bool enabled;

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
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Image.asset(
                widget.imageAsset,
                key: ValueKey<String>(widget.imageAsset),
                width: w,
                height: h,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
