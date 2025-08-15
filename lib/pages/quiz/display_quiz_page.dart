// lib/pages/quiz/display_quiz_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 대기 화면 커스터마이즈
const Color kWaitingBgColor = Color(0xFF0B1324);
const String kWaitingImageAsset = 'assets/display_wait.png'; // 없으면 아이콘 대체

/// ✅ 컴팩트 리빌 모드: 리빌 시 하단에 추가 섹션(요약/상세 등) 전혀 표시하지 않음
const bool kCompactReveal = true;

class DisplayQuizPage extends StatelessWidget {
  const DisplayQuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    // 단일 정렬(인덱스 부담↓), 최신 것부터 50개만
    final stream = fs
        .collection('quizTopics')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    return Scaffold(
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

          // 1) running 중인 토픽 우선
          final running = docs
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
            return _ActiveQuizView(
              topicId: d.id,
              title: title,
              phase: phase, // 'question' | 'reveal'
              currentQuizId: currentQuizId,
            );
          }

          // 2) running이 없을 땐, 명시적으로 디스플레이에 결과를 띄우라고 요청된 경우에만 요약 보여줌
          final showSummary = docs
              .where((d) => (d.data()['showSummaryOnDisplay'] as bool?) == true)
              .toList()
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

          // 3) 그 외(토픽만 고르는 중 등)는 무조건 대기화면
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
              height: 200,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.hourglass_top, color: Colors.white70, size: 100),
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

/// 진행 중 화면(문제/리빌) — 깜빡임 방지를 위해 캐시 사용
class _ActiveQuizView extends StatefulWidget {
  const _ActiveQuizView({
    required this.topicId,
    required this.title,
    required this.phase,
    required this.currentQuizId,
  });

  final String topicId;
  final String title;
  final String phase; // 'question' | 'reveal'
  final String currentQuizId;

  @override
  State<_ActiveQuizView> createState() => _ActiveQuizViewState();
}

class _ActiveQuizViewState extends State<_ActiveQuizView> {
  /// 최근에 화면에 그렸던 quizId (스냅샷이 바뀌는 짧은 순간에 유지용)
  String? _lastQuizIdShown;

  /// quizId -> quiz data 캐시
  final Map<String, Map<String, dynamic>> _quizCache = {};

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final quizRef = fs.doc('quizTopics/${widget.topicId}/quizzes/${widget.currentQuizId}');
    final resRef = fs.doc('quizTopics/${widget.topicId}/results/${widget.currentQuizId}');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: quizRef.snapshots(),
      builder: (context, quizSnap) {
        Map<String, dynamic>? qx = quizSnap.data?.data();

        // 새 데이터가 오면 캐시에 저장 + last 갱신
        if (qx != null) {
          _quizCache[widget.currentQuizId] = qx;
          _lastQuizIdShown = widget.currentQuizId;
        }

        // 대기(초기 로드)거나 스냅 준비전: 캐시로 유지해서 깜빡임 제거
        qx ??= _quizCache[widget.currentQuizId] ??
            (_lastQuizIdShown != null ? _quizCache[_lastQuizIdShown] : null);

        if (qx == null) {
          // 정말 처음엔만 대기
          return const _WaitingScreen();
        }

        final question = (qx['question'] as String?) ?? '';
        final List<String> choices =
            (qx['choices'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        final List<String> triggers =
            (qx['triggers'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        final int? correct = (qx['correctIndex'] as num?)?.toInt();

        final header = Column(
          children: [
            const SizedBox(height: 28),
            Text(
              widget.title.isEmpty ? 'Quiz' : widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B1324),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        );

        if (widget.phase == 'question') {
          // 문제 단계: 선택지 + 트리거 칩
          return Container(
            color: const Color(0xFFF7F9FC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(child: _ChoiceListPlain(choices: choices, triggers: triggers)),
                // 문제 단계: 하단 여백만 (UI 부담 적음)
                const SizedBox(height: 12),
              ],
            ),
          );
        } else {
          // 리빌 단계: 결과 스트림
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: resRef.snapshots(),
            builder: (context, resSnap) {
              final counts = (resSnap.data?.data()?['counts'] as List?)
                      ?.map((e) => (e as num).toInt())
                      .toList() ??
                  const [];
              return Container(
                color: const Color(0xFFF7F9FC),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    // ✅ 리빌 단계는 "카드 그리드"만 표시 (하단 추가 섹션 없음)
                    Expanded(
                      child: _ChoiceListReveal(
                        choices: choices,
                        triggers: triggers,
                        counts: counts,
                        correct: correct,
                        compact: kCompactReveal, // ⬅️ 컴팩트 모드로 부가요소(칩 등) 숨김
                      ),
                    ),
                    // ✅ 하단 여분 UI/요약/상세 등을 전혀 렌더하지 않음
                    if (!kCompactReveal) const SizedBox(height: 12),
                  ],
                ),
              );
            },
          );
        }
      },
    );
  }
}

