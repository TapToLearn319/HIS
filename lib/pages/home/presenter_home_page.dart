// lib/pages/home/presenter_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/help_badge.dart';
// Providers
import '../../provider/session_provider.dart';
import '../../provider/hub_provider.dart';
import '../../sidebar_menu.dart';

// ---- 색 / 상수 ----
const _kAppBg = Color(0xFFF6FAFF);
const _kCardW = 1011.0;
const _kCardH = 544.0;
const _kCardRadius = 10.0;
const _kCardBorder = Color(0xFFD2D2D2);

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

// 좌석 색: 출석/액션 기본(연파랑) & 수업 중 눌림(회색) & 미출석(연주황)
const _kAttendedBlue = Color(0xFFCEE6FF);
const _kDuringClassGray = Color(0x33A2A2A2);
const _kAssignedAbsent = Color(0xFFFFEBE2);

class PresenterHomePage extends StatefulWidget {
  @override
  State<PresenterHomePage> createState() => _PresenterHomePageState();
}

class _PresenterHomePageState extends State<PresenterHomePage> {
  bool _popping = false;

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

  static const String _kLastSessionKey = 'presenter_last_session_id';

Future<void> _saveLastSessionId(String hubId, String sid) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('$_kLastSessionKey:$hubId', sid);
}

