// lib/pages/home/presenter_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Providers
import '../../provider/session_provider.dart';
import '../../provider/seat_map_provider.dart';
import '../../provider/students_provider.dart';
import '../../provider/debug_events_provider.dart';
import '../../provider/total_stats_provider.dart';
import '../../provider/student_stats_provider.dart';

const String kHubId = 'hub-001'; // your hub/classroom id

class PresenterHomePage extends StatefulWidget {
  @override
  State<PresenterHomePage> createState() => _PresenterHomePageState();
}

class _PresenterHomePageState extends State<PresenterHomePage> {
  bool _showLogs = false;
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

  // ====== logger helpers ======
  String _ts() => DateTime.now().toIso8601String();
  void _log(String msg) => debugPrint('[HOME ${_ts()}] $msg');

  // Seat doc ids: "1".."24"
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
        _log('ensureSessionOnStart: already bound to $currentSid -> clear events');
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
      await FirebaseFirestore.instance.doc('sessions/$sid').set(
        {'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

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
      await _deleteCollection(FirebaseFirestore.instance, 'sessions/$sid/events', 300);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session logs cleared.')),
      );
      _log('clearEventsForSession: done');
    } catch (e, st) {
      _log('clearEventsForSession ERROR: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear logs: $e')),
      );
    } finally {
      _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final sessionId = session.sessionId;

    final seatMapProvider = context.watch<SeatMapProvider>();
    final studentsProvider = context.watch<StudentsProvider>();
    final debugProvider = context.watch<DebugEventsProvider>();

    // 최신 이벤트 기반 좌석 색상 계산 (hubTs/ts 중 큰 값 기준)
    final Map<String, String> lastSlotByStudent = {};
    final Map<String, int> lastScoreByStudent = {};
    int scoreOf(ev) {
      final a = ev.hubTs ?? 0;
      final b = ev.ts?.millisecondsSinceEpoch ?? 0;
      return (a > b) ? a : b;
    }

    for (final ev in debugProvider.events) {
      final sid = ev.studentId;
      final slot = (ev.slotIndex == '1' || ev.slotIndex == '2') ? ev.slotIndex : null;
      if (sid == null || slot == null) continue;
      final s = scoreOf(ev);
      final prev = lastScoreByStudent[sid];
      if (prev == null || s > prev) {
        lastScoreByStudent[sid] = s;
        lastSlotByStudent[sid] = slot;
      }
    }

    Color _colorFor(String? slot) {
      if (slot == '2') return Colors.lightGreenAccent; // slot2=초록
      if (slot == '1') return Colors.redAccent;        // slot1=빨강
      return const Color(0xFF6063C6);                  // 기본
    }

    // 프레임마다 핵심 상태 로그
    _log('build: sid=$sessionId, seats=${seatMapProvider.seatMap.length}, '
         'students=${studentsProvider.students.length}, events=${debugProvider.events.length}');

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar (Back + Session + Logout)
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
                            sessionId == null ? 'No session' : 'Session • $sessionId',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              _log('Session button tapped');
                              _openSessionMenu(context);
                            },
                            child: const Text('Session'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              _log('Logout pressed -> pop route');
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Seat grid
                  Expanded(
                    child: GridView.builder(
                      itemCount: 24,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.8,
                      ),
                      itemBuilder: (context, index) {
                        final key = _seatKey(index);
                        final studentId = seatMapProvider.seatMap[key];
                        final displayName = studentId == null
                            ? 'Empty'
                            : studentsProvider.displayName(studentId);
                        final slot = studentId == null ? null : lastSlotByStudent[studentId];

                        return InkWell(
                          onTap: () => _openSeatPicker(seatIndex: index),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _colorFor(slot),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              displayName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Logs toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _log('Toggle logs -> ${!_showLogs}');
                          setState(() => _showLogs = !_showLogs);
                        },
                        icon: Icon(_showLogs ? Icons.expand_more : Icons.expand_less),
                        label: Text(_showLogs ? 'Hide logs' : 'Show logs'),
                      ),
                      if (_showLogs && debugProvider.hasMore)
                        TextButton(
                          onPressed: () {
                            _log('Load more logs');
                            context.read<DebugEventsProvider>().loadMore();
                          },
                          child: const Text('Load more'),
                        ),
                    ],
                  ),

                  if (_showLogs)
                    SizedBox(
                      height: 200,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: debugProvider.events.isEmpty
                            ? const Center(child: Text('No logs'))
                            : ListView.builder(
                                itemCount: debugProvider.events.length,
                                itemBuilder: (context, index) {
                                  final ev = debugProvider.events[index];
                                  final name = ev.studentId == null
                                      ? '(unknown)'
                                      : studentsProvider.displayName(ev.studentId!);
                                  final timeStr =
                                      ev.ts?.toDate().toLocal().toString() ?? '-';
                                  final slot = ev.slotIndex ?? '-';
                                  // deviceId 끝 5자리
                                  final tail5 = ev.deviceId.length > 5
                                      ? ev.deviceId.substring(ev.deviceId.length - 5)
                                      : ev.deviceId;
                                  return ListTile(
                                    dense: true,
                                    title: Text('$name (slot $slot • ${ev.clickType})'),
                                    subtitle: Text(
                                      'dev …$tail5 • hubTs=${ev.hubTs ?? 0} • $timeStr',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Provider pagination overlay (기존)
          if (debugProvider.isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                  title: const Text('New session (empty)'),
                  subtitle: const Text('Start fresh without seat layout'),
                  onTap: () {
                    _log('sheet tap: new_empty');
                    Navigator.of(sheetCtx, rootNavigator: true).pop('new_empty');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_all),
                  title: const Text('New session from previous'),
                  subtitle: const Text('Copy seat layout from a previous session'),
                  onTap: () {
                    _log('sheet tap: new_from_prev');
                    Navigator.of(sheetCtx, rootNavigator: true).pop('new_from_prev');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: const Text('Load existing session'),
                  subtitle: const Text('Switch to a saved session & layout'),
                  onTap: () {
                    _log('sheet tap: load_existing');
                    Navigator.of(sheetCtx, rootNavigator: true).pop('load_existing');
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete current session data (admin)'),
                  subtitle: const Text('Delete events, studentStats, and stats/summary'),
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
        case 'new_from_prev':
          await _createFromPrevious(context);
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

  // ---------- New session (empty) ----------
  Future<void> _createEmptySession(BuildContext context) async {
    _log('createEmptySession: open dialog');
    final controller = TextEditingController(text: _defaultSessionId());
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
            title: const Text('New session ID'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(onPressed: () => _safeRootPop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => _safeRootPop(true), child: const Text('Create')),
            ],
          ),
        );
      },
    );
    _log('createEmptySession: dialog result=$ok');
    if (ok != true) return;

    await _runNextFrame(() async {
      final sid = controller.text.trim();
      if (sid.isEmpty) {
        _log('createEmptySession: empty sid, abort');
        return;
      }
      _log('createEmptySession: switch/bind sid=$sid');
      await _switchSessionAndBind(context, sid);

      _log('createEmptySession: write sessions/$sid meta');
      await FirebaseFirestore.instance.doc('sessions/$sid').set(
        {
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'note': 'empty layout',
        },
        SetOptions(merge: true),
      );

      // 새 세션이어도 초기화 UX 일관성 유지 (no-op이어도 호출)
      await _clearEventsForSession(sid);

      if (!mounted) return;
      _log('createEmptySession: snackbar');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Started new session: $sid')),
      );
    });
  }

  // ---------- New session from previous ----------
  Future<void> _createFromPrevious(BuildContext context) async {
    _log('createFromPrevious: pick source dialog');
    final fromSid = await _pickSessionId(context, title: 'Pick source session');
    _log('createFromPrevious: picked=$fromSid');
    if (fromSid == null) return;

    await _runNextFrame(() async {
      _log('createFromPrevious: input target dialog');
      final toSid = await _inputSessionId(context, title: 'New session ID');
      _log('createFromPrevious: target=$toSid');
      if (toSid == null || toSid.trim().isEmpty) return;

      final target = toSid.trim();
      _log('createFromPrevious: switch/bind sid=$target');
      await _switchSessionAndBind(context, target);

      _log('createFromPrevious: copy seatMap $fromSid -> $target');
      await _copySeatMap(fromSid, target);

      _log('createFromPrevious: write sessions/$target meta');
      await FirebaseFirestore.instance.doc('sessions/$target').set(
        {
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'copiedFrom': fromSid,
        },
        SetOptions(merge: true),
      );

      // 새 세션 초기화 (대개 no-op)
      await _clearEventsForSession(target);

      if (!mounted) return;
      _log('createFromPrevious: snackbar');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('New session from "$fromSid": $target')),
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
      await FirebaseFirestore.instance.doc('sessions/$sid').set(
        {'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      // ▶ 다른 세션 로드 시에도 초기화
      await _clearEventsForSession(sid);

      if (!mounted) return;
      _log('loadExisting: snackbar');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded session: $sid')),
      );
    });
  }

  // ---------- Common: switch + bind + set hub ----------
  Future<void> _switchSessionAndBind(BuildContext context, String sid) async {
    _log('switchSessionAndBind: start sid=$sid');
    final session = context.read<SessionProvider>();

    SeatMapProvider? seatMap;
    DebugEventsProvider? debug;
    TotalStatsProvider? total;
    StudentStatsProvider? perStudent;
    try { seatMap = context.read<SeatMapProvider>(); } catch (_) {}
    try { debug = context.read<DebugEventsProvider>(); } catch (_) {}
    try { total = context.read<TotalStatsProvider>(); } catch (_) {}
    try { perStudent = context.read<StudentStatsProvider>(); } catch (_) {}

    session.setSession(sid);
    _log('switchSessionAndBind: session.setSession done');

    Future<void> _bindSafe(String name, FutureOr<void> Function() run) async {
      _log('bind start: $name');
      try {
        await Future.sync(run);
        _log('bind ok: $name');
      } catch (e, st) {
        _log('bind ERROR: $name -> $e\n$st');
        rethrow;
      }
    }

    await _bindSafe('seatMap', () => seatMap?.bindSession(sid));
    await _bindSafe('debug', () => debug?.bindSession(sid));
    await _bindSafe('total', () => total?.bindSession(sid));
    await _bindSafe('perStudent', () => perStudent?.bindSession(sid));
    _log('switchSessionAndBind: providers bound');

    // hub가 이 세션을 따라가도록
    await FirebaseFirestore.instance.doc('hubs/$kHubId').set(
      {
        'currentSessionId': sid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    _log('switchSessionAndBind: hub updated');
  }

  // ---------- Helpers ----------
  Future<void> _copySeatMap(String fromSid, String toSid) async {
    final fs = FirebaseFirestore.instance;
    final src = await fs.collection('sessions/$fromSid/seatMap').get();
    if (src.docs.isEmpty) {
      _log('copySeatMap: source empty');
      return;
    }
    final batch = fs.batch();
    for (final d in src.docs) {
      final data = d.data();
      batch.set(
        fs.doc('sessions/$toSid/seatMap/${d.id}'),
        {'studentId': data['studentId']},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    _log('copySeatMap: copied ${src.docs.length} seats');
  }

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

  Future<String?> _pickSessionId(BuildContext context, {required String title}) async {
    final ids = await _listRecentSessionIds();
    _log('pickSessionId: ${ids.length} items');
    if (ids.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved sessions.')),
      );
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
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _inputSessionId(BuildContext context, {required String title}) async {
    final ctrl = TextEditingController(text: _defaultSessionId());
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
            title: Text(title),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(onPressed: () => _safeRootPop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => _safeRootPop(true), child: const Text('OK')),
            ],
          ),
        );
      },
    );
    if (ok == true) return ctrl.text.trim();
    return null;
  }

  String _defaultSessionId() {
    final now = DateTime.now();
    return '${now.toIso8601String().substring(0, 10)}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  // 좌석 피커 (이름 중복 배정 방지 포함)
  Future<void> _openSeatPicker({required int seatIndex}) async {
    final seatMapProvider = context.read<SeatMapProvider>();
    final studentsProvider = context.read<StudentsProvider>();
    final seatNo = _seatKey(seatIndex);
    String? selected = seatMapProvider.seatMap[seatNo];

    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('— Empty —')),
      ...studentsProvider.students.entries.map(
        (e) => DropdownMenuItem<String?>(value: e.key, child: Text((e.value['name'] as String?) ?? e.key)),
      ),
    ];

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
              TextButton(onPressed: () => _safeRootPop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => _safeRootPop(true), child: const Text('Save')),
            ],
          ),
        );
      },
    );

    if (ok == true) {
      try {
        final newStudentId = selected;

        // 1) 동일 학생이 다른 좌석에 배정돼 있으면 그 좌석을 Empty로
        if (newStudentId != null) {
          String? otherSeatKey;
          seatMapProvider.seatMap.forEach((k, v) {
            if (k != seatNo && v == newStudentId) {
              otherSeatKey = k;
            }
          });
          if (otherSeatKey != null) {
            _log('assignSeat: "$newStudentId" already at seat=$otherSeatKey -> set Empty first');
            await seatMapProvider.assignSeat(otherSeatKey!, null);
          }
        }

        // 2) 현재 좌석에 최종 지정
        await seatMapProvider.assignSeat(seatNo, newStudentId);

        final name = newStudentId == null ? 'Empty' : studentsProvider.displayName(newStudentId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seat $seatNo → $name')),
        );
        _log('assignSeat OK: seat=$seatNo student=$newStudentId');
      } catch (e, st) {
        _log('assignSeat ERROR: $e\n$st');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assign failed: $e')),
        );
      }
    }
  }

  // ====== Admin purge ======
  Future<void> _purgeCurrentSession(BuildContext context) async {
    final sid = context.read<SessionProvider>().sessionId;
    _log('purge: start (sid=$sid)');
    if (sid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No session is set.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        title: const Text('Delete current session data'),
        content: Text(
          'This will delete events, studentStats, and stats/summary under '
          'sessions/$sid. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => _safeRootPop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => _safeRootPop(true), child: const Text('Delete')),
        ],
      ),
    );
    _log('purge: confirm result=$ok');
    if (ok != true) return;

    _log('purge: show overlay(dialog)');
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      useRootNavigator: true,
    );

    final fs = FirebaseFirestore.instance;
    try {
      _log('purge: delete events');
      await _deleteCollection(fs, 'sessions/$sid/events', 300);
      _log('purge: delete studentStats');
      await _deleteCollection(fs, 'sessions/$sid/studentStats', 300);

      final statsDoc = fs.doc('sessions/$sid/stats/summary');
      final exists = await statsDoc.get();
      if (exists.exists) {
        _log('purge: delete stats/summary');
        await statsDoc.delete();
      }

      if (!mounted) return;
      _log('purge: close overlay + snackbar OK');
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current session data deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      _log('purge: close overlay + snackbar ERROR: $e');
      Navigator.of(context, rootNavigator: true).pop();
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
}
