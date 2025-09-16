


// lib/pages/home/presenter_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Providers
import '../../provider/session_provider.dart';
import '../../sidebar_menu.dart';

const _kBoardGreen = Color(0xFFD7FF79);
const _kSoftBlueBg = Color(0xFFEAF2FF);
const _kSoftBlueBd = Color(0xFF9DBCFD);
const _kSoftPinkBg = Color(0xFFFBE9EE);
const _kSoftPinkBd = Color(0xFFF0B9C8);
const _kEmptyStroke = Color(0xFFCBD5E1);

const _kAppBg = Color(0xFFF6FAFF);
const _kPanelBorder = Color(0xFFE6EEF8);
const _kPanelShadow = Color(0x14000000);
const _kTitleNavy = Color(0xFF0B1324);

const _kCardW = 1011.0;
const _kCardH = 544.0;
const _kCardRadius = 10.0;
const _kCardBorder = Color(0xFFD2D2D2);

const _kDateFontSize = 16.0;
const _kDateLineHeight = 34.0 / 16.0; // 2.125

const _weekdayFont = 'FONTSPRING DEMO - Lufga';
const _dateNumFont = 'Pretendard Variable';

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

// 버튼 지정
enum SlotPurpose { attendance, action }

extension SlotPurposeX on SlotPurpose {
  String get key => this == SlotPurpose.attendance ? 'attendance' : 'action';
  static SlotPurpose fromKey(String? key) {
    if (key == 'action') return SlotPurpose.action;
    return SlotPurpose.attendance;
  }
}

const String kHubId = 'hub-001'; // your hub/classroom id

class PresenterHomePage extends StatefulWidget {
  @override
  State<PresenterHomePage> createState() => _PresenterHomePageState();
}

class _PresenterHomePageState extends State<PresenterHomePage> {
  bool _showLogs = false;
  bool _popping = false;

  // ✅ 세션 문서 + 모든 서브컬렉션 완전 삭제
Future<void> _deleteSessionFully(String sid) async {
  final fs = FirebaseFirestore.instance;

  // 1) 서브컬렉션 전부 삭제
  await _deleteCollection(fs, 'sessions/$sid/events', 500);
  await _deleteCollection(fs, 'sessions/$sid/seatMap', 500);
  await _deleteCollection(fs, 'sessions/$sid/studentStats', 500);
  await _deleteCollection(fs, 'sessions/$sid/stats', 500);

  // 2) 세션 문서 자체 삭제
  final docRef = fs.doc('sessions/$sid');
  final doc = await docRef.get();
  if (doc.exists) {
    await docRef.delete();
  }
}