Future<String?> _loadLastSessionId(String hubId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('$_kLastSessionKey:$hubId');
}

  // ── ⬇️ 추가: 화면 입장 이후만 인정하기 위한 기준 시각(세션별)
  int? _enterMs;
  String? _enterSessionId;
  int get _sinceMs => _enterMs ??= DateTime.now().millisecondsSinceEpoch;

  // 로그/도움
  String _ts() => DateTime.now().toIso8601String();
  void _log(String msg) => debugPrint('[HOME ${_ts()}] $msg');

  // 좌석 키
  String _seatKey(int index) => '${index + 1}';

  // 안전 팝
  void _safeRootPop<T>(T result) {
    if (_popping) return;
    _popping = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _popping = false;
        return;
      }
      Navigator.of(context, rootNavigator: true).pop(result);
      _popping = false;
    });
  }

  Future<void> _runNextFrame(FutureOr<void> Function() action) async {
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await action();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureSessionOnStart();
    });
  }

  // ===== 세션 보장 =====
  Future<void> _ensureSessionOnStart() async {
  _log('ensureSessionOnStart: begin');
  final hubId = context.read<HubProvider>().hubId;
  if (hubId == null) {
    _log('ensureSessionOnStart: hubId is null');
    return;
  }

  final session = context.read<SessionProvider>();
  final currentSid = session.sessionId;
  try {
    if (currentSid != null) {
      await FirebaseFirestore.instance
          .doc('hubs/$hubId/sessions/$currentSid')
          .set({
        'classRunning': false,
        'runIntervals': [],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    // ✅ (추가) 로컬에 저장된 "마지막 사용 세션"을 우선 시도
    final lastSid = await _loadLastSessionId(hubId);
    if (lastSid != null && lastSid.isNotEmpty) {
      final lastRef = FirebaseFirestore.instance.doc('hubs/$hubId/sessions/$lastSid');
      final lastDoc = await lastRef.get();
      if (lastDoc.exists) {
        await _switchSessionAndBind(context, lastSid);
        await lastRef.set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        return; // 복구 성공 시 여기서 종료
      }
    }

    // (기존) 최근 세션 목록에서 첫 번째 로드
    final ids = await _listRecentSessionIds(limit: 50);
    if (ids.isEmpty) {
      await _openSessionMenu(context);
      return;
    }
    final sid = ids.first;
    await _switchSessionAndBind(context, sid);
    await FirebaseFirestore.instance.doc('hubs/$hubId/sessions/$sid').set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (e, st) {
    _log('ensureSessionOnStart ERROR: $e\n$st');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Failed: $e')));
    await _openSessionMenu(context);
  }
}

  // 이벤트/라이브 타임스탬프 공통 파싱
  int _eventMs(Map<String, dynamic> x) {
    // 우선순위: ts(Timestamp) > hubTs(number) > ms/lastMs(number) > updatedAt(Timestamp)
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

  // 세션 완전 삭제
  Future<void> _deleteSessionFully(String sid) async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;

    final fs = FirebaseFirestore.instance;
    await _deleteCollection(fs, 'hubs/$hubId/sessions/$sid/events', 500);
    await _deleteCollection(fs, 'hubs/$hubId/sessions/$sid/seatMap', 500);
    await _deleteCollection(fs, 'hubs/$hubId/sessions/$sid/studentStats', 500);
    await _deleteCollection(fs, 'hubs/$hubId/sessions/$sid/stats', 500);
    final docRef = fs.doc('hubs/$hubId/sessions/$sid');
    final doc = await docRef.get();
    if (doc.exists) await docRef.delete();
  }

  // ===== 수업 토글 (서버 상태 기준) =====
  Future<void> _toggleClassRunningServer() async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;

    final sid = context.read<SessionProvider>().sessionId;
    if (sid == null) return;
    final fs = FirebaseFirestore.instance;
    final ref = fs.doc('hubs/$hubId/sessions/$sid');

    await fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final meta = snap.data() ?? {};
      final bool running = (meta['classRunning'] as bool?) ?? false;
      final List<dynamic> raw = (meta['runIntervals'] as List?)?.toList() ?? [];
      final now = DateTime.now().millisecondsSinceEpoch;

      if (running) {
        // stop: 마지막 구간 endMs 채우기
        if (raw.isNotEmpty) {
          final last = Map<String, dynamic>.from(raw.last as Map);
          if (last['endMs'] == null) {
            last['endMs'] = now;
            raw[raw.length - 1] = last;
          }
        }
        tx.set(
          ref,
          {
            'classRunning': false,
            'runIntervals': raw,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        // start: 새 구간 추가
        raw.add({'startMs': now, 'endMs': null});
        tx.set(
          ref,
          {
            'classRunning': true,
            'runIntervals': raw,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  // 서버 runIntervals 파싱
  List<_RunInterval> _parseRunIntervals(dynamic raw) {
    final List<_RunInterval> out = [];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final start = (e['startMs'] as num?)?.toInt();
          final end = (e['endMs'] as num?)?.toInt();
          if (start != null) out.add(_RunInterval(start, end));
        }
      }
    }
    return out;
  }

  bool _isDuringRunServer(int ms, List<_RunInterval> intervals) {
    for (final r in intervals) {
      final end = r.endMs ?? DateTime.now().millisecondsSinceEpoch;
      if (ms >= r.startMs && ms <= end) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hubId = context.watch<HubProvider>().hubId; // ✅ 허브 변경 시 리빌드
    final session = context.watch<SessionProvider>();
    final sessionId = session.sessionId;
    final fs = FirebaseFirestore.instance;

    if (hubId == null) {
      return AppScaffold(
        selectedIndex: 0,
        body: const Scaffold(
          backgroundColor: _kAppBg,
          body: Center(child: Text('허브가 선택되지 않았습니다.')),
        ),
      );
    }

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
                    // 상단 바
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Back',
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              sessionId == null
                                  ? 'No session'
                                  : 'Session • $sessionId',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        OutlinedButton(
                          onPressed: () => _openSessionMenu(context),
                          child: const Text('Session'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 본문
                    if (sessionId == null)
                      const Expanded(
                        child: Center(
                            child: Text(
                                'No session. Tap "Session" to create or load.')),
                      )
                    else
                      Expanded(
                        child: StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          stream: fs
                              .doc('hubs/$hubId/sessions/$sessionId')
                              .snapshots(),
                          builder: (context, sessSnap) {
                            final meta = sessSnap.data?.data();
                            final int cols =
                                (meta?['cols'] as num?)?.toInt() ?? 6;
                            final int rows =
                                (meta?['rows'] as num?)?.toInt() ?? 4;

                            final serverIntervals =
                                _parseRunIntervals(meta?['runIntervals']);

                            // === 디자인 캔버스(1280×720) 스케일/클리핑 래퍼 ===
                            return LayoutBuilder(
                              builder: (context, box) {
                                const designW = 1280.0;
                                const designH = 720.0;
                                final scaleW = box.maxWidth / designW;
                                final scaleH = box.maxHeight / designH;
                                final scaleFit =
                                    scaleW < scaleH ? scaleW : scaleH;

                                if (scaleFit < 1) {
                                  // 더 작아지면 축소 없이 잘라내기
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
                                        child: _DesignSurface(
                                          hubId: hubId,
                                          sessionId: sessionId!,
                                          cols: cols,
                                          rows: rows,
                                          serverIntervals: serverIntervals,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                // 더 크면 확대
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
                                        child: _DesignSurface(
                                          hubId: hubId,
                                          sessionId: sessionId!,
                                          cols: cols,
                                          rows: rows,
                                          serverIntervals: serverIntervals,
                                        ),
                                      ),
                                    ),
                                  ),
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

            // 수업 토글 FAB (서버 상태와 동기 표시)
            if (sessionId != null)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream:
                    fs.doc('hubs/$hubId/sessions/$sessionId').snapshots(),
                builder: (context, snap) {
                  final running =
                      (snap.data?.data()?['classRunning'] as bool?) ?? false;
                  return _ClassToggleFabImage(
                    running: running,
                    onTap: _toggleClassRunningServer,
                  );
                },
              ),

            // Busy overlay
            if (_busy)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
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
    );
  }

  // ============== 디자인 내부(1280×720) ==============
  Widget _DesignSurface({
    required String hubId,
    required String sessionId,
    required int cols,
    required int rows,
    required List<_RunInterval> serverIntervals,
  }) {
    // ── ⬇️ 추가: 세션이 바뀌면 기준 시각을 새로 잡음 (입장 이후만 인정)
    if (_enterSessionId != sessionId) {
      _enterSessionId = sessionId;
      _enterMs = DateTime.now().millisecondsSinceEpoch;
    }
    final sinceMs = _sinceMs;

    final fs = FirebaseFirestore.instance;

    bool isDuringRun(int ms) => _isDuringRunServer(ms, serverIntervals);

    return Center(
      child: Container(
        width: 1280,
        height: 720,
        color: Colors.transparent,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              fs.collection('hubs/$hubId/sessions/$sessionId/seatMap').snapshots(),
          builder: (context, seatSnap) {
            final Map<String, String?> seatMap = {};
            if (seatSnap.data != null) {
              for (final d in seatSnap.data!.docs) {
                seatMap[d.id] = (d.data()['studentId'] as String?)?.trim();
              }
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // ✅ students 를 hub 스코프로 유지
              stream: fs.collection('hubs/$hubId/students').snapshots(),
              builder: (context, stuSnap) {
                final Map<String, String> nameOf = {};
                if (stuSnap.data != null) {
                  for (final d in stuSnap.data!.docs) {
                    final x = d.data();
                    final n = (x['name'] as String?)?.trim();
                    if (n != null && n.isNotEmpty) nameOf[d.id] = n;
                  }
                }

                // ✅ liveByDevice + devices 매핑으로 버튼 최신 상태 계산
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      fs.collection('hubs/$hubId/liveByDevice').snapshots(),
                  builder: (context, liveSnap) {
                    final Map<String, Map<String, dynamic>> liveByDevice = {};
                    if (liveSnap.data != null) {
                      for (final d in liveSnap.data!.docs) {
                        liveByDevice[d.id] = d.data();
                      }
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: fs.collection('hubs/$hubId/devices').snapshots(),
                      builder: (context, devSnap) {
                        final Map<String, String> lastSlotByStudent = {};
                        final Map<String, int> lastMsByStudent = {};
                        final Map<String, String>
                            firstTouchColorByStudent = {}; // 'blue'|'gray'

                        if (devSnap.data != null) {
                          for (final d in devSnap.data!.docs) {
                            final devId = d.id;
                            final data = d.data();
                            final sid = (data['studentId'] as String?)?.trim();
                            if (sid == null || sid.isEmpty) continue;

                            // slotIndex from devices (can be '1'/'2' or int)
                            String? slot;
                            final rawSlot = data['slotIndex'];
                            if (rawSlot is num) {
                              slot = '${rawSlot.toInt()}';
                            } else if (rawSlot is String &&
                                rawSlot.trim().isNotEmpty) {
                              final s = rawSlot.trim();
                              if (s == '1' || s == '2') slot = s;
                            }
                            slot ??= '1'; // 기본값

                            final live = liveByDevice[devId];
                            if (live == null) continue;

                            final ms = _eventMs(live);
                            // ── ⬇️ 추가: 페이지 입장(sinceMs) 이전에 눌린 기록은 무시
                            if (ms <= 0 || ms < sinceMs) continue;

                            if (!lastMsByStudent.containsKey(sid) ||
                                ms > lastMsByStudent[sid]!) {
                              lastMsByStudent[sid] = ms;
                              lastSlotByStudent[sid] = slot;
                              firstTouchColorByStudent[sid] =
                                  isDuringRun(ms) ? 'gray' : 'blue';
                            }
                          }
                        }

                        // 상단 정보
                        final now = DateTime.now();
                        final weekdayStr = [
                          'SUN',
                          'MON',
                          'TUE',
                          'WED',
                          'THU',
                          'FRI',
                          'SAT'
                        ][now.weekday % 7];
                        final dateNumStr =
                            '${now.month.toString().padLeft(2, "0")}.${now.day.toString().padLeft(2, "0")}';
                        final totalSeats = cols * rows;
                        final assignedCount = seatMap.values
                            .where((v) => (v?.trim().isNotEmpty ?? false))
                            .length;

                        return Center(
                          child: SizedBox(
                            width: _kCardW,
                            height: _kCardH,
                            child: Container(
                              padding:
                                  const EdgeInsets.fromLTRB(28, 24, 28, 24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(_kCardRadius),
                                border: Border.all(
                                    color: _kCardBorder, width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 날짜 • Board • 합계
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: const HelpBadge(
                                      tooltip: 'Students can press the button on their seat to indicate their attendance.',
                                      placement: HelpPlacement.left, // 말풍선이 왼쪽으로 펼쳐지게
                                      // gap: 2, // 네가 쓰는 HelpBadge가 gap 지원하면 켜줘서 더 가깝게
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(weekdayStr,
                                              style: _weekdayTextStyle),
                                          const SizedBox(width: 8),
                                          Text(dateNumStr,
                                              style: _dateNumTextStyle),
                                        ],
                                      ),
                                      const Spacer(),
                                      const SizedBox(width: 32),  
                                      SizedBox(
                                        width: 680,
                                        height: 40,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: const Color.fromARGB(
                                                255, 211, 255, 110),
                                            borderRadius:
                                                BorderRadius.circular(12.05),
                                          ),
                                          child: const Center(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 16),
                                              child: Text(
                                                'Board',
                                                maxLines: 1,
                                                softWrap: false,
                                                overflow: TextOverflow.fade,
                                                textAlign: TextAlign.center,
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
                                      const Spacer(),
                                      SizedBox(
                                        width: 142, // 살짝 여유
                                        child: Text(
                                          '$assignedCount / $totalSeats',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 25.26,
                                            fontWeight: FontWeight.w700,
                                            height: 25 / 25.26,
                                            color: Color(0xFF001A36),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  // 좌석 그리드
                                  Expanded(
                                    child: _SeatGrid(
                                      cols: cols,
                                      rows: rows,
                                      seatMap: seatMap,
                                      nameOf: nameOf,
                                      lastSlotByStudent: lastSlotByStudent,
                                      fixedColorByStudent:
                                          firstTouchColorByStudent,
                                      onSeatTap: (i) =>
                                          _openSeatPicker(seatIndex: i),
                                    ),
                                  ),
                                ],
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
        ),
      ),
    );
  }

  // ===================== Session menu =====================
  Future<void> _openSessionMenu(BuildContext context) async {
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
                  onTap: () => Navigator.of(sheetCtx, rootNavigator: true)
                      .pop('new_empty'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: const Text('Load existing session'),
                  subtitle:
                      const Text('Switch to a saved session & layout'),
                  onTap: () => Navigator.of(sheetCtx, rootNavigator: true)
                      .pop('load_existing'),
                ),
                const Divider(height: 0),
                ListTile(
                  leading:
                      const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete current session (admin)'),
                  subtitle: const Text(
                      'Remove document + subcollections: events, seatMap, studentStats, stats.'),
                  onTap: () => Navigator.of(sheetCtx, rootNavigator: true)
                      .pop('purge'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    await _runNextFrame(() async {
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
    });
  }

  // ---------- New session ----------
  Future<void> _createEmptySession(BuildContext context) async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;

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
            builder: (context, setLocal) => AlertDialog(
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
                          onChanged: (v) =>
                              setLocal(() => cols = v.clamp(1, 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DialogStepper(
                          label: 'Rows',
                          value: rows,
                          onChanged: (v) =>
                              setLocal(() => rows = v.clamp(1, 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => _safeRootPop(false),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => _safeRootPop(true),
                    child: const Text('Create')),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true) return;

    final sid = ctrlSid.text.trim();
    if (sid.isEmpty) return;

    await _runNextFrame(() async {
      await _switchSessionAndBind(context, sid);
      await FirebaseFirestore.instance.doc('hubs/$hubId/sessions/$sid').set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'note': 'empty layout',
        'cols': cols,
        'rows': rows,
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Started new session: $sid ($cols×$rows)')));
    });
  }

  // ---------- Load existing ----------
  Future<void> _loadExistingSession(BuildContext context) async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;

    final sid = await _pickSessionId(context, title: 'Load session');
    if (sid == null) return;

    await _runNextFrame(() async {
      await _switchSessionAndBind(context, sid);
      await FirebaseFirestore.instance.doc('hubs/$hubId/sessions/$sid').set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Loaded session: $sid')));
    });
  }

  // ---------- Switch + bind + hub ----------
  Future<void> _switchSessionAndBind(
      BuildContext context, String sid) async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;

    final session = context.read<SessionProvider>();
    session.setSession(sid);
    await FirebaseFirestore.instance.doc('hubs/$hubId').set({
      'currentSessionId': sid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _saveLastSessionId(hubId, sid);
  }

  // ---------- helpers ----------
  Future<List<String>> _listRecentSessionIds({int limit = 50}) async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return [];
    final fs = FirebaseFirestore.instance;
    try {
      final snap =
          await fs.collection('hubs/$hubId/sessions').limit(limit).get();
      final docs = [...snap.docs];
      docs.sort((a, b) {
        final ta = (a.data()['updatedAt'] as Timestamp?);
        final tb = (b.data()['updatedAt'] as Timestamp?);
        final va = ta?.millisecondsSinceEpoch ?? 0;
        final vb = tb?.millisecondsSinceEpoch ?? 0;
        return vb.compareTo(va);
      });
      return docs.map((d) => d.id).toList();
    } catch (_) {
      final alt =
          await fs.collection('hubs/$hubId/sessions').limit(limit).get();
      return alt.docs.map((d) => d.id).toList();
    }
  }

  Future<String?> _pickSessionId(BuildContext context,
      {required String title}) async {
    final ids = await _listRecentSessionIds();
    if (ids.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No saved sessions.')));
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
                  itemBuilder: (_, i) => ListTile(
                    title: Text(ids[i]),
                    onTap: () => _safeRootPop(ids[i]),
                  ),
                ),
              ),
              TextButton(
                  onPressed: () => _safeRootPop(null),
                  child: const Text('Cancel')),
            ],
          ),
        );
      },
    );
  }

  Future<void> _purgeCurrentSession(BuildContext context) async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;

    final sid = context.read<SessionProvider>().sessionId;
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
          'hubs/$hubId/sessions/$sid\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => _safeRootPop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => _safeRootPop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      useRootNavigator: true,
    );

    try {
      await _deleteSessionFully(sid);
      final remain = await _listRecentSessionIds(limit: 50);
      if (remain.isNotEmpty) {
        final nextSid = remain.first;
        await _switchSessionAndBind(context, nextSid);
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Session "$sid" deleted. Switched to "$nextSid".')));
        }
      } else {
        final session = context.read<SessionProvider>();
        session.clear(); // nullable이면 사용
        await FirebaseFirestore.instance.doc('hubs/$hubId').set({
          'currentSessionId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Session deleted. No sessions left.')));
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _deleteCollection(
      FirebaseFirestore fs, String path, int batchSize) async {
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
  }

  String _defaultSessionId() {
    final now = DateTime.now();
    return '${now.toIso8601String().substring(0, 10)}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openSeatPicker({required int seatIndex}) async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;

    final fs = FirebaseFirestore.instance;
    final sid = context.read<SessionProvider>().sessionId;
    if (sid == null) return;

    final seatNo = _seatKey(seatIndex);

    // ✅ 학생 목록도 hub 스코프에서 로드
    final stuSnap = await fs.collection('hubs/$hubId/students').get();
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
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => _safeRootPop(true),
                  child: const Text('Save')),
            ],
          ),
        );
      },
    );

    if (ok == true) {
      try {
        await _assignSeatExclusive(seatNo: seatNo, studentId: selected);
        final name = selected == null
            ? 'Empty'
            // ✅ 이름 조회도 hub 스코프
            : ((await fs.doc('hubs/$hubId/students/$selected').get())
                    .data()?['name'] as String? ??
                selected);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Seat $seatNo → $name')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Assign failed: $e')));
      }
    }
  }

  Future<void> _assignSeatExclusive({
    required String seatNo,
    required String? studentId,
  }) async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;

    final sid = context.read<SessionProvider>().sessionId;
    if (sid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No session is set.')));
      return;
    }
    final fs = FirebaseFirestore.instance;
    final col = fs.collection('hubs/$hubId/sessions/$sid/seatMap');

    List<DocumentSnapshot<Map<String, dynamic>>> dupDocs = const [];
    if (studentId != null) {
      final qSnap =
          await col.where('studentId', isEqualTo: studentId).limit(50).get();
      dupDocs = qSnap.docs;
    }

    await fs.runTransaction((tx) async {
      for (final d in dupDocs) {
        if (d.id == seatNo) continue;
        final dr = col.doc(d.id);
        final latest = await tx.get(dr);
        final latestStudent = latest.data()?['studentId'] as String?;
        if (latest.exists && latestStudent == studentId) {
          tx.set(dr, {'studentId': null}, SetOptions(merge: true));
        }
      }
      final targetRef = col.doc(seatNo);
      tx.set(targetRef, {'studentId': studentId}, SetOptions(merge: true));
    });
  }
}

// ===== 좌석 상태(간소화: slot 목적 없이 탭 유무만) =====
enum _SeatState { empty, assignedAbsent, attended }

_SeatState _seatStateByPresence({
  required bool hasStudent,
  required bool tapped,
}) {
  if (!hasStudent) return _SeatState.empty;
  if (!tapped) return _SeatState.assignedAbsent;
  return _SeatState.attended;
}

/* ---------- Seat Grid ---------- */
class _SeatGrid extends StatelessWidget {
  const _SeatGrid({
    required this.cols,
    required this.rows,
    required this.seatMap,
    required this.nameOf,
    required this.lastSlotByStudent,
    required this.fixedColorByStudent,
    required this.onSeatTap,
  });

  final int cols;
  final int rows;
  final Map<String, String?> seatMap; // seatNo -> studentId?
  final Map<String, String> nameOf; // studentId -> name
  final Map<String, String> lastSlotByStudent; // studentId -> '1' | '2'
  final Map<String, String> fixedColorByStudent; // studentId -> 'gray' | 'blue'
  final ValueChanged<int> onSeatTap;

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
            final seatStudentId = seatMap[seatNo]?.trim();
            final hasStudent =
                seatStudentId != null && seatStudentId.isNotEmpty;
            final name =
                hasStudent ? (nameOf[seatStudentId!] ?? seatStudentId) : null;

            final tapped = hasStudent
                ? lastSlotByStudent.containsKey(seatStudentId!)
                : false;
            final state =
                _seatStateByPresence(hasStudent: hasStudent, tapped: tapped);

            // 색 계산 (폴백=연파랑, 절대 running으로 회색 강제 X)
            Color fillColor;
            if (!hasStudent) {
              fillColor = Colors.white;
            } else if (state == _SeatState.assignedAbsent) {
              fillColor = _kAssignedAbsent;
            } else {
              final fixed =
                  fixedColorByStudent[seatStudentId!]; // 'gray'|'blue'|null
              if (fixed == 'gray') {
                fillColor = _kDuringClassGray; // 수업 중 '누름'이었다면 회색
              } else {
                fillColor = _kAttendedBlue; // 그 외 기본 연파랑
              }
            }

            final isDark = fillColor.computeLuminance() < 0.5;
            final nameColor =
                isDark ? Colors.white : const Color(0xFF0B1324);
            final seatNoColor =
                isDark ? Colors.white70 : const Color(0xFF1F2937);
            final showDashed = (state == _SeatState.empty);

            final tile = LayoutBuilder(
              builder: (ctx, cc) {
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

                final contentBox = Container(
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(radius),
                    border: showDashed
                        ? null
                        : Border.all(color: Colors.transparent),
                  ),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                      horizontal: padH, vertical: padV),
                  child: hasStudent
                      ? FittedBox(
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

            return InkWell(onTap: () => onSeatTap(index), child: tile);
          },
        );
      },
    );
  }
}

/* ---------- 작은 UI들 ---------- */

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
              _roundBtn(Icons.remove,
                  onTap: () => onChanged((value - 1).clamp(1, 12))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('$value',
                    style:
                        const TextStyle(fontWeight: FontWeight.w800)),
              ),
              _roundBtn(Icons.add,
                  onTap: () => onChanged((value + 1).clamp(1, 12))),
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

/* ---------- dashes ---------- */
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
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = distance + dash > metric.length
            ? metric.length - distance
            : dash;
        final extract =
            metric.extractPath(distance, distance + len);
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

/* ---------- 수업 토글 FAB & 런 이력 ---------- */

class _RunInterval {
  _RunInterval(this.startMs, [this.endMs]);
  final int startMs;
  final int? endMs;
}

class _ClassToggleFabImage extends StatelessWidget {
  const _ClassToggleFabImage({
    required this.running,
    required this.onTap,
  });

  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ✅ 여기부터 수정: hover / click 애니메이션 버튼
              _MakeButton(
                scale: 1.0,
                imageAsset: running
                    ? 'assets/logo_bird_save.png'
                    : 'assets/logo_bird_begin.png',
                tooltip: running ? 'Stop class' : 'Start class',
                onTap: onTap,
              ),

              // 기존 HelpBadge 유지
              const Positioned(
                right: -2,
                top: -2,
                child: HelpBadge(
                  tooltip:
                      "Pressing BEGIN will mark students as late from that point onward. Pressing SAVE will save the attendance information for the current date and class.",
                  placement: HelpPlacement.left,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 🎨 공통 버튼 (hover + click 애니메이션)
class _MakeButton extends StatefulWidget {
  const _MakeButton({
    required this.scale,
    required this.imageAsset,
    required this.onTap,
    this.tooltip,
  });

  final double scale;
  final String imageAsset;
  final VoidCallback onTap;
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
    final scaleAnim = _down ? 0.98 : (_hover ? 1.03 : 1.0);

    final image = Image.asset(
      widget.imageAsset,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.error,
        size: 72,
        color: Colors.grey,
      ),
    );

    final content = widget.tooltip != null
        ? Tooltip(message: widget.tooltip!, child: image)
        : image;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: scaleAnim,
          child: SizedBox(width: w, height: h, child: content),
        ),
      ),
    );
  }
}
