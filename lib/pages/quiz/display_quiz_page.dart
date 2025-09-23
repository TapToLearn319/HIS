// lib/pages/quiz/display_quiz_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';

/// 대기 화면 커스터마이즈
const Color kWaitingBgColor = Color.fromARGB(255, 246, 250, 255);
const String kWaitingImageAsset = 'assets/logo_bird_standby.png'; // 없으면 아이콘 대체

/// ✅ 컴팩트 리빌 모드: 리빌 시 하단에 추가 섹션(요약/상세 등) 전혀 표시하지 않음
const bool kCompactReveal = true;

class DisplayQuizPage extends StatefulWidget {
  const DisplayQuizPage({super.key});

  @override
  State<DisplayQuizPage> createState() => _DisplayQuizPageState();
}

class _DisplayQuizPageState extends State<DisplayQuizPage> {
  /// 디스플레이가 켜진 순간 — 이 이후의 변경만 반영
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
    print('🔎 Display hubId=${context.read<HubProvider?>()?.hubId}, hubPath=${context.read<HubProvider?>()?.hubDocPath}');

    if (hubPath == null) {
      // 허브 미선택 시 대기화면
      
      return const Scaffold(body: _WaitingScreen());
    }

    // 단일 정렬(인덱스 부담↓), 최신 것부터 50개만
    final stream = fs
        .collection('$hubPath/quizTopics')
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

          // 1) running 중인 토픽 중 "가장 최근" 것을 무조건 표시 (fresh 필터 제거)
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