/// 문제 단계: 선택지 + 트리거 칩
class _ChoiceListPlain extends StatelessWidget {
  const _ChoiceListPlain({required this.choices, required this.triggers});
  final List<String> choices;
  final List<String> triggers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final isWide = c.maxWidth > 900;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            childAspectRatio: isWide ? 3.8 : 4.6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: choices.length,
          itemBuilder: (_, i) {
            final trig = (i < triggers.length) ? triggers[i] : null;
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFFDAE2EE)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF111827),
                          child: Text(
                            String.fromCharCode(65 + i),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            choices[i],
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _TriggerBadge(triggerKey: trig),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 리빌 단계 - 정답 하이라이트 + 막대(progress) + 카운트
class _ChoiceListReveal extends StatelessWidget {
  const _ChoiceListReveal({
    required this.choices,
    required this.triggers,
    required this.counts,
    required this.correct,
    this.compact = false,
  });

  final List<String> choices;
  final List<String> triggers;
  final List<int> counts;
  final int? correct;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final total = counts.isEmpty ? 0 : counts.reduce((a, b) => a + b);
    return LayoutBuilder(
      builder: (_, c) {
        final isWide = c.maxWidth > 900;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            childAspectRatio: isWide ? 3.8 : 4.6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: choices.length,
          itemBuilder: (_, i) {
            final v = (i < counts.length) ? counts[i] : 0;
            final ratio = total == 0 ? 0.0 : (v / total);
            final isCorrect = correct != null && i == correct;
            final barColor = isCorrect ? Colors.green : const Color(0xFF64748B);

            // 컴팩트 모드: 카드 높이를 낮추기 위해 칩/여백 축소
            final trig = (i < triggers.length) ? triggers[i] : null;
            final showTrig = !compact; // ⬅️ 리빌 컴팩트 시 칩 숨김

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: isCorrect ? Colors.green : const Color(0xFFDAE2EE)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isCorrect ? Colors.green : const Color(0xFF111827),
                          child: Text(
                            String.fromCharCode(65 + i),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            choices[i],
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isCorrect ? Colors.green.shade800 : const Color(0xFF0B1324),
                            ),
                          ),
                        ),
                        if (isCorrect)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? 8 : 10),
                    if (showTrig) _TriggerBadge(triggerKey: trig),
                    SizedBox(height: compact ? 8 : 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0),
                        minHeight: 12,
                        color: barColor,
                        backgroundColor: barColor.withOpacity(0.15),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('응답: $v',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                        Text(total == 0 ? '0%' : '${(ratio * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 트리거 칩 UI (S1/S2 × Click/Hold)
class _TriggerBadge extends StatelessWidget {
  const _TriggerBadge({required this.triggerKey});
  final String? triggerKey;

  @override
  Widget build(BuildContext context) {
    final t = triggerKey ?? '';
    final label = _labelFor(t);
    final icon = _iconFor(t);
    final color = _colorFor(t);

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.7)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  static String _labelFor(String k) {
    switch (k) {
      case 'S1_CLICK':
        return 'Slot 1 · Click';
      case 'S1_HOLD':
        return 'Slot 1 · Hold';
      case 'S2_CLICK':
        return 'Slot 2 · Click';
      case 'S2_HOLD':
        return 'Slot 2 · Hold';
      default:
        return 'No trigger';
    }
  }

  static IconData _iconFor(String k) {
    switch (k) {
      case 'S1_CLICK':
      case 'S2_CLICK':
        return Icons.touch_app;
      case 'S1_HOLD':
      case 'S2_HOLD':
        return Icons.pan_tool_alt;
      default:
        return Icons.help_outline;
    }
  }

  static Color _colorFor(String k) {
    switch (k) {
      case 'S1_CLICK':
        return const Color(0xFF60A5FA); // 파랑
      case 'S1_HOLD':
        return const Color(0xFF2563EB); // 진파랑
      case 'S2_CLICK':
        return const Color(0xFFF87171); // 빨강
      case 'S2_HOLD':
        return const Color(0xFFDC2626); // 진빨강
      default:
        return Colors.grey;
    }
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
    final quizzesStream =
        fs.collection('quizTopics/$topicId/quizzes').orderBy('createdAt').snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: quizzesStream,
      builder: (context, qsnap) {
        final quizzes = qsnap.data?.docs ?? const [];
        if (quizzes.isEmpty) {
          return const _WaitingScreen();
        }
        return Container(
          color: const Color(0xFFF7F9FC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 28),
              Text(
                title.isEmpty ? 'Quiz Results' : '$title • Results',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                  itemCount: quizzes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final q = quizzes[i].data();
                    final quizId = quizzes[i].id;
                    final question = (q['question'] as String?) ?? '';
                    final List<String> choices =
                        (q['choices'] as List?)?.map((e) => e.toString()).toList() ?? const [];
                    final int? correct = (q['correctIndex'] as num?)?.toInt();

                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: fs.doc('quizTopics/$topicId/results/$quizId').snapshots(),
                      builder: (context, rsnap) {
                        final counts = (rsnap.data?.data()?['counts'] as List?)
                                ?.map((e) => (e as num).toInt())
                                .toList() ??
                            List<int>.filled(choices.length, 0);
                        final total = counts.isEmpty ? 0 : counts.reduce((a, b) => a + b);

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Color(0xFFDAE2EE)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Q${i + 1}. $question',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                for (int ci = 0; ci < choices.length; ci++) ...[
                                  _resultRow(
                                    label: '${String.fromCharCode(65 + ci)}. ${choices[ci]}',
                                    value: counts.length > ci ? counts[ci] : 0,
                                    total: total,
                                    isCorrect: correct != null && ci == correct,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ],
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
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.check_circle, color: Colors.green, size: 18),
              ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isCorrect ? Colors.green.shade700 : const Color(0xFF0B1324),
                ),
              ),
            ),
            Text(' ${value}명', style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 10,
            color: barColor,
            backgroundColor: barColor.withOpacity(0.15),
          ),
        ),
      ],
    );
  }
}
