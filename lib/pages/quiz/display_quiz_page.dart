// lib/pages/quiz/display_quiz_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';

const Color kWaitingBgColor = Color.fromARGB(255, 246, 250, 255);
const String kWaitingImageAsset = 'assets/logo_bird_main.png';

const kQuizBarColor = Color(0xFFA9E817);

const bool kCompactReveal = true;

class DisplayQuizPage extends StatefulWidget {
  const DisplayQuizPage({super.key});

  @override
  State<DisplayQuizPage> createState() => _DisplayQuizPageState();
}

class _DisplayQuizPageState extends State<DisplayQuizPage> {
  late final DateTime _openedAt = DateTime.now();
  static const Duration _clockSkew = Duration(seconds: 3);

  bool _isFreshFrom(Timestamp? ts) {
    if (ts == null) return false;
    return ts.toDate().isAfter(_openedAt.subtract(_clockSkew));
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    // 허브 경로
    final hubPath = context.watch<HubProvider>().hubDocPath;
    // 무조건 허브가 있어야 진행
    if (hubPath == null) {
      return const Scaffold(body: _WaitingScreen());
    }

    // 단일 정렬(인덱스 부담↓), 최신 것부터 50개만
    final stream =
        fs
            .collection('$hubPath/quizTopics')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _WaitingScreen();
          }
          if (snap.hasError) {
            return _errorView('Quiz stream error: ${snap.error}');
          }
          final docs = snap.data?.docs ?? const [];

          if (docs.isEmpty) {
            return const _WaitingScreen();
          }

          // 1) running 중인 토픽 중 "가장 최근" 것을 표시
          final running =
              docs
                  .where((d) => (d.data()['status'] as String?) == 'running')
                  .toList()
                ..sort((a, b) {
                  final sa = a.data()['questionStartedAt'] as Timestamp?;
                  final sb = b.data()['questionStartedAt'] as Timestamp?;
                  final va = sa?.millisecondsSinceEpoch ?? 0;
                  final vb = sb?.millisecondsSinceEpoch ?? 0;
                  return vb.compareTo(va);
                });

          if (running.isNotEmpty) {
            final d = running.first;
            final x = d.data();
            final phase = (x['phase'] as String?) ?? 'finished';
            final currentQuizId = x['currentQuizId'] as String?;
            final title = (x['title'] as String?) ?? '';

            if (phase == 'finished' || currentQuizId == null) {
              return const _WaitingScreen();
            }

            // 시작 기준 시각(ms) 확보: questionStartedAtMs → fallback questionStartedAt
            final startMs =
                (x['questionStartedAtMs'] is num)
                    ? (x['questionStartedAtMs'] as num).toInt()
                    : ((x['questionStartedAt'] is Timestamp)
                        ? (x['questionStartedAt'] as Timestamp)
                            .millisecondsSinceEpoch
                        : null);

            // 가능하면 세션ID도 넘겨서 필터 정확도↑
            final sessionId = (x['sessionId'] as String?)?.trim();

            return _ActiveQuizView(
              topicId: d.id,
              title: title,
              phase: phase, // 'question' | 'reveal'
              currentQuizId: currentQuizId,
              startMs: startMs,
              sessionId: sessionId,
            );
          }

          // 2) running이 없고 디스플레이 요약 요청이 신선하면 표시
          final showSummary =
              docs.where((d) {
                  final x = d.data();
                  final want = (x['showSummaryOnDisplay'] as bool?) == true;
                  if (!want) return false;
                  final updated = x['updatedAt'] as Timestamp?;
                  return _isFreshFrom(updated);
                }).toList()
                ..sort((a, b) {
                  final ua = a.data()['updatedAt'] as Timestamp?;
                  final ub = b.data()['updatedAt'] as Timestamp?;
                  final va = ua?.millisecondsSinceEpoch ?? 0;
                  final vb = ub?.millisecondsSinceEpoch ?? 0;
                  return vb.compareTo(va);
                });

          if (showSummary.isNotEmpty) {
            final d = showSummary.first;
            final title = (d.data()['title'] as String?) ?? '';
            return _SummaryView(topicId: d.id, title: title);
          }