          // 2) running이 없고, 명시적으로 디스플레이 요약 요청된 경우
          //    ⚠️ updatedAt 이 디스플레이 오픈 이후인 경우에만 반영 (과거 Show Result 무시)
          final showSummary = docs.where((d) {
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

/// 진행 중 화면(문제/리빌) — (아래 클래스들은 이전 버전과 동일, 폰트/아이콘 확대 버전 유지)
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
  String? _lastQuizIdShown;
  final Map<String, Map<String, dynamic>> _quizCache = {};

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    // 허브 경로 확보
    final hubPath = context.read<HubProvider>().hubDocPath;
    if (hubPath == null) {
      return const _WaitingScreen();
    }

    final quizRef =
        fs.doc('$hubPath/quizTopics/${widget.topicId}/quizzes/${widget.currentQuizId}');
    final resRef =
        fs.doc('$hubPath/quizTopics/${widget.topicId}/results/${widget.currentQuizId}');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: quizRef.snapshots(),
      builder: (context, quizSnap) {
        Map<String, dynamic>? qx = quizSnap.data?.data();

        if (qx != null) {
          _quizCache[widget.currentQuizId] = qx;
          _lastQuizIdShown = widget.currentQuizId;
        }
        qx ??= _quizCache[widget.currentQuizId] ??
            (_lastQuizIdShown != null ? _quizCache[_lastQuizIdShown] : null);

        if (qx == null) {
          return const _WaitingScreen();
        }

        final question = (qx['question'] as String?) ?? '';
        final List<String> choices =
            (qx['choices'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        final List<String> triggers =
            (qx['triggers'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        final int? correct = (qx['correctIndex'] as num?)?.toInt();

        Widget _centerWrapper(Widget child) {
          return Container(
            color: const Color(0xFFF7F9FC),
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(48, 32, 48, 48),
                  child: child,
                ),
              ),
            ),
          );
        }

        if (widget.phase == 'question') {
          return _centerWrapper(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title.isEmpty ? 'Quiz' : widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B1324),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 22),
                _ChoiceListPlain(choices: choices, triggers: triggers, shrink: true),
              ],
            ),
          );
        } else {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: resRef.snapshots(),
            builder: (context, resSnap) {
              final counts = (resSnap.data?.data()?['counts'] as List?)
                      ?.map((e) => (e as num).toInt())
                      .toList() ??
                  const [];

              return _centerWrapper(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title.isEmpty ? 'Quiz' : widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      question,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B1324),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _ChoiceListReveal(
                      choices: choices,
                      triggers: triggers,
                      counts: counts,
                      correct: correct,
                      compact: kCompactReveal,
                      shrink: true,
                    ),
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

/// 문제 단계
class _ChoiceListPlain extends StatelessWidget {
  const _ChoiceListPlain({
    required this.choices,
    required this.triggers,
    this.shrink = false,
  });
  final List<String> choices;
  final List<String> triggers;
  final bool shrink;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      shrinkWrap: shrink,
      physics: shrink ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 480,
        childAspectRatio: 1.35,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
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
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF111827),
                      child: Text(
                        String.fromCharCode(65 + i),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        choices[i],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _TriggerBadge(triggerKey: trig),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 리빌 단계
class _ChoiceListReveal extends StatelessWidget {
  const _ChoiceListReveal({
    required this.choices,
    required this.triggers,
    required this.counts,
    required this.correct,
    this.compact = false,
    this.shrink = false,
  });

  final List<String> choices;
  final List<String> triggers;
  final List<int> counts;
  final int? correct;
  final bool compact;
  final bool shrink;

  @override
  Widget build(BuildContext context) {
    final total = counts.isEmpty ? 0 : counts.reduce((a, b) => a + b);
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      shrinkWrap: shrink,
      physics: shrink ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 480,
        childAspectRatio: 1.35,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
      ),
      itemCount: choices.length,
      itemBuilder: (_, i) {
        final v = (i < counts.length) ? counts[i] : 0;
        final ratio = total == 0 ? 0.0 : (v / total);
        final isCorrect = correct != null && i == correct;
        final barColor = isCorrect ? Colors.green : const Color(0xFF64748B);

        final trig = (i < triggers.length) ? triggers[i] : null;
        final showTrig = !compact;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: isCorrect ? Colors.green : const Color(0xFFDAE2EE)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isCorrect ? Colors.green : const Color(0xFF111827),
                      child: Text(
                        String.fromCharCode(65 + i),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        choices[i],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: isCorrect ? Colors.green.shade800 : const Color(0xFF0B1324),
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (isCorrect)
                      const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(Icons.check_circle, color: Colors.green, size: 28),
                      ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 20),
                if (showTrig) _TriggerBadge(triggerKey: trig),
                SizedBox(height: compact ? 14 : 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 16,
                    color: barColor,
                    backgroundColor: barColor.withOpacity(0.15),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 4),
                    const Text(
                      '응답:',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334155), fontSize: 16),
                    ),
                    Text(
                      '$v명',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334155), fontSize: 16),
                    ),
                    Text(
                      total == 0 ? '0%' : '${(ratio * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 트리거 칩 UI
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.7)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  static String _labelFor(String k) {
    switch (k) {
      case 'S1_CLICK':
        return 'Button 1 · Click';
      case 'S1_HOLD':
        return 'Button 1 · Hold';
      case 'S2_CLICK':
        return 'Button 2 · Click';
      case 'S2_HOLD':
        return 'Button 2 · Hold';
      default:
        return 'No trigger';
    }
  }

  static IconData _iconFor(String k) {
    switch (k) {
      case 'S1_CLICK':
      case 'S2_CLICK':
        return Icons.pan_tool_alt;
      case 'S1_HOLD':
      case 'S2_HOLD':
        return Icons.touch_app;
      default:
        return Icons.help_outline;
    }
  }

  static Color _colorFor(String k) {
    switch (k) {
      case 'S1_CLICK':
        return const Color(0xFF60A5FA);
      case 'S1_HOLD':
        return const Color(0xFF2563EB);
      case 'S2_CLICK':
        return const Color(0xFFF87171);
      case 'S2_HOLD':
        return const Color(0xFFDC2626);
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

    final hubPath = context.watch<HubProvider>().hubDocPath;
    if (hubPath == null) {
      return const _WaitingScreen();
    }

    final quizzesStream = fs
        .collection('$hubPath/quizTopics/$topicId/quizzes')
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
                          (q['choices'] as List?)?.map((e) => e.toString()).toList() ?? const [];
                      final int? correct = (q['correctIndex'] as num?)?.toInt();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: fs.doc('$hubPath/quizTopics/$topicId/results/$quizId').snapshots(),
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
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
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
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _resultRow(
                                          label: '${String.fromCharCode(65 + ci)}. ${choices[ci]}',
                                          value: counts.length > ci ? counts[ci] : 0,
                                          total: total,
                                          isCorrect: correct != null && ci == correct,
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
                  color: isCorrect ? Colors.green.shade700 : const Color(0xFF0B1324),
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
