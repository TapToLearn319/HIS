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

  // 마지막 퀴즈인지 판별
  bool get _isLastQuiz => _currentIndex >= _totalCount;

  @override
  void initState() {
    super.initState();

    final fs = FirebaseFirestore.instance;
    final hubPath = context.read<HubProvider>().hubDocPath;
    print('🧩 hubPath in quiz display: $hubPath');
    if (hubPath != null) {
      _liveSub = fs
          .collection('$hubPath/liveByDevice')
          .snapshots()
          .listen(_handleLiveEvent);
    }
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _handleLiveEvent(QuerySnapshot<Map<String, dynamic>> snap) async {
    if (widget.phase == 'reveal') return; // 결과 공개 중엔 투표 차단
    if (snap.docs.isEmpty) return;

    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;

    final fs = FirebaseFirestore.instance;

    for (final doc in snap.docs) {
      final data = doc.data();
      final deviceId = doc.id;
      final slotIndex = data['slotIndex']?.toString();
      final clickTypeRaw =
          (data['clickType'] ?? '').toString().toLowerCase().trim();
      final lastHubTs = (data['lastHubTs'] as num?)?.toInt() ?? 0;

      if (clickTypeRaw.isEmpty ||
          !(clickTypeRaw == 'click' || clickTypeRaw == 'hold'))
        continue;
      if (slotIndex == null || slotIndex.isEmpty) continue;
      if (widget.startMs != null && lastHubTs < widget.startMs!) continue;

      if (_lastProcessedTs[deviceId] == lastHubTs) continue;
      _lastProcessedTs[deviceId] = lastHubTs;

      final topicId = widget.topicId;
      final quizId = widget.currentQuizId;
      if (topicId.isEmpty || quizId.isEmpty) continue;

      final deviceRef = fs.doc('hubs/$hubId/devices/$deviceId');
      final locked = (await deviceRef.get()).data()?['voteLock'] == true;
      if (locked) continue;

      await deviceRef.set({'voteLock': true}, SetOptions(merge: true));
      Future.delayed(const Duration(milliseconds: 500), () {
        deviceRef.set({'voteLock': false}, SetOptions(merge: true));
      });

      final quizRef = fs.doc('hubs/$hubId/quizTopics/$topicId/quizzes/$quizId');

      await fs.runTransaction((tx) async {
  final snap = await tx.get(quizRef);
  if (!snap.exists) return;

  final data = snap.data()!;
  final List triggers = (data['triggers'] as List?) ?? const [];
  final allowMultiple = data['allowMultiple'] == true;

  final List<int> counts =
      (data['counts'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      List<int>.filled(triggers.length, 0);

  // ✅ 안전 복제
  final Map<String, dynamic> votesByDevice =
      Map<String, dynamic>.from((data['votesByDevice'] as Map?) ?? {});

  final newSlot = slotIndex!;
  final newTrigger = 'S${newSlot}_${clickTypeRaw.toUpperCase()}';
  final newIdx = triggers.indexOf(newTrigger);
  if (newIdx < 0) return;

  if (!allowMultiple) {
    final prevSlot = votesByDevice[deviceId]?.toString();

    // 동일 보기 재클릭 → 무시
    if (prevSlot == newSlot) return;

    // 🔹 이전 선택 감산 먼저
    if (prevSlot != null && prevSlot.isNotEmpty) {
      for (int i = 0; i < triggers.length; i++) {
        final t = triggers[i].toString().toUpperCase();
        final tSlot = t.split('_').first.replaceAll('S', '');
        if (tSlot == prevSlot && counts[i] > 0) counts[i] -= 1;
      }
    }

    // 🔹 새 선택 증가
    counts[newIdx] += 1;

    // 🔹 기존 key 교체 (덮어쓰기)
    votesByDevice[deviceId] = newSlot;
  } else {
    // multiple 모드
    final prevList =
        (votesByDevice[deviceId] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    if (prevList.contains(newSlot)) return;
    counts[newIdx] += 1;
    prevList.add(newSlot);
    votesByDevice[deviceId] = prevList;
  }

  // 🔹 음수 방지
  for (int i = 0; i < counts.length; i++) {
    if (counts[i] < 0) counts[i] = 0;
  }

  // ✅ 트랜잭션 안전 업데이트 (merge: true)
  tx.set(quizRef, {
    'counts': counts,
    'votesByDevice': votesByDevice,
  }, SetOptions(merge: true));
});
    }
  }

  Widget _quizBarRow({
    required String label,
    required int votes,
    required int total,
    required bool hideResults,
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
                              ),
                            ),
                          ),
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
        fs
            .doc(
              '$hubPath/quizTopics/${widget.topicId}/quizzes/${widget.currentQuizId}',
            )
            .snapshots();

    final topicStream =
        fs.doc('$hubPath/quizTopics/${widget.topicId}').snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: topicStream,
      builder: (context, topicSnap) {
        final topicData = topicSnap.data?.data();
        if (topicData == null) return const _WaitingScreen();

        _currentIndex = (topicData['currentQuizIndex'] as num?)?.toInt() ?? 1;
        final quizCol = fs.collection(
          '$hubPath/quizTopics/${widget.topicId}/quizzes',
        );
        quizCol.where('public', isEqualTo: true).get().then((qs) {
          if (mounted) {
            setState(() {
              setState(() {
                _totalCount = qs.docs.length;
              });
            });
          }
        });

        final timerSec = (topicData['timerSeconds'] as num?)?.toInt();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: quizStream,
          builder: (context, quizSnap) {
            if (!quizSnap.hasData) {
              return const _WaitingScreen();
            }

            final qx = quizSnap.data!.data();
            if (qx == null) return const _WaitingScreen();

            if (!qx.containsKey('public')) {
              return const _WaitingScreen();
            }

            final isPublic = qx['public'] == true;
            if (isPublic == false) {
              debugPrint(
                '⏭️ Skipping non-public quiz: ${widget.currentQuizId}',
              );
              unawaited(_skipToNextPublicQuiz(fs, hubPath));
              return const _WaitingScreen();
            }

            if (isPublic && timerSec != null && timerSec > 0) {
              if (_lastQuizIdShown != widget.currentQuizId) {
                _lastQuizIdShown = widget.currentQuizId;
                _timer?.cancel();
                _isTimerRunning = false;
                _remaining = null;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _startTimer(timerSec);
                  }
                });
              }
            } else {
              if (_isTimerRunning || _remaining != null) {
                debugPrint('⏹️ Firestore에서 timerSeconds 없음 → 타이머 종료');
              }
              _timer?.cancel();
              _isTimerRunning = false;
              _timerTotalSeconds = null;
              _remaining = null;
              _lastQuizIdShown = null;
            }

            final question = (qx['question'] as String?) ?? '';
            final List<String> choices =
                (qx['choices'] as List?)?.map((e) => e.toString()).toList() ??
                const [];
            final List<int> counts =
                (qx['counts'] as List?)
                    ?.map((e) => (e as num).toInt())
                    .toList() ??
                List<int>.filled(choices.length, 0);

            final Map<String, dynamic> votersMap = Map<String, dynamic>.from(
              (qx['votesByDevice'] as Map?) ?? const {},
            );
            final int totalVoters = votersMap.keys.toSet().length;

            final total = counts.isEmpty ? 0 : counts.reduce((a, b) => a + b);

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
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          hide ? '—' : '$totalVoters VOTERS',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ===== 선택지 박스 =====
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.black12.withOpacity(0.08),
                          ),
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
                            for (var i = 0; i < choices.length; i++) ...[
                              _quizBarRow(
                                label: choices[i],
                                votes: (i < counts.length) ? counts[i] : 0,
                                total: total,
                                hideResults: hide,
                              ),
                              if (i != choices.length - 1)
                                const SizedBox(height: 12),
                            ],
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

        final question = (qx['question'] as String?) ?? '';
        final List<String> choices =
            (qx['choices'] as List?)?.map((e) => e.toString()).toList() ??
            const [];
        final List<int> counts =
            (qx['counts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List<int>.filled(choices.length, 0);

        final int? correctIndex = (qx['correctIndex'] as num?)?.toInt();

        final Map<String, dynamic> votersMap = Map<String, dynamic>.from(
          (qx['votesByDevice'] as Map?) ?? const {},
        );
        final int totalVoters = votersMap.keys.toSet().length;

        final total = counts.isEmpty ? 0 : counts.reduce((a, b) => a + b);

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
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black12.withOpacity(0.08),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Column(
                      children: [
                        for (var i = 0; i < choices.length; i++) ...[
                          _quizBarRow(
                            label: choices[i],
                            votes: counts[i],
                            total: total,
                            hideResults: false,
                            isRevealPhase: true,
                            isMax: (correctIndex != null && i == correctIndex),
                          ),
                          if (i != choices.length - 1)
                            const SizedBox(height: 12),
                        ],
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
                      final List<String> choices =
                          (q['choices'] as List?)
                              ?.map((e) => e.toString())
                              .toList() ??
                          const [];
                      final int? correct = (q['correctIndex'] as num?)?.toInt();

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
                                List<int>.filled(choices.length, 0);
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
                                    ...List.generate(choices.length, (ci) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _resultRow(
                                          label:
                                              '${String.fromCharCode(65 + ci)}. ${choices[ci]}',
                                          value:
                                              counts.length > ci
                                                  ? counts[ci]
                                                  : 0,
                                          total: total,
                                          isCorrect:
                                              correct != null && ci == correct,
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