          // 3) 그 외는 대기화면
          return const _WaitingScreen();
        },
      ),
    );
  }

  Widget _errorView(String msg) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Text(
        msg,
        style: const TextStyle(color: Colors.redAccent),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 대기 화면
class _WaitingScreen extends StatelessWidget {
  const _WaitingScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kWaitingBgColor,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              kWaitingImageAsset,
              errorBuilder:
                  (_, __, ___) => const Icon(
                    Icons.hourglass_top,
                    color: Colors.white70,
                    size: 100,
                  ),
            ),
            const SizedBox(height: 20),
            const Text(
              '잠시 후 퀴즈가 시작됩니다…',
              style: TextStyle(
                color: Colors.white70,
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


/// 진행 중 화면(문제/리빌)
class _ActiveQuizView extends StatefulWidget {
  const _ActiveQuizView({
    required this.topicId,
    required this.title,
    required this.phase,
    required this.currentQuizId,
    required this.startMs,
    required this.sessionId,
  });

  final String topicId;
  final String title;
  final String phase; // 'question' | 'reveal'
  final String currentQuizId;
  final int? startMs; // ★ liveByDevice 필터 기준
  final String? sessionId; // ★ 있으면 정확도↑

  

  @override
  State<_ActiveQuizView> createState() => _ActiveQuizViewState();
}

class _Ev {
  final int score;
  final int button;
  final String gesture;
  _Ev({required this.score, required this.button, required this.gesture});
}

class _Opt {
  final String label;
  final int button;
  final String gesture;
  final int votes;
  _Opt({required this.label, required this.button, required this.gesture, this.votes = 0});

  _Opt copyWith({int? votes}) =>
      _Opt(label: label, button: button, gesture: gesture, votes: votes ?? this.votes);
}

class _ActiveQuizViewState extends State<_ActiveQuizView> {
  static final Map<String, int> _lastProcessedTs = {};

  String? _lastQuizIdShown;
  String? _lastSkippedQuizId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _liveSub;
  Map<String, Set<String>>? _deviceVotedSlots;
  final Map<String, Map<String, dynamic>> _quizCache = {};

  Duration? _remaining; // ← null이면 타이머 표시 안 함
  Timer? _timer;
  bool _isTimerRunning = false;
  int? _timerTotalSeconds; // Firestore에서 불러온 원래 설정값
  int _currentIndex = 1;
  int _totalCount = 1;

  Color _colorForBinding(int button, String gesture) {
  if (button == 1) {
    return const Color(0xff70D71C); // 초록
  } else {
    return const Color(0xff9A6EFF); // 보라
  }
}

  List<_Opt> _opts = []; // 선택지별 상태 리스트
int _total = 0;  

  // 마지막 퀴즈인지 판별
  bool get _isLastQuiz => _currentIndex >= _totalCount;

 @override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final hubPath = context.read<HubProvider>().hubDocPath;
    if (hubPath == null) return;

    _liveSub = FirebaseFirestore.instance
        .collection('$hubPath/liveByDevice')
        .snapshots()
        .listen(_handleLiveEvent);
  });
}

  @override
  void dispose() {
    _liveSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<Map<String, String?>> _loadRunContext(String hubId) async {
  final topicSnap = await FirebaseFirestore.instance
      .doc('hubs/$hubId/quizTopics/${widget.topicId}')
      .get();

  final data = topicSnap.data() ?? {};
  return {
    'sessionId': (data['sessionId'] as String?)?.trim(),
    'runId': (data['activeRunId'] as String?)?.trim(),
  };
}

Future<void> _saveResponsesToRun({
  required String hubId,
  required String quizId,
  required List options,
  required Map<String, Set<String>> votesByStudent,
}) async {
  final ctx = await _loadRunContext(hubId);
  final sessionId = ctx['sessionId'];
  final runId = ctx['runId'];

  if (sessionId == null || sessionId.isEmpty || runId == null || runId.isEmpty) {
    debugPrint('⚠️ responses save skipped: sessionId/activeRunId missing');
    return;
  }

  final fs = FirebaseFirestore.instance;
  final batch = fs.batch();

  for (final entry in votesByStudent.entries) {
    final studentId = entry.key;
    final selectedKeys = entry.value;

    // 단일선택 기준에서는 Set에 1개만 있음
    // 다중선택이면 여러 개일 수 있는데, 지금 통계 구조는 selectedIndex 1개 기준이므로
    // 우선 첫 번째 것만 저장
    if (selectedKeys.isEmpty) continue;

    final selectedKey = selectedKeys.first;
    final selectedIndex = options.indexWhere((opt) {
      final b = (opt['binding'] as Map?) ?? {};
      final btn = b['button']?.toString();
      final ges = (b['gesture'] ?? 'single').toString();
      return selectedKey == '${btn}_${ges}';
    });

    if (selectedIndex < 0) continue;

    final responseRef = fs.doc(
      'hubs/$hubId/sessions/$sessionId/quizRuns/$runId/responses/${quizId}_$studentId',
    );

    batch.set(responseRef, {
      'topicId': widget.topicId,
      'quizId': quizId,
      'studentId': studentId,
      'selectedIndex': selectedIndex,
      'selectedTitle': ((options[selectedIndex] as Map)['title'] ?? '').toString(),
      'answeredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  await batch.commit();
}

   void _handleLiveEvent(QuerySnapshot<Map<String, dynamic>> snap) async {
  if (snap.docs.isEmpty) return;

  final hubId = context.read<HubProvider>().hubId;
  if (hubId == null) return;

  final fs = FirebaseFirestore.instance;
  final topicRef = fs.doc('hubs/$hubId/quizTopics/${widget.topicId}');
  final topicSnap = await topicRef.get();
  final topicData = topicSnap.data();
  final status = (topicData?['status'] ?? '').toString();
  final phase = (topicData?['phase'] ?? '').toString(); // ✅ 추가

  // ✅ 1️⃣ status가 running이 아니면 집계 중단
  if (status != 'running') return;

  // ✅ 2️⃣ phase가 reveal이면 집계 중단
  if (phase == 'reveal') {
    debugPrint('🟡 Display: reveal phase → 집계 중단');
    return;
  }

  

  // 🔹 현재 퀴즈 정보
  final quizRef = fs.doc(
      'hubs/$hubId/quizTopics/${widget.topicId}/quizzes/${widget.currentQuizId}');
  final quizSnap = await quizRef.get();
  
  if (!quizSnap.exists) return;

  final quizData = quizSnap.data()!;
  final List options = (quizData['options'] as List?) ?? const [];
  final bool allowMultiple = quizData['allowMultiple'] == true;

  // 🔹 학생 단위 마지막 이벤트 저장 (vote와 동일 구조)
  final Map<String, _Ev> lastByStudent = {};
  for (final d in snap.docs) {
    final x = d.data();
    final studentId = (x['studentId'] ?? '').toString();
    if (studentId.isEmpty) continue;

    final slotIndex = x['slotIndex']?.toString();
    final clickTypeRaw =
        (x['clickType'] ?? '').toString().toLowerCase().trim();
    final lastHubTs = (x['lastHubTs'] as num?)?.toInt() ?? 0;

    if (slotIndex == null || slotIndex.isEmpty) continue;
    if (widget.startMs != null && lastHubTs < widget.startMs!) continue;
    if (clickTypeRaw != 'click' && clickTypeRaw != 'hold') continue;

    final cur = lastByStudent[studentId];
    if (cur == null || lastHubTs > cur.score) {
      lastByStudent[studentId] = _Ev(
        score: lastHubTs,
        button: int.tryParse(slotIndex) ?? 1,
        gesture: clickTypeRaw == 'hold' ? 'hold' : 'single',
      );
    }
  }

  // 🔹 다중선택 모드일 경우, 한 학생의 두 버튼 모두 반영
  // 🔹 단일선택 모드일 경우, 가장 마지막 이벤트만 반영
  final Map<String, Set<String>> votesByStudent = {};
  for (final entry in lastByStudent.entries) {
    final studentId = entry.key;
    final ev = entry.value;
    final key = '${ev.button}_${ev.gesture}';

    if (!votesByStudent.containsKey(studentId)) {
      votesByStudent[studentId] = {};
    }

    if (allowMultiple) {
      votesByStudent[studentId]!.add(key);
    } else {
      // 단일선택 모드면 이전 선택 제거하고 덮어씀
      votesByStudent[studentId]!
        ..clear()
        ..add(key);
    }
  }

  // 🔹 옵션별 집계
  final counts = List<int>.filled(options.length, 0);
  for (final studentEntry in votesByStudent.entries) {
    for (final key in studentEntry.value) {
      final idx = options.indexWhere((opt) {
        final b = (opt['binding'] as Map?) ?? {};
        final btn = b['button']?.toString();
        final ges = (b['gesture'] ?? 'single').toString();
        return key == '${btn}_${ges}';
      });
      if (idx >= 0 && idx < counts.length) {
        counts[idx]++;
      }
    }
  }

  // 🔹 UI 갱신
  if (!mounted) return;
  setState(() {
    if (_opts.length != options.length) {
      _opts = List.generate(options.length, (i) {
        final opt = options[i];
        final b = (opt['binding'] as Map?) ?? {};
        return _Opt(
          label: (opt['title'] ?? '').toString(),
          button: int.tryParse(b['button']?.toString() ?? '1') ?? 1,
          gesture: (b['gesture'] ?? 'single').toString(),
        );
      });
    }

    for (int i = 0; i < options.length && i < counts.length; i++) {
      _opts[i] = _opts[i].copyWith(votes: counts[i]);
    }

    // ✅ 총 투표자 수: 한 번이라도 버튼 누른 “학생”의 수
    _total = votesByStudent.keys.length;
  });

  final votesByDevice = <String, dynamic>{};
  for (final entry in votesByStudent.entries) {
    final studentId = entry.key;
    final selectedKeys = entry.value.toList();
    if (selectedKeys.isEmpty) continue;
    votesByDevice[studentId] = selectedKeys.first;
  }

  // 1) 기존 votes 저장 유지
  await FirebaseFirestore.instance
      .doc('hubs/$hubId/quizTopics/${widget.topicId}/quizzes/${widget.currentQuizId}')
      .set({
    'votes': counts,
    'votesByDevice': votesByDevice,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  // 2) 통계용 responses 저장 추가
  await _saveResponsesToRun(
    hubId: hubId,
    quizId: widget.currentQuizId,
    options: options,
    votesByStudent: votesByStudent,
  );
}





  Widget _quizBarRow({
    required String label,
    required int votes,
    required int total,
    required bool hideResults,
    required int button,          // ✅ 추가
    required String gesture,
    bool isRevealPhase = false, // ✅ phase 구분용
    bool isMax = false, // ✅ 최다 득표 구분용
  }) {
    final double ratio = (!hideResults && total > 0) ? (votes / total) : 0.0;
    final String percentText =
        hideResults ? '—' : (total == 0 ? '0%' : '${(ratio * 100).round()}%');

    // ✅ bar 색상
    final Color barColor =
        hideResults
            ? Colors.transparent
            : (isRevealPhase
                ? (isMax ? kQuizBarColor : const Color(0xFFA2A2A2)) // 리빌 중
                : kQuizBarColor); // 투표 중

    // ✅ 퍼센트 텍스트 스타일
    final TextStyle percentStyle =
        (isRevealPhase && isMax)
            ? const TextStyle(
              color: Colors.black,
              fontSize: 26,
              fontWeight: FontWeight.w600,
              height: 1.21,
            )
            : const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.black87,
            );

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.black12.withOpacity(0.12)),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final maxW = c.maxWidth;
                final fillW = (maxW * ratio).clamp(0.0, maxW);
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (fillW > 0)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: fillW,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                    Positioned(
                      left: 12,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: votes > 0 ? barColor : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          const SizedBox(width: 34),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                                color: Colors.black,
                              ),
                            ),
                          ),
const SizedBox(width: 12),

    // ✅ 여기에 추가 ↓↓↓↓↓
    Builder(builder: (context) {
      final color = _colorForBinding(button, gesture);
      final isHold = (gesture == 'hold');
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isHold ? 80 : 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.7)),
        ),
        child: isHold
            ? const Text(
                'hold',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              )
            : null,
      );
    }),

                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Text(
            percentText,
            textAlign: TextAlign.right,
            style: percentStyle,
          ),
        ),
      ],
    );
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    _timerTotalSeconds = seconds;
    _remaining = Duration(seconds: seconds);
    _isTimerRunning = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining == null) return;
      if (_remaining!.inSeconds <= 1) {
        t.cancel();
        setState(() {
          _remaining = Duration.zero;
          _isTimerRunning = false;
        });
      } else {
        setState(() {
          _remaining = Duration(seconds: _remaining!.inSeconds - 1);
        });
      }
    });
  }

  String get _formattedTime {
    if (_remaining == null) return '';
    final m = _remaining!.inMinutes;
    final s = _remaining!.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final hubPath = context.read<HubProvider>().hubDocPath;
    if (hubPath == null) return const _WaitingScreen();

    // 총 학생 수 스트림
    final studentsStream = fs.collection('$hubPath/students').snapshots();

    final topicStream =
        fs.doc('$hubPath/quizTopics/${widget.topicId}').snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: studentsStream,
      builder: (context, stuSnap) {
        final totalStudents = stuSnap.data?.docs.length ?? 0;
        final quizRef = fs.doc(
          '$hubPath/quizTopics/${widget.topicId}/quizzes/${widget.currentQuizId}',
        );

        return Stack(
          children: [
            if (widget.phase == 'question')
              _buildQuestionPhase(fs, hubPath, quizRef, totalStudents)
            else
              _buildRevealPhase(fs, hubPath, quizRef, totalStudents),
            Positioned(
              top: 32,
              left: 32,
              right: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ✅ 타이머 설정이 있을 때만 표시
                  if (_remaining != null &&
                      _timerTotalSeconds != null &&
                      _timerTotalSeconds! > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.alarm_outlined,
                          color: Color(0xFF001A36),
                          size: 42,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formattedTime,
                          style: const TextStyle(
                            color: Color(0xFF001A36),
                            fontSize: 42,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(), // ✅ 아무것도 표시하지 않음
                  // 🔢 오른쪽: 현재 문제 / 전체 문항
                  Text(
                    '$_currentIndex / $_totalCount',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF001A36),
                      fontSize: 42,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _skipToNextPublicQuiz(
    FirebaseFirestore fs,
    String hubPath,
  ) async {
    try {
      final topicRef = fs.collection('$hubPath/quizTopics').doc(widget.topicId);
      final quizCol = fs.collection(
        '$hubPath/quizTopics/${widget.topicId}/quizzes',
      );
      final qs = await quizCol.orderBy('createdAt').get();

      bool foundCurrent = false;
      String? nextPublicId;

      for (final doc in qs.docs) {
        if (doc.id == widget.currentQuizId) {
          foundCurrent = true;
          continue;
        }
        if (foundCurrent && (doc.data()['public'] == true)) {
          nextPublicId = doc.id;
          break;
        }
      }

      // 다음 public 문항이 있으면 그걸로 교체
      if (nextPublicId != null) {
        await topicRef.update({
          'currentQuizId': nextPublicId,
          'questionStartedAt': FieldValue.serverTimestamp(),
          'questionStartedAtMs': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 마지막까지 다 비공개면 종료 처리
        // await topicRef.update({'phase': 'finished', 'status': 'finished'});
      }
    } catch (e) {
      debugPrint('❌ skipToNextPublicQuiz error: $e');
    }
  }

  Widget _buildQuestionPhase(
  FirebaseFirestore fs,
  String hubPath,
  DocumentReference<Map<String, dynamic>> quizRef,
  int totalStudents,
) {
  final quizStream =
      fs.doc('$hubPath/quizTopics/${widget.topicId}/quizzes/${widget.currentQuizId}').snapshots();

  final topicStream = fs.doc('$hubPath/quizTopics/${widget.topicId}').snapshots();

  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: topicStream,
    builder: (context, topicSnap) {
      final topicData = topicSnap.data?.data();
      if (topicData == null) return const _WaitingScreen();

      _currentIndex = (topicData['currentQuizIndex'] as num?)?.toInt() ?? 1;

      final quizCol = fs.collection('$hubPath/quizTopics/${widget.topicId}/quizzes');
      quizCol.where('public', isEqualTo: true).get().then((qs) {
        if (mounted) {
          setState(() {
            _totalCount = qs.docs.length;
          });
        }
      });

      final timerSec = (topicData['timerSeconds'] as num?)?.toInt();

      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: quizStream,
        builder: (context, quizSnap) {
          if (!quizSnap.hasData) return const _WaitingScreen();
          final qx = quizSnap.data!.data();
          if (qx == null) return const _WaitingScreen();

          final isPublic = qx['public'] == true;
          if (!isPublic) {
            unawaited(_skipToNextPublicQuiz(fs, hubPath));
            return const _WaitingScreen();
          }

          // ✅ 데이터 구조 수정된 부분
          final question = (qx['question'] as String?) ?? '';
          final List options = (qx['options'] as List?) ?? [];
final List<int> votes =
    (qx['votes'] as List?)?.map((e) => (e as num).toInt()).toList()
    ?? List<int>.filled(options.length, 0);

// 로컬 집계 사용 여부 판단
final bool useLocal = (_opts.length == options.length);
final List<int> displayedVotes = useLocal
    ? _opts.map((e) => e.votes).toList()
    : votes;

// 총합(퍼센트 계산용)과 VOTERS 카운트
final int displayedTotal = useLocal
    ? _total                               // 로컬: 실제 투표한 디바이스 수
    : (votes.isEmpty ? 0 : votes.reduce((a, b) => a + b)); // Firestore fallback

          final total = votes.isEmpty ? 0 : votes.reduce((a, b) => a + b);

          final showResultsMode =
              (topicData['showResultsMode'] as String?) ?? 'afterEnd';
          final hide = showResultsMode != 'realtime';

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 95, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      question.isEmpty ? 'Untitled question' : question,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 41,
                        fontWeight: FontWeight.w500,
                        color: Colors.black, 
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        hide ? '—' : '$displayedTotal VOTERS',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12.withOpacity(0.08)),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Column(
                        children: [
                          if (hide)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Results will be shown after voting ends',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          // ✅ choices → options
                          ...options.asMap().entries.map((entry) {
  final i = entry.key;
  final opt = entry.value;

  final binding = (opt['binding'] as Map?) ?? {};
  final btn = int.tryParse(binding['button']?.toString() ?? '1') ?? 1;
  final ges = (binding['gesture'] ?? 'single').toString();

  return Padding(
    padding: EdgeInsets.only(bottom: i != options.length - 1 ? 12 : 0),
    child: _quizBarRow(
      label: (opt['title'] ?? '') as String,
      votes: (i < displayedVotes.length) ? displayedVotes[i] : 0,
      total: displayedTotal,
      hideResults: hide,
      button: btn,
      gesture: ges,
    ),
  );
}).toList(),

                        ],
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
}


  Widget _buildRevealPhase(
  FirebaseFirestore fs,
  String hubPath,
  DocumentReference<Map<String, dynamic>> quizRef,
  int totalStudents,
) {
  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: quizRef.snapshots(),
    builder: (context, quizSnap) {
      final qx = quizSnap.data?.data();
      if (qx == null) return const _WaitingScreen();

      if ((qx['public'] as bool?) == false) {
        return const _WaitingScreen();
      }

      // ✅ 구조 수정
      final question = (qx['question'] ?? '') as String;
      final List options = (qx['options'] as List?) ?? [];
      final List<int> votes =
          (qx['votes'] as List?)?.map((e) => (e as num).toInt()).toList() ??
          List<int>.filled(options.length, 0);

      final correctBinding = (qx['correctBinding'] as Map?) ?? {};
      final correctKey = '${correctBinding['button']}_${correctBinding['gesture']}';

      final Map<String, dynamic> votersMap =
          Map<String, dynamic>.from((qx['votesByDevice'] as Map?) ?? const {});
      final int totalVoters = votersMap.keys.toSet().length;

      final total = votes.isEmpty ? 0 : votes.reduce((a, b) => a + b);

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 95, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  question.isEmpty ? 'Untitled question' : question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 41,
                    fontWeight: FontWeight.w500,
                    color: Colors.black, 
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$totalVoters VOTERS',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                      color: Colors.black, 
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12.withOpacity(0.08)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    children: [
                      ...options.asMap().entries.map((entry) {
  final i = entry.key;
  final opt = entry.value;

  final binding = (opt['binding'] as Map?) ?? {};
  final btn = int.tryParse(binding['button']?.toString() ?? '1') ?? 1;
  final ges = (binding['gesture'] ?? 'single').toString();

  return Padding(
    padding: EdgeInsets.only(bottom: i != options.length - 1 ? 12 : 0),
    child: _quizBarRow(
      label: (opt['title'] ?? '') as String,
      votes: votes[i],
      total: total,
      hideResults: false,
      isRevealPhase: true,
      isMax: correctKey ==
          '${binding['button']}_${binding['gesture']}',
      button: btn,
      gesture: ges,
    ),
  );
}).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
}

/// 종료 후 결과 요약(명시적으로 요청된 경우에만)
class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.topicId, required this.title});
  final String topicId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    final hubPath = context.watch<HubProvider>().hubDocPath;
    if (hubPath == null) {
      return const _WaitingScreen();
    }

    final quizzesStream =
        fs
            .collection('$hubPath/quizTopics/$topicId/quizzes')
            .where('public', isEqualTo: true)
            .orderBy('createdAt')
            .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: quizzesStream,
      builder: (context, qsnap) {
        final quizzes = qsnap.data?.docs ?? const [];
        if (quizzes.isEmpty) {
          return const _WaitingScreen();
        }
        return Container(
          color: const Color(0xFFF7F9FC),
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(48, 32, 48, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title.isEmpty ? 'Quiz Results' : '$title • Results',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ...List.generate(quizzes.length, (i) {
                      final qDoc = quizzes[i];
                      final q = qDoc.data();
                      final quizId = qDoc.id;
                      final question = (q['question'] as String?) ?? '';
                      final List options = (q['options'] as List?) ?? [];
                      final List<String> optionTitles = options
                          .map((opt) => (opt['title'] ?? '').toString())
                          .toList();

                      // ✅ correctBinding 기반으로 정답 매칭
                      // final correctBinding = (q['correctBinding'] as Map?) ?? {};
                      // final correctKey =
                      //     '${correctBinding['button']}_${correctBinding['gesture']}';
                      // final isCorrect = key == correctKey;
                      final bool isCorrect = false;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>
                        >(
                          stream:
                              fs
                                  .doc(
                                    '$hubPath/quizTopics/$topicId/results/$quizId',
                                  )
                                  .snapshots(),
                          builder: (context, rsnap) {
                            final counts =
                                (rsnap.data?.data()?['counts'] as List?)
                                    ?.map((e) => (e as num).toInt())
                                    .toList() ??
                                List<int>.filled(optionTitles.length, 0);
                            final total =
                                counts.isEmpty
                                    ? 0
                                    : counts.reduce((a, b) => a + b);

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(
                                  color: Color(0xFFDAE2EE),
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  20,
                                  24,
                                  20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Q${i + 1}. $question',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 24,
                                        height: 1.25,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 14),
                                    ...List.generate(optionTitles.length, (ci) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _resultRow(
                                          label:
                                              '${String.fromCharCode(65 + ci)}. ${optionTitles[ci]}',
                                          value:
                                              counts.length > ci
                                                  ? counts[ci]
                                                  : 0,
                                          total: total,
                                          isCorrect: isCorrect,
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _resultRow({
    required String label,
    required int value,
    required int total,
    required bool isCorrect,
  }) {
    final ratio = total == 0 ? 0.0 : (value / total);
    final barColor = isCorrect ? Colors.green : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isCorrect)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.check_circle, color: Colors.green, size: 26),
              ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color:
                      isCorrect
                          ? Colors.green.shade700
                          : const Color(0xFF0B1324),
                  height: 1.2,
                ),
              ),
            ),
            Text(
              ' ${value}명',
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 16,
            color: barColor,
            backgroundColor: barColor.withOpacity(0.15),
          ),
        ),
      ],
    );
  }
}