  // Busy overlay
  bool _busy = false;
  String? _busyMsg;
  void _setBusy(bool v, [String? msg]) {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyMsg = v ? (msg ?? 'Loading...') : null;
    });
  }

  // ====== logger helpers ======
  String _ts() => DateTime.now().toIso8601String();
  void _log(String msg) => debugPrint('[HOME ${_ts()}] $msg');

  // Seat doc ids: "1".."N"
  String _seatKey(int index) => '${index + 1}';

  // ---- Safe pop (route/dialog) on next frame ----
  void _safeRootPop<T>(T result) {
    if (_popping) {
      _log('SAFE_POP suppressed: $result');
      return;
    }
    _popping = true;
    _log('SAFE_POP request: $result');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _popping = false;
        _log('SAFE_POP aborted (not mounted)');
        return;
      }
      Navigator.of(context, rootNavigator: true).pop(result);
      _popping = false;
      _log('SAFE_POP done: $result');
    });
  }

  // ---- Wait one endOfFrame + microtask ----
  Future<void> _runNextFrame(FutureOr<void> Function() action) async {
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await action();
  }

  @override
  void initState() {
    super.initState();
    // 첫 진입 시 세션 자동 확보 + 해당 세션 이벤트 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureSessionOnStart();
    });
  }

  // ====== ensure session on first load ======
  Future<void> _ensureSessionOnStart() async {
    _log('ensureSessionOnStart: begin');
    final session = context.read<SessionProvider>();
    final currentSid = session.sessionId;

    try {
      if (currentSid != null) {
        _log('ensureSessionOnStart: already bound to $currentSid');
        _log('ensureSessionOnStart: clear events');
        await _clearEventsForSession(currentSid);
        return;
      }

      final ids = await _listRecentSessionIds(limit: 50);
      _log('ensureSessionOnStart: found ${ids.length} sessions');
      if (ids.isEmpty) {
        _log('ensureSessionOnStart: no sessions -> open picker sheet');
        await _openSessionMenu(context);
        return;
      }

      // 최신 것 자동 선택
      final sid = ids.first;
      _log('ensureSessionOnStart: auto-load recent "$sid"');
      await _switchSessionAndBind(context, sid);

      // touch updatedAt
      await FirebaseFirestore.instance.doc('sessions/$sid').set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ▶ 진입 시 기존 로그 비우기 (오버레이)
      await _clearEventsForSession(sid);

      _log('ensureSessionOnStart: done');
    } catch (e, st) {
      _log('ensureSessionOnStart ERROR: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load recent session: $e')),
      );
      // 세션 선택 시트로 폴백
      await _openSessionMenu(context);
    }
  }

  // 현재 세션 events 전체 삭제(진입/세션전환 시)
  Future<void> _clearEventsForSession(String sid) async {
    _log('clearEventsForSession: start for $sid');
    _setBusy(true, 'Clearing session logs…');
    try {
      await _deleteCollection(
        FirebaseFirestore.instance,
        'sessions/$sid/events',
        300,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Session logs cleared.')));
      _log('clearEventsForSession: done');
    } catch (e, st) {
      _log('clearEventsForSession ERROR: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to clear logs: $e')));
    } finally {
      _setBusy(false);
    }
  }

  // ===== robust slot extraction =====
  String? _extractSlot(dynamic raw, {String? triggerKey}) {
    final s = raw?.toString().trim().toUpperCase();
    if (s == '1' || s == 'SLOT1' || s == 'S1' || s == 'LEFT') return '1';
    if (s == '2' || s == 'SLOT2' || s == 'S2' || s == 'RIGHT') return '2';
    final t = triggerKey?.toString().trim().toUpperCase();
    if (t?.startsWith('S1_') == true) return '1';
    if (t?.startsWith('S2_') == true) return '2';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final sessionId = session.sessionId;
    final fs = FirebaseFirestore.instance;

    // Top bar & 세션 조작은 그대로 두고, 좌석/이벤트/학생 데이터는 스트림으로 직접 구독
    return AppScaffold(
      selectedIndex: 0,
      body: Scaffold(
        backgroundColor: _kAppBg,
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar (Back + Session)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Back',
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                _log('Back pressed -> Navigator.pop');
                                Navigator.pop(context);
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              sessionId == null
                                  ? 'No session'
                                  : 'Session • $sessionId',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton(
                          onPressed: () {
                            _log('Session button tapped');
                            _openSessionMenu(context);
                          },
                          child: const Text('Session'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ===== Board + Seat (스트림 체인) =====
                    if (sessionId == null)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'No session. Tap "Session" to create or load.',
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.9,
                            heightFactor: 0.9,
                            // ✅ 카드(Container) 대신, 먼저 세션 메타를 구해서
                            //   "버튼매핑(위) + 카드(아래)"를 Column으로 배치
                            child: StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: fs.doc('sessions/$sessionId').snapshots(),
                              builder: (context, sessSnap) {
                                final meta = sessSnap.data?.data();
                                final int cols =
                                    (meta?['cols'] as num?)?.toInt() ?? 6;
                                final int rows =
                                    (meta?['rows'] as num?)?.toInt() ?? 4;

                                // 슬롯 목적 맵
                                final Map<String, dynamic> rawPurpose =
                                    (meta?['slotPurpose']
                                        as Map<String, dynamic>?) ??
                                    const {};
                                final Map<String, SlotPurpose> slotPurpose = {
                                  '1': SlotPurposeX.fromKey(
                                    rawPurpose['1'] as String? ?? 'attendance',
                                  ),
                                  '2': SlotPurposeX.fromKey(
                                    rawPurpose['2'] as String? ?? 'action',
                                  ),
                                };

                                Future<void> _saveSlotPurpose(
                                  String slot,
                                  SlotPurpose p,
                                ) async {
                                  await FirebaseFirestore.instance
                                      .doc('sessions/$sessionId')
                                      .set({
                                        'slotPurpose': {slot: p.key},
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));
                                }

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // 🔼 카드 위로 뺀 버튼 매핑
                                    Center(
                                      child: _SlotMappingPill(
                                        slot1: slotPurpose['1']!,
                                        slot2: slotPurpose['2']!,
                                        onChanged: (slot, p) async {
                                          await _saveSlotPurpose(slot, p);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Slot $slot → ${p.key}',
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // 🔽 아래는 "카드" (원래 Container) + 그 안의 기존 내용
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, c) {
                                          final scaleW = c.maxWidth / _kCardW;
                                          final scaleH = c.maxHeight / _kCardH;
                                          final scale =
                                              (scaleW < scaleH)
                                                  ? scaleW
                                                  : scaleH; // ↑ 확대/축소 모두 허용

                                          final cardW = _kCardW * scale;
                                          final cardH = _kCardH * scale;

                                          // 카드 내부 여백/모서리/테두리도 비율에 맞춰 스케일
                                          final r = _kCardRadius * scale;
                                          final padH = 28.0 * scale;
                                          final padV = 24.0 * scale;
                                          final borderW = (1.0 * scale).clamp(
                                            0.75,
                                            2.0,
                                          ); // 너무 얇거나 두꺼워지는 것 방지

                                          return Center(
                                            child: SizedBox(
  width: cardW,
  height: cardH,
  child: Container(
    padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kCardRadius),
      border: Border.all(color: _kCardBorder, width: 1),
    ),
                                                  // ⬇️ 스트림 체인은 반드시 Container의 child로!
                                                  child: StreamBuilder<
                                                    QuerySnapshot<
                                                      Map<String, dynamic>
                                                    >
                                                  >(
                                                    stream:
                                                        fs
                                                            .collection(
                                                              'sessions/$sessionId/seatMap',
                                                            )
                                                            .snapshots(),
                                                    builder: (
                                                      context,
                                                      seatSnap,
                                                    ) {
                                                      final Map<String, String?>
                                                      seatMap = {};
                                                      if (seatSnap.data !=
                                                          null) {
                                                        for (final d
                                                            in seatSnap
                                                                .data!
                                                                .docs) {
                                                          seatMap[d.id] =
                                                              (d.data()['studentId']
                                                                      as String?)
                                                                  ?.trim();
                                                        }
                                                      }

                                                      return StreamBuilder<
                                                        QuerySnapshot<
                                                          Map<String, dynamic>
                                                        >
                                                      >(
                                                        stream:
                                                            fs
                                                                .collection(
                                                                  'students',
                                                                )
                                                                .snapshots(),
                                                        builder: (
                                                          context,
                                                          stuSnap,
                                                        ) {
                                                          final Map<
                                                            String,
                                                            String
                                                          >
                                                          nameOf = {};
                                                          if (stuSnap.data !=
                                                              null) {
                                                            for (final d
                                                                in stuSnap
                                                                    .data!
                                                                    .docs) {
                                                              final x =
                                                                  d.data();
                                                              final n =
                                                                  (x['name']
                                                                          as String?)
                                                                      ?.trim();
                                                              if (n != null &&
                                                                  n.isNotEmpty)
                                                                nameOf[d.id] =
                                                                    n;
                                                            }
                                                          }

                                                          return StreamBuilder<
                                                            QuerySnapshot<
                                                              Map<
                                                                String,
                                                                dynamic
                                                              >
                                                            >
                                                          >(
                                                            stream:
                                                                fs
                                                                    .collection(
                                                                      'sessions/$sessionId/events',
                                                                    )
                                                                    .orderBy(
                                                                      'ts',
                                                                      descending:
                                                                          true,
                                                                    )
                                                                    .limit(300)
                                                                    .snapshots(),
                                                            builder: (
                                                              context,
                                                              evSnap,
                                                            ) {
                                                              final Map<
                                                                String,
                                                                String
                                                              >
                                                              lastSlotByStudent =
                                                                  {};
                                                              final Map<
                                                                String,
                                                                int
                                                              >
                                                              lastScoreByStudent =
                                                                  {};

                                                              if (evSnap.data !=
                                                                  null) {
                                                                for (final d
                                                                    in evSnap
                                                                        .data!
                                                                        .docs) {
                                                                  final x =
                                                                      d.data();
                                                                  final studentId =
                                                                      (x['studentId']
                                                                              as String?)
                                                                          ?.trim();
                                                                  if (studentId ==
                                                                          null ||
                                                                      studentId
                                                                          .isEmpty)
                                                                    continue;
                                                                  final slot = _extractSlot(
                                                                    x['slotIndex'],
                                                                    triggerKey:
                                                                        x['triggerKey'],
                                                                  );
                                                                  if (slot !=
                                                                          '1' &&
                                                                      slot !=
                                                                          '2')
                                                                    continue;
                                                                  final int
                                                                  hubTs =
                                                                      (x['hubTs']
                                                                              as num?)
                                                                          ?.toInt() ??
                                                                      0;
                                                                  final int ts =
                                                                      (x['ts']
                                                                              is Timestamp)
                                                                          ? (x['ts']
                                                                                  as Timestamp)
                                                                              .millisecondsSinceEpoch
                                                                          : 0;
                                                                  final score =
                                                                      (hubTs >
                                                                              ts)
                                                                          ? hubTs
                                                                          : ts;
                                                                  final prev =
                                                                      lastScoreByStudent[studentId];
                                                                  if (prev ==
                                                                          null ||
                                                                      score >
                                                                          prev) {
                                                                    lastScoreByStudent[studentId] =
                                                                        score;
                                                                    lastSlotByStudent[studentId] =
                                                                        slot!;
                                                                  }
                                                                }
                                                              }

                                                              final now =
                                                                  DateTime.now();
                                                              final weekdayStr =
                                                                  [
                                                                    'SUN',
                                                                    'MON',
                                                                    'TUE',
                                                                    'WED',
                                                                    'THU',
                                                                    'FRI',
                                                                    'SAT',
                                                                  ][now.weekday %
                                                                      7];
                                                              final dateNumStr =
                                                                  '${now.month.toString().padLeft(2, "0")}.${now.day.toString().padLeft(2, "0")}';
                                                              final totalSeats =
                                                                  cols * rows;
                                                              final assignedCount =
                                                                  seatMap.values
                                                                      .where(
                                                                        (v) =>
                                                                            (v?.trim().isNotEmpty ??
                                                                                false),
                                                                      )
                                                                      .length;

                                                              return Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  // 상단 줄: 날짜 • 합계
                                                                  // 상단 줄: 날짜(요일+숫자) • 합계
                                                                  // ⛳️ 날짜 • Board • 학생 수를 한 줄에 배치
                                                                  Row(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      // 날짜(요일 + 숫자)
                                                                      Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Text(
                                                                            weekdayStr,
                                                                            style:
                                                                                _weekdayTextStyle,
                                                                          ), // Lufga, 16, lh 34
                                                                          const SizedBox(
                                                                            width:
                                                                                8,
                                                                          ),
                                                                          Text(
                                                                            dateNumStr,
                                                                            style:
                                                                                _dateNumTextStyle,
                                                                          ), // Pretendard Var, 16, lh 34
                                                                        ],
                                                                      ),

                                                                      const Spacer(),

                                                                      // Board pill (가운데)
                                                                      SizedBox(
                                                                        width:
                                                                            544,
                                                                        height:
                                                                            40,
                                                                        child: DecoratedBox(
                                                                          decoration: BoxDecoration(
                                                                            color: const Color(
                                                                              0xFFD3FF6E,
                                                                            ),
                                                                            borderRadius: BorderRadius.circular(
                                                                              12.05,
                                                                            ),
                                                                          ),
                                                                          child: const Center(
                                                                            child: Text(
                                                                              'Board',
                                                                              style: TextStyle(
                                                                                fontSize:
                                                                                    16,
                                                                                fontWeight:
                                                                                    FontWeight.w700,
                                                                                color:
                                                                                    Colors.black,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),

                                                                      const Spacer(),

                                                                      // 학생 수 (오른쪽 정렬, 고정 너비)
                                                                      SizedBox(
                                                                        width:
                                                                            142, // 피그마 기준
                                                                        child: Text(
                                                                          '$assignedCount / $totalSeats',
                                                                          textAlign:
                                                                              TextAlign.right,
                                                                          style: const TextStyle(
                                                                            fontSize:
                                                                                25.26,
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            height:
                                                                                25 /
                                                                                25.26,
                                                                            color: Color(
                                                                              0xFF001A36,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  SizedBox(height: (18.0 * scale).clamp(12.0, 28.0)),

                                                                  // Seat grid
                                                                  Expanded(
                                                                    child: _SeatGrid(
                                                                      cols:
                                                                          cols,
                                                                      rows:
                                                                          rows,
                                                                      seatMap:
                                                                          seatMap,
                                                                      nameOf:
                                                                          nameOf,
                                                                      lastSlotByStudent:
                                                                          lastSlotByStudent,
                                                                      onSeatTap:
                                                                          (
                                                                            seatIndex,
                                                                          ) => _openSeatPicker(
                                                                            seatIndex:
                                                                                seatIndex,
                                                                          ),
                                                                      purposeOfSlot:
                                                                          (
                                                                            studentId,
                                                                            slot,
                                                                          ) =>
                                                                              slotPurpose[slot]?.key,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 12,
                                                                  ),

                                                                  // Logs
                                                                  Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .spaceBetween,
                                                                    children: [
                                                                      TextButton.icon(
                                                                        onPressed:
                                                                            () => setState(
                                                                              () =>
                                                                                  _showLogs =
                                                                                      !_showLogs,
                                                                            ),
                                                                        icon: Icon(
                                                                          _showLogs
                                                                              ? Icons.expand_more
                                                                              : Icons.expand_less,
                                                                        ),
                                                                        label: Text(
                                                                          _showLogs
                                                                              ? 'Hide logs'
                                                                              : 'Show logs',
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  if (_showLogs)
                                                                    SizedBox(
                                                                      height:
                                                                          200,
                                                                      child: Container(
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              8,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          color:
                                                                              Colors.grey.shade200,
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                8,
                                                                              ),
                                                                        ),
                                                                        child:
                                                                            (evSnap.data ==
                                                                                        null ||
                                                                                    evSnap.data!.docs.isEmpty)
                                                                                ? const Center(
                                                                                  child: Text(
                                                                                    'No logs',
                                                                                  ),
                                                                                )
                                                                                : ListView.builder(
                                                                                  itemCount:
                                                                                      evSnap.data!.docs.length,
                                                                                  itemBuilder: (
                                                                                    context,
                                                                                    index,
                                                                                  ) {
                                                                                    final ev =
                                                                                        evSnap.data!.docs[index].data();
                                                                                    final sid =
                                                                                        ev['studentId']
                                                                                            as String?;
                                                                                    final name =
                                                                                        (sid ==
                                                                                                null)
                                                                                            ? '(unknown)'
                                                                                            : (nameOf[sid] ??
                                                                                                sid);
                                                                                    final timeStr =
                                                                                        (ev['ts']
                                                                                                is Timestamp)
                                                                                            ? (ev['ts']
                                                                                                    as Timestamp)
                                                                                                .toDate()
                                                                                                .toLocal()
                                                                                                .toString()
                                                                                            : '-';
                                                                                    final slot =
                                                                                        ev['slotIndex']?.toString();
                                                                                    final dev =
                                                                                        (ev['deviceId']
                                                                                                as String? ??
                                                                                            '');
                                                                                    final tail5 =
                                                                                        dev.length >
                                                                                                5
                                                                                            ? dev.substring(
                                                                                              dev.length -
                                                                                                  5,
                                                                                            )
                                                                                            : dev;
                                                                                    final clickType =
                                                                                        (ev['clickType']
                                                                                                as String? ??
                                                                                            '');
                                                                                    return ListTile(
                                                                                      dense:
                                                                                          true,
                                                                                      title: Text(
                                                                                        '$name (slot ${slot ?? '-'} • $clickType)',
                                                                                      ),
                                                                                      subtitle: Text(
                                                                                        'dev …$tail5 • hubTs=${(ev['hubTs'] as num?)?.toInt() ?? 0} • $timeStr',
                                                                                        style: const TextStyle(
                                                                                          fontSize:
                                                                                              12,
                                                                                        ),
                                                                                      ),
                                                                                    );
                                                                                  },
                                                                                ),
                                                                      ),
                                                                    ),
                                                                ],
                                                              );
                                                            },
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                    // 우리 측 busy overlay (로그 초기화 등)
                    if (_busy)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _busyMsg ?? 'Working…',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== Session menu =====================
  Future<void> _openSessionMenu(BuildContext context) async {
    _log('Open session sheet');

    final String? action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) {
        final noSplashTheme = Theme.of(sheetCtx).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
        );
        return Theme(
          data: noSplashTheme,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.fiber_new),
                  title: const Text('New session'),
                  subtitle: const Text('Set seat layout (cols/rows)'),
                  onTap: () {
                    _log('sheet tap: new_empty');
                    Navigator.of(
                      sheetCtx,
                      rootNavigator: true,
                    ).pop('new_empty');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: const Text('Load existing session'),
                  subtitle: const Text('Switch to a saved session & layout'),
                  onTap: () {
                    _log('sheet tap: load_existing');
                    Navigator.of(
                      sheetCtx,
                      rootNavigator: true,
                    ).pop('load_existing');
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete current session data (admin)'),
                  subtitle: const Text(
                    'Delete events, studentStats, and stats/summary',
                  ),
                  onTap: () {
                    _log('sheet tap: purge');
                    Navigator.of(sheetCtx, rootNavigator: true).pop('purge');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    _log('sheet closed with action=$action');
    if (!mounted || action == null) return;

    await _runNextFrame(() async {
      _log('execute action: $action');
      switch (action) {
        case 'new_empty':
          await _createEmptySession(context);
          break;
        case 'load_existing':
          await _loadExistingSession(context);
          break;
        case 'purge':
          await _purgeCurrentSession(context);
          break;
      }
      _log('done action: $action');
    });
  }

  // ---------- New session (with cols/rows) ----------
  Future<void> _createEmptySession(BuildContext context) async {
    _log('createEmptySession: open dialog');

    final ctrlSid = TextEditingController(text: _defaultSessionId());
    int cols = 6;
    int rows = 4;

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) {
        final noSplashTheme = Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
        );
        return Theme(
          data: noSplashTheme,
          child: StatefulBuilder(
            builder:
                (context, setLocal) => AlertDialog(
                  title: const Text('New session'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: ctrlSid,
                        decoration: const InputDecoration(
                          labelText: 'Session ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DialogStepper(
                              label: 'Cols',
                              value: cols,
                              onChanged:
                                  (v) => setLocal(() => cols = v.clamp(1, 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DialogStepper(
                              label: 'Rows',
                              value: rows,
                              onChanged:
                                  (v) => setLocal(() => rows = v.clamp(1, 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => _safeRootPop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => _safeRootPop(true),
                      child: const Text('Create'),
                    ),
                  ],
                ),
          ),
        );
      },
    );
    _log('createEmptySession: dialog result=$ok');
    if (ok != true) return;

    await _runNextFrame(() async {
      final sid = ctrlSid.text.trim();
      if (sid.isEmpty) {
        _log('createEmptySession: empty sid, abort');
        return;
      }

      _log('createEmptySession: switch/bind sid=$sid');
      await _switchSessionAndBind(context, sid);

      _log('createEmptySession: write sessions/$sid meta with cols/rows');
      await FirebaseFirestore.instance.doc('sessions/$sid').set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'note': 'empty layout',
        'cols': cols,
        'rows': rows,
      }, SetOptions(merge: true));

      // 새 세션이어도 초기화 UX 일관성 유지 (no-op이어도 호출)
      await _clearEventsForSession(sid);

      if (!mounted) return;
      _log('createEmptySession: snackbar');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Started new session: $sid ($cols×$rows)')),
      );
    });
  }

  // ---------- Load existing ----------
  Future<void> _loadExistingSession(BuildContext context) async {
    _log('loadExisting: pick dialog');
    final sid = await _pickSessionId(context, title: 'Load session');
    _log('loadExisting: picked=$sid');
    if (sid == null) return;

    await _runNextFrame(() async {
      _log('loadExisting: switch/bind sid=$sid');
      await _switchSessionAndBind(context, sid);

      _log('loadExisting: touch updatedAt');
      await FirebaseFirestore.instance.doc('sessions/$sid').set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ▶ 다른 세션 로드 시에도 초기화
      await _clearEventsForSession(sid);

      if (!mounted) return;
      _log('loadExisting: snackbar');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Loaded session: $sid')));
    });
  }

  // ---------- Common: switch + bind + set hub ----------
  Future<void> _switchSessionAndBind(BuildContext context, String sid) async {
    _log('switchSessionAndBind: start sid=$sid');
    final session = context.read<SessionProvider>();

    session.setSession(sid);
    _log('switchSessionAndBind: session.setSession done');

    // hub가 이 세션을 따라가도록
    await FirebaseFirestore.instance.doc('hubs/$kHubId').set({
      'currentSessionId': sid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _log('switchSessionAndBind: hub updated');
  }

  // ---------- Helpers ----------
  // 서버 orderBy 없이 가져와 로컬에서 정렬
  Future<List<String>> _listRecentSessionIds({int limit = 50}) async {
    final fs = FirebaseFirestore.instance;
    try {
      final snap = await fs.collection('sessions').limit(limit).get();
      final docs = [...snap.docs];
      docs.sort((a, b) {
        final ta = (a.data()['updatedAt'] as Timestamp?);
        final tb = (b.data()['updatedAt'] as Timestamp?);
        final va = ta?.millisecondsSinceEpoch ?? 0;
        final vb = tb?.millisecondsSinceEpoch ?? 0;
        return vb.compareTo(va);
      });
      return docs.map((d) => d.id).toList();
    } catch (e, st) {
      _log('listRecentSessionIds error: $e\n$st');
      final alt = await fs.collection('sessions').limit(limit).get();
      return alt.docs.map((d) => d.id).toList();
    }
  }

  Future<String?> _pickSessionId(
    BuildContext context, {
    required String title,
  }) async {
    final ids = await _listRecentSessionIds();
    _log('pickSessionId: ${ids.length} items');
    if (ids.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No saved sessions.')));
      return null;
    }

    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) {
        final noSplashTheme = Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
        );
        return Theme(
          data: noSplashTheme,
          child: SimpleDialog(
            title: Text(title),
            children: [
              SizedBox(
                width: 420,
                height: 360,
                child: ListView.builder(
                  itemCount: ids.length,
                  itemBuilder:
                      (_, i) => ListTile(
                        title: Text(ids[i]),
                        onTap: () => _safeRootPop(ids[i]),
                      ),
                ),
              ),
              TextButton(
                onPressed: () => _safeRootPop(null),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSeatPicker({required int seatIndex}) async {
    final fs = FirebaseFirestore.instance;
    final sid = context.read<SessionProvider>().sessionId;
    if (sid == null) return;

    final seatNo = _seatKey(seatIndex);

    // 학생 목록 로드(간단 버전)
    final stuSnap = await fs.collection('students').get();
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('— Empty —')),
      ...stuSnap.docs.map((d) {
        final name = (d.data()['name'] as String?) ?? d.id;
        return DropdownMenuItem<String?>(value: d.id, child: Text(name));
      }),
    ];

    String? selected;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) {
        final noSplashTheme = Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
        );
        return Theme(
          data: noSplashTheme,
          child: AlertDialog(
            title: Text('Seat $seatNo • Assign student'),
            content: DropdownButtonFormField<String?>(
              isExpanded: true,
              value: selected,
              items: items,
              onChanged: (v) => selected = v,
              decoration: const InputDecoration(
                labelText: 'Student',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _safeRootPop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _safeRootPop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (ok == true) {
      try {
        await _assignSeatExclusive(seatNo: seatNo, studentId: selected);
        final name =
            selected == null
                ? 'Empty'
                : ((await fs.doc('students/$selected').get()).data()?['name']
                        as String? ??
                    selected);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Seat $seatNo → $name')));
        _log('assignSeatExclusive OK: seat=$seatNo student=$selected');
      } catch (e, st) {
        _log('assignSeatExclusive ERROR: $e\n$st');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Assign failed: $e')));
      }
    }
  }

  // ====== Admin purge ======
  Future<void> _purgeCurrentSession(BuildContext context) async {
  final sid = context.read<SessionProvider>().sessionId;
  _log('purge: start (sid=$sid)');
  if (sid == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('No session is set.')));
    return;
  }

  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (_) => AlertDialog(
      title: const Text('Delete current session'),
      content: Text(
        'This will remove the entire session (document + all subcollections):\n'
        'events, seatMap, studentStats, stats.\n\n'
        'sessions/$sid\n\n'
        'This cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => _safeRootPop(false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => _safeRootPop(true), child: const Text('Delete')),
      ],
    ),
  );
  _log('purge: confirm result=$ok');
  if (ok != true) return;

  // 로딩 오버레이
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (_) => const Center(child: CircularProgressIndicator()),
    useRootNavigator: true,
  );

  try {
    // 1) 세션 완전 삭제
    await _deleteSessionFully(sid);

    // 2) 가장 최근 세션 자동 선택(있으면)
    final remain = await _listRecentSessionIds(limit: 50);
    if (remain.isNotEmpty) {
      final nextSid = remain.first;
      _log('purge: switch to next recent session "$nextSid"');
      await _switchSessionAndBind(context, nextSid);

      // 기존 UX와 맞추려면 로드 직후 이벤트도 정리
      await _clearEventsForSession(nextSid);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session "$sid" deleted. Switched to "$nextSid".')),
        );
      }
    } else {
      // 3) 남은 세션이 없으면 언바인드
      final session = context.read<SessionProvider>();
      // SessionProvider가 nullable이면 아래 한 줄이 동작합니다.
      session.clear();

      await FirebaseFirestore.instance.doc('hubs/$kHubId').set({
        'currentSessionId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session deleted. No sessions left.')),
        );
      }
    }
  } catch (e, st) {
    _log('purge ERROR: $e\n$st');
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // 로딩 닫기
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Delete failed: $e')),
    );
  }
}


  Future<void> _deleteCollection(
    FirebaseFirestore fs,
    String path,
    int batchSize,
  ) async {
    Query q = fs.collection(path).limit(batchSize);
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
    _log('deleteCollection: done $path');
  }

  String _defaultSessionId() {
    final now = DateTime.now();
    return '${now.toIso8601String().substring(0, 10)}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  // ===== exclusive seat assign (no duplicates) =====
  Future<void> _assignSeatExclusive({
    required String seatNo,
    required String? studentId, // null이면 비우기
  }) async {
    final sid = context.read<SessionProvider>().sessionId;
    if (sid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No session is set.')));
      return;
    }

    final fs = FirebaseFirestore.instance;
    final col = fs.collection('sessions/$sid/seatMap');

    // 미리 중복 후보 목록 조회 (쿼리는 트랜잭션 밖에서만 가능)
    List<DocumentSnapshot<Map<String, dynamic>>> dupDocs = const [];
    if (studentId != null) {
      final qSnap =
          await col.where('studentId', isEqualTo: studentId).limit(50).get();
      dupDocs = qSnap.docs;
    }

    await fs.runTransaction((tx) async {
      // 1) 기존에 그 학생이 앉아 있던 다른 좌석 -> 비우기
      for (final d in dupDocs) {
        if (d.id == seatNo) continue;
        final dr = col.doc(d.id);
        final latest = await tx.get(dr);
        final latestStudent = latest.data()?['studentId'] as String?;
        if (latest.exists && latestStudent == studentId) {
          tx.set(dr, {'studentId': null}, SetOptions(merge: true));
        }
      }
      // 2) 타깃 좌석 최종 배정/비우기
      final targetRef = col.doc(seatNo);
      tx.set(targetRef, {'studentId': studentId}, SetOptions(merge: true));
    });
  }
}

enum _SeatState { empty, assignedAbsent, attended, actioned }

_SeatState _seatStateByPurpose({
  required bool hasStudent,
  required String? lastSlot,
  required String? Function(String studentId, String slot) purposeOfSlot,
  required String studentId,
}) {
  if (!hasStudent) return _SeatState.empty;
  if (lastSlot == null) return _SeatState.assignedAbsent;

  final purpose = purposeOfSlot(
    studentId,
    lastSlot,
  ); // 'attendance' | 'action' | null
  if (purpose == 'attendance') return _SeatState.attended;
  if (purpose == 'action') return _SeatState.actioned;

  return _SeatState.assignedAbsent;
}

Color _colorOfState(_SeatState s) {
  switch (s) {
    case _SeatState.empty:
      return Colors.white; // 빈 좌석
    case _SeatState.assignedAbsent:
      return Colors.black; // 미출석(검정)
    case _SeatState.attended:
      return _kSoftBlueBg; // 출석(연파랑)
    case _SeatState.actioned:
      return _kSoftPinkBg; // 액션(연핑크)
  }
}

/* ---------- Seat Grid ---------- */

class _SeatGrid extends StatelessWidget {
  const _SeatGrid({
    required this.cols,
    required this.rows,
    required this.seatMap,
    required this.nameOf,
    required this.lastSlotByStudent,
    required this.onSeatTap,
    required this.purposeOfSlot,
  });

  final int cols;
  final int rows;
  final Map<String, String?> seatMap; // seatNo -> studentId?
  final Map<String, String> nameOf; // studentId -> name
  final Map<String, String> lastSlotByStudent; // studentId -> '1' | '2'
  final ValueChanged<int> onSeatTap;

  final String? Function(String studentId, String slot) purposeOfSlot;

  String _seatKey(int index) => '${index + 1}';

  Color? _highlightColor(String? slot) {
    if (slot == '2') return Colors.lightGreenAccent; // slot2=초록
    if (slot == '1') return Colors.redAccent; // slot1=빨강
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final seatCount = cols * rows;

    return LayoutBuilder(
      builder: (context, c) {
        const crossSpacing = 24.0;
        const mainSpacing = 24.0;

        final gridW = c.maxWidth;
final gridH = c.maxHeight - 2; // ⬅️ 1~2px 여유로 오차 흡수
final tileW = (gridW - crossSpacing * (cols - 1)) / cols;
final tileH = (gridH - mainSpacing * (rows - 1)) / rows;
final ratio = (tileW / tileH).isFinite ? tileW / tileH : 1.0;

return GridView.builder(
  padding: const EdgeInsets.only(bottom: 8), // ⬅️ 마지막 줄 여유 공간
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
            final seatStudentId = seatMap[seatNo]?.trim();
            final hasStudent =
                seatStudentId != null && seatStudentId.isNotEmpty;
            final name =
                hasStudent ? (nameOf[seatStudentId!] ?? seatStudentId) : null;
            final lastSlot =
                hasStudent ? lastSlotByStudent[seatStudentId!] : null;

            final state = _seatStateByPurpose(
              hasStudent: hasStudent,
              lastSlot: lastSlot,
              purposeOfSlot: purposeOfSlot,
              studentId: seatStudentId ?? '',
            );
            final fillColor = _colorOfState(state);
            final isDark = fillColor.computeLuminance() < 0.5;
            final nameColor = isDark ? Colors.white : const Color(0xFF0B1324);
            final seatNoColor =
                isDark ? Colors.white70 : const Color(0xFF1F2937);
            final showDashed = (state == _SeatState.empty);

            // ... itemBuilder 내부 공통 계산( seatNo, hasStudent, state 등 ) 그대로 두고

            final tile = LayoutBuilder(
              builder: (ctx, cc) {
                // 디자인 기준(피그마) 대비 스케일: 기본치 계산은 유지
                const baseH = 76.0;
                final s = (cc.maxHeight / baseH).clamp(0.6, 2.2);

                final radius = 12.0 * s;
                final padH = (6.0 * s).clamp(2.0, 10.0);
                final padV = (4.0 * s).clamp(1.0, 8.0);
                final fsSeat = (12.0 * s).clamp(9.0, 16.0);
                final fsName = (14.0 * s).clamp(10.0, 18.0);
                final gap = (2.0 * s).clamp(1.0, 8.0);

                Widget contentColumn() => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seatNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      style: TextStyle(
                        fontSize: fsSeat,
                        height: 1.0, // 라인 여백 최소화
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
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      style: TextStyle(
                        fontSize: fsName,
                        height: 1.0,
                        color: nameColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );

                // 타일(배경/모서리) 크기는 고정, 내부 컨텐츠는 필요 시 축소
                final contentBox = Container(
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(radius),
                    border:
                        showDashed
                            ? null
                            : Border.all(color: Colors.transparent),
                  ),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: padH,
                    vertical: padV,
                  ),
                  child:
                      hasStudent
                          ? FittedBox(
                            // ✅ 넘치면 자동으로 축소
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: contentColumn(),
                          )
                          : const SizedBox.shrink(),
                );

                return showDashed
                    ? CustomPaint(
                      foregroundPainter: _DashedBorderPainter(
                        radius: radius + 4,
                        color: const Color(0xFFCBD5E1),
                        strokeWidth: (2.0 * s).clamp(1.2, 3.0),
                        dash: (8.0 * s).clamp(5.0, 12.0),
                        gap: (6.0 * s).clamp(3.0, 10.0),
                      ),
                      child: contentBox,
                    )
                    : contentBox;
              },
            );

            // 반환
            return InkWell(onTap: () => onSeatTap(index), child: tile);
          },
        );
      },
    );
  }
}

/* ---------- small UI pieces ---------- */

class _DialogStepper extends StatelessWidget {
  const _DialogStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            children: [
              _roundBtn(
                Icons.remove,
                onTap: () => onChanged((value - 1).clamp(1, 12)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '$value',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _roundBtn(
                Icons.add,
                onTap: () => onChanged((value + 1).clamp(1, 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

/* ---------- dashed border painter ---------- */

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

    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = color;

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len =
            distance + dash > metric.length ? metric.length - distance : dash;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth ||
        dash != oldDelegate.dash ||
        gap != oldDelegate.gap ||
        color != oldDelegate.color;
  }
}

class _SlotMappingPill extends StatelessWidget {
  const _SlotMappingPill({
    required this.slot1,
    required this.slot2,
    required this.onChanged,
  });

  final SlotPurpose slot1;
  final SlotPurpose slot2;
  final Future<void> Function(String slot, SlotPurpose purpose) onChanged;

  @override
  Widget build(BuildContext context) {
    Widget buildSelector({
      required String label,
      required String slot,
      required SlotPurpose value,
    }) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          DropdownButton<SlotPurpose>(
            value: value,
            onChanged: (v) {
              if (v != null) onChanged(slot, v);
            },
            items: const [
              DropdownMenuItem(
                value: SlotPurpose.attendance,
                child: Text('Attendance'),
              ),
              DropdownMenuItem(
                value: SlotPurpose.action,
                child: Text('Action'),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD2D2D2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildSelector(label: 'Slot 1', slot: '1', value: slot1),
          const SizedBox(width: 16),
          buildSelector(label: 'Slot 2', slot: '2', value: slot2),
        ],
      ),
    );
  }
}
