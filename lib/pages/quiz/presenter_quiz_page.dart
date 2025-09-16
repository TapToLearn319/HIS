// lib/pages/quiz/presenter_quiz_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const String kHubId = 'hub-001'; // 집계용: hubs/{hubId}.currentSessionId 사용

// 둥둥 뜨는 FAB용 이미지(원하는 경로로 교체하세요)
const String kFabCreateTopicAsset = 'assets/icons/fab_create_topic.png';
const String kFabAddQuizAsset = 'assets/icons/fab_add_quiz.png';
const String kSaveIconAsset = 'assets/icons/save_quiz.png';

/// Presenter Quiz (Top-level: quizTopics/{topicId}/quizzes/{quizId})
/// - Topic: title, status(draft|running|stopped), startedAt, endedAt,
///          currentIndex, currentQuizId, phase('question'|'reveal'|'finished'),
///          questionStartedAt, showSummaryOnDisplay
/// - Quiz: question, choices[2..4], correctIndex | correctIndices[], triggers[per choice],
///         anonymous(bool), allowMultiple(bool), showMode('realtime'|'after')
/// - Result: quizTopics/{topicId}/results/{quizId}
///           { counts: int[], correctIndex, startedAt, endedAt, computedAt }
class PresenterQuizPage extends StatelessWidget {
  const PresenterQuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 246, 250, 255),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Quiz (Presenter)'),
      ),
      body: Stack(
        children: const [
          _TopicList(),
          _CreateTopicFab(), // 오른쪽 아래 둥둥 FAB
        ],
      ),
    );
  }
}

class _CreateTopicFab extends StatelessWidget {
  const _CreateTopicFab();

  Future<void> _createTopicDialog(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create topic'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Topic title',
            border: OutlineInputBorder(),
            hintText: '예: 3-1 분수 덧셈',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true) {
      final title = c.text.trim();
      if (title.isEmpty) return;
      await FirebaseFirestore.instance.collection('quizTopics').add({
        'title': title,
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'currentIndex': null,
        'currentQuizId': null,
        'phase': 'finished',
        'questionStartedAt': null,
        'showSummaryOnDisplay': false,
      });
      _snack(context, 'Topic created.');
    }
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: 200,   // 필요시 조절
          height: 200,  // 필요시 조절
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              hoverColor: Colors.black.withOpacity(0.05),   // 마우스 오버
              splashColor: Colors.black.withOpacity(0.1),   // 클릭 물결
              onTap: () => _createTopicDialog(context),
              child: Tooltip(
                message: 'Create topic',
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Image.asset(
                    'assets/logo_bird_create.png',   // 원하는 이미지 경로로 교체
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.add_circle,
                      size: 48,
                      color: Colors.indigo,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class _TopicList extends StatelessWidget {
  const _TopicList();

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final stream = fs.collection('quizTopics')
        .orderBy('createdAt', descending: true)
        .snapshots();

    String _fmtDate(Timestamp? ts) {
      final dt = ts?.toDate();
      if (dt == null) return '-';
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    Future<int> _quizCount(String topicId) async {
      final qs = await fs.collection('quizTopics/$topicId/quizzes').get();
      return qs.size;
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const _EmptyState(
            title: 'No topics yet',
            subtitle: '오른쪽 아래 버튼으로 토픽을 만들어 주세요.',
          );
        }

        final topics = snap.data!.docs;
        return Center(
          child: FractionallySizedBox(
            widthFactor: 0.95,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 440, // ✅ 카드 최대 폭 크게
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 4 / 3,
              ),
              itemCount: topics.length,
              itemBuilder: (_, i) {
                final d = topics[i];
                final x = d.data();
                final title = (x['title'] as String?) ?? '(untitled)';
                final createdAt = x['createdAt'] as Timestamp?;

                return Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFDAE2EE)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _TopicDetailPage(topicId: d.id)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 제목
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20, // ✅ 폰트 크기 키움
                              color: Color(0xFF0B1324),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          const Divider(color: Colors.black, thickness: 1), // ✅ 검은색 디바이더

                          const SizedBox(height: 12),
                          // 퀴즈 개수
                          FutureBuilder<int>(
                            future: _quizCount(d.id),
                            builder: (context, snapCount) {
                              final cnt = snapCount.data ?? 0;
                              return Row(
                                children: [
                                  const Icon(Icons.view_module_outlined, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '퀴즈 $cnt개',
                                    style: const TextStyle(fontSize: 16), // ✅ 폰트 크기 키움
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // 생성일
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _fmtDate(createdAt),
                                style: const TextStyle(fontSize: 16), // ✅ 폰트 크기 키움
                              ),
                            ],
                          ),

                          const Spacer(),

                          // more 버튼
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => _TopicDetailPage(topicId: d.id)),
                                );
                              },
                              child: const Text(
                                'more ›',
                                style: TextStyle(
                                  fontSize: 16, // ✅ 버튼 폰트 크기 키움
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
  }
}



class _TopicDetailPage extends StatelessWidget {
  const _TopicDetailPage({required this.topicId});
  final String topicId;

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final topicStream = fs.doc('quizTopics/$topicId').snapshots();
    final quizzesStream =
        fs.collection('quizTopics/$topicId/quizzes').orderBy('createdAt', descending: false).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: topicStream,
      builder: (context, topicSnap) {
        final topic = topicSnap.data?.data();
        final title = (topic?['title'] as String?) ?? '(untitled)';
        final status = (topic?['status'] as String?) ?? 'draft';
        final phase = (topic?['phase'] as String?) ?? 'finished';
        final currentIndex = (topic?['currentIndex'] as num?)?.toInt();
        final currentQuizId = topic?['currentQuizId'] as String?;
        final questionStartedAt = topic?['questionStartedAt'] as Timestamp?;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
  stream: quizzesStream,
  builder: (context, snap) {
    final quizzes = snap.data?.docs ?? const [];
    // ⬇️ 여기서부터 Scaffold를 WillPopScope로 감싼다
    return WillPopScope(
      onWillPop: () async {
        // 진행 중이면 자동으로 stopped로 정리
        await _maybeStopRunningTopic(status: status, topicId: topicId);
        return true; // pop 진행
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 246, 250, 255),
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _maybeStopRunningTopic(status: status, topicId: topicId);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          title: Text('Topic • $title'),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.8,
                    child: _RunBar(
                      topicId: topicId,
                      quizzes: quizzes,
                      status: status,
                      phase: phase,
                      currentIndex: currentIndex,
                      currentQuizId: currentQuizId,
                      questionStartedAt: questionStartedAt,
                    ),
                  ),
                ),
                const Divider(height: 0),
                Expanded(
                  child: quizzes.isEmpty
                      ? const Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.8,
                            child: _EmptyState(
                              title: 'No quizzes',
                              subtitle: '오른쪽 아래 버튼으로 퀴즈를 추가해 주세요.',
                            ),
                          ),
                        )
                      : Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.8,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemBuilder: (_, i) => _QuizCardTile(
                                topicId: topicId,
                                fs: fs,
                                quizDoc: quizzes[i],
                                isCurrent: currentQuizId == quizzes[i].id,
                                topicStatus: status,
                              ),
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemCount: quizzes.length,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            _CreateQuizFabImage(
              topicId: topicId,
              fs: fs,
              isRunning: status == 'running',
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

class _CreateQuizFabImage extends StatelessWidget {
  const _CreateQuizFabImage({
    required this.topicId,
    required this.fs,
    this.isRunning = false,
  });

  final String topicId;
  final FirebaseFirestore fs;
  final bool isRunning;

  Future<void> _handleStartStop(BuildContext context) async {
    // 실제 동작: 퀴즈 생성 화면으로 이동
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _CreateQuizPage(topicId: topicId, fs: fs),
        fullscreenDialog: true,
      ),
    );
    if (created == true && context.mounted) {
      _snack(context, 'Quiz created.');
    }
  }

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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _handleStartStop(context),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Image.asset(
                  'assets/logo_bird_create.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.add_circle, size: 48, color: Colors.indigo),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------- 퀴즈 카드 (more를 누르면만 옵션+인원 표시) -------------------

class _QuizCardTile extends StatefulWidget {
  const _QuizCardTile({
    required this.topicId,
    required this.fs,
    required this.quizDoc,
    required this.isCurrent,
    required this.topicStatus,
  });

  final String topicId;
  final FirebaseFirestore fs;
  final QueryDocumentSnapshot<Map<String, dynamic>> quizDoc;
  final bool isCurrent;
  final String topicStatus;

  @override
  State<_QuizCardTile> createState() => _QuizCardTileState();
}

class _QuizCardTileState extends State<_QuizCardTile> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.quizDoc;
    final x = d.data();
    final question = (x['question'] as String?) ?? '(no question)';
    final List choices = (x['choices'] as List?) ?? const [];
    final int? correct = (x['correctIndex'] as num?)?.toInt();
    final List<int> correctList =
        ((x['correctIndices'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final bool allowMultiple = correctList.isNotEmpty;
    final List triggers = (x['triggers'] as List?) ?? const [];
    final bool anonymous = (x['anonymous'] as bool?) ?? false;

    bool _isCorrectIdx(int idx) =>
        allowMultiple ? correctList.contains(idx) : (correct != null && idx == correct);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: widget.fs.doc('quizTopics/${widget.topicId}/results/${d.id}').get(),
      builder: (context, resSnap) {
        final res = resSnap.data?.data();
        final List<int> counts =
            ((res?['counts'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
        final total = counts.fold<int>(0, (p, c) => p + c);

        return Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 헤더: 타이틀만 보이게 + 우측 액션들 (요청 반영: more ▶ edit ▶ delete)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        question,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // More 토글: 닫힘(▼ expand_more), 열림(▲ expand_less)
                    IconButton(
                      tooltip: _showMore ? 'Less' : 'More',
                      icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
                      onPressed: () => setState(() => _showMore = !_showMore),
                    ),
                    // Edit: 연필 아이콘
                    IconButton(
                      tooltip: 'Edit (설정)',
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editQuizDialog(context, widget.fs, quizId: d.id, initial: x),
                    ),
                    // Delete
                    IconButton(
                      tooltip: 'Delete quiz',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        if (widget.topicStatus == 'running' && widget.isCurrent) {
                          _snack(context, '현재 진행 중인 퀴즈는 삭제할 수 없습니다. Next/Finish 후 삭제하세요.');
                          return;
                        }

                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete quiz'),
                            content: const Text('이 퀴즈와 해당 결과가 삭제됩니다. 계속할까요?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (ok == true) {
                          try {
                            final batch = widget.fs.batch();
                            final quizRef = widget.fs.doc('quizTopics/${widget.topicId}/quizzes/${d.id}');
                            final resRef  = widget.fs.doc('quizTopics/${widget.topicId}/results/${d.id}');
                            batch.delete(quizRef);
                            batch.delete(resRef); // 존재 안 해도 delete는 안전합니다.
                            await batch.commit();

                            // ⚠️ 여기서 위젯이 이미 dispose 되었을 수 있음 → mounted 확인!
                            if (!mounted) return;
                            _snack(context, 'Quiz deleted.');
                          } catch (e) {
                            if (!mounted) return;
                            _snack(context, 'Delete failed: $e');
                          }
                        }
                      },
                    ),
                  ],
                ),

                // ── more 펼쳤을 때만: 설정 뱃지 + "누르는 방식"별 인원수 ──
                if (_showMore) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (allowMultiple)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Chip(visualDensity: VisualDensity.compact, label: Text('복수정답')),
                        ),
                      if (anonymous)
                        const Chip(visualDensity: VisualDensity.compact, label: Text('익명')),
                    ],
                  ),
                  const Divider(height: 18),

                  // 제목
                  Row(
                    children: const [
                      Icon(Icons.touch_app, size: 18, color: Colors.indigo),
                      SizedBox(width: 6),
                      Text('누르는 방식 및 인원수',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 각 옵션: 트리거칩 + (정답표시) + 텍스트 + 인원칩
                  for (int i = 0; i < choices.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 트리거(누르는 방식)
                          _triggerChip(triggers.length > i ? (triggers[i] as String?) : null),
                          const SizedBox(width: 8),

                          // 정답 표시 아이콘
                          Icon(
                            _isCorrectIdx(i) ? Icons.check_circle : Icons.circle_outlined,
                            size: 18,
                            color: _isCorrectIdx(i) ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 6),

                          // 보기 텍스트
                          Expanded(
                            child: Text(
                              '${String.fromCharCode(65 + i)}. ${choices[i]}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // 인원수
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(' ${i < counts.length ? counts[i] : 0} '),
                          ),
                        ],
                      ),
                    ),

                  // 총계
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('총 ${total}명', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------- 공용 트리거칩/에딧 다이얼로그 등 -------------------

const _kTriggerLabel = <String, String>{
  'S1_CLICK': 'Slot 1 • Click',
  'S1_HOLD': 'Slot 1 • Hold',
  'S2_CLICK': 'Slot 2 • Click',
  'S2_HOLD': 'Slot 2 • Hold',
};

Widget _triggerChip(String? key) {
  final label = key == null ? 'No trigger' : _kTriggerLabel[key] ?? key;
  final color = key == null ? Colors.grey : Colors.indigo;
  return Chip(
    visualDensity: VisualDensity.compact,
    side: BorderSide(color: color),
    backgroundColor: color.withOpacity(0.08),
    label: Text(label, style: TextStyle(color: color)),
  );
}

// ── Edit dialog (단일정답 유지) ──
Future<void> _editQuizDialog(
  BuildContext context,
  FirebaseFirestore fs, {
  required String quizId,
  required Map<String, dynamic> initial,
}) async {
  final qCtrl = TextEditingController(text: (initial['question'] as String?) ?? '');
  final List initChoices = (initial['choices'] as List?) ?? const [];
  final List initTriggers = (initial['triggers'] as List?) ?? const [];
  int correctIndex = (initial['correctIndex'] as num?)?.toInt() ?? 0;

  final List<TextEditingController> choiceCtrls = <TextEditingController>[
    for (final c in initChoices) TextEditingController(text: c.toString()),
  ];
  if (choiceCtrls.length < 2) choiceCtrls.addAll([TextEditingController(), TextEditingController()]);
  final List<String?> triggerKeys = <String?>[...initTriggers.map((e) => e?.toString()).cast<String?>()];
  while (triggerKeys.length < choiceCtrls.length) {
    triggerKeys.add(null);
  }

  List<String> _availableForIndex(int idx) {
    final used = triggerKeys.toList()..removeAt(idx);
    return _kTriggerLabel.keys.where((k) => !used.contains(k)).toList();
  }

  void _ensureTriggerLength() {
    while (triggerKeys.length < choiceCtrls.length) triggerKeys.add(null);
    while (triggerKeys.length > choiceCtrls.length) triggerKeys.removeLast();
  }

  void addChoiceSync(StateSetter setState) {
    if (choiceCtrls.length >= 4) return;
    choiceCtrls.add(TextEditingController());
    setState(_ensureTriggerLength);
  }

  void removeChoiceSync(StateSetter setState, int idx) {
    if (choiceCtrls.length <= 2) return;
    final c = choiceCtrls.removeAt(idx);
    c.dispose();
    if (correctIndex >= choiceCtrls.length) correctIndex = choiceCtrls.length - 1;
    setState(_ensureTriggerLength);
  }

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          _ensureTriggerLength();
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Edit quiz'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: qCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Question', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Choices (2~4)', style: TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(
                        tooltip: 'Add choice',
                        onPressed: choiceCtrls.length >= 4 ? null : () => addChoiceSync(setState),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (int i = 0; i < choiceCtrls.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Radio<int>(
                            value: i,
                            groupValue: correctIndex,
                            onChanged: (v) => setState(() => correctIndex = v ?? correctIndex),
                          ),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: choiceCtrls[i],
                              decoration: InputDecoration(
                                labelText: 'Choice ${String.fromCharCode(65 + i)}',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Trigger',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: triggerKeys[i],
                                  items: _availableForIndex(i)
                                      .map((k) => DropdownMenuItem(value: k, child: Text(_kTriggerLabel[k] ?? k)))
                                      .toList()
                                    ..sort((a, b) => (a.child as Text).data!.compareTo((b.child as Text).data!)),
                                  onChanged: (v) => setState(() => triggerKeys[i] = v),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: choiceCtrls.length <= 2 ? null : () => removeChoiceSync(setState, i),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('라디오가 선택된 항목이 정답입니다. 각 선택지에는 Flic 입력 트리거를 하나씩 매핑하세요.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final q = qCtrl.text.trim();
                  final choices = choiceCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                  if (q.isEmpty || choices.length < 2) {
                    _snack(context, '문제와 최소 2개의 선택지를 입력하세요.');
                    return;
                  }
                  if (correctIndex < 0 || correctIndex >= choices.length) {
                    _snack(context, '정답 인덱스가 올바르지 않습니다.');
                    return;
                  }
                  if (triggerKeys.length != choices.length || triggerKeys.any((k) => k == null)) {
                    _snack(context, '모든 선택지에 트리거를 지정하세요.');
                    return;
                  }
                  final used = <String>{};
                  for (final k in triggerKeys.whereType<String>()) {
                    if (!used.add(k)) {
                      _snack(context, '트리거가 중복되었습니다: $k');
                      return;
                    }
                  }

                  // topicId 안전 추출
                  final maybeTopicId = context.findAncestorWidgetOfExactType<_TopicDetailPage>()?.topicId;
                  final routeArg = (ModalRoute.of(context)?.settings.arguments ?? '').toString();
                  final String safeTopicId = (maybeTopicId?.isNotEmpty ?? false) ? maybeTopicId! : routeArg;

                  if (safeTopicId.isEmpty) {
                    _snack(context, '토픽 ID를 찾을 수 없습니다.');
                    return;
                  }

                  await fs.doc('quizTopics/$safeTopicId/quizzes/$quizId').set({
                    'question': q,
                    'choices': choices,
                    'correctIndex': correctIndex,
                    'correctIndices': FieldValue.delete(),
                    'triggers': triggerKeys.whereType<String>().toList(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  Navigator.pop(context, true);
                  _snack(context, 'Quiz updated.');
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  qCtrl.dispose();
  for (final c in choiceCtrls) {
    c.dispose();
  }
}

// ------------------- 진행 컨트롤 바 (토글 리빌 + 동시 디스플레이 결과 보기) -------------------

class _RunBar extends StatefulWidget {
  const _RunBar({
    required this.topicId,
    required this.quizzes,
    required this.status,
    required this.phase,
    required this.currentIndex,
    required this.currentQuizId,
    required this.questionStartedAt,
  });

  final String topicId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> quizzes;
  final String status;
  final String phase;
  final int? currentIndex;
  final String? currentQuizId;
  final Timestamp? questionStartedAt;

  @override
  State<_RunBar> createState() => _RunBarState();
}

class _RunBarState extends State<_RunBar> {
  bool _busy = false;
  void _setBusy(bool v) => mounted ? setState(() => _busy = v) : null;

  @override
  Widget build(BuildContext context) {
    final hasQuizzes = widget.quizzes.isNotEmpty;
    final isRunning = widget.status == 'running';
    final onQuestion = isRunning && widget.phase == 'question';
    final onReveal = isRunning && widget.phase == 'reveal';
    final idx = widget.currentIndex ?? -1;

    final current = (idx >= 0 && idx < widget.quizzes.length) ? widget.quizzes[idx] : null;
    final currentQ = current?.data();

    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14), // 높이감 살짝 ↑
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isRunning
                    ? (onReveal ? 'Running • Reveal' : 'Running • Question')
                    : (widget.status == 'stopped' ? 'Stopped' : 'Draft'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isRunning ? Colors.green : (widget.status == 'stopped' ? Colors.grey : Colors.orange),
                ),
              ),
              const SizedBox(width: 12),
              if (currentQ != null)
                Expanded(
                  child: Text(
                    'Q${idx + 1}. ${(currentQ['question'] as String?) ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Expanded(child: Text('No current quiz')),
            ],
          ),
          const SizedBox(height: 10), // 버튼 바 위여백 약간 ↑
          Wrap(
            runSpacing: 8,
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: (!_busy && hasQuizzes && !isRunning) ? () => _startTopic(context) : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start topic'),
              ),
              ElevatedButton.icon(
                onPressed: (!_busy && (onQuestion || onReveal))
                    ? () => _toggleReveal(context, onQuestion: onQuestion, onReveal: onReveal)
                    : null,
                icon: Icon(onReveal ? Icons.visibility_off : Icons.visibility),
                label: Text(onReveal ? 'Hide results' : 'Reveal answer'),
              ),
              ElevatedButton.icon(
                onPressed: (!_busy && (onQuestion || onReveal)) ? () => _nextOrFinish(context) : null,
                icon: const Icon(Icons.skip_next),
                label: Text((idx >= 0 && idx == widget.quizzes.length - 1) ? 'Finish' : 'Next'),
              ),
              if (widget.status == 'stopped')
                TextButton.icon(
                  onPressed: () => _openResultsDialog(context),
                  icon: const Icon(Icons.insights),
                  label: const Text('View results'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startTopic(BuildContext context) async {
    if (widget.quizzes.isEmpty) return;
    _setBusy(true);
    try {
      final fs = FirebaseFirestore.instance;
      final first = widget.quizzes.first;
      await fs.doc('quizTopics/${widget.topicId}').set({
        'status': 'running',
        'phase': 'question',
        'currentIndex': 0,
        'currentQuizId': first.id,
        'questionStartedAt': FieldValue.serverTimestamp(),
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'showSummaryOnDisplay': false,
      }, SetOptions(merge: true));
      _snack(context, 'Topic started.');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _toggleReveal(BuildContext context, {required bool onQuestion, required bool onReveal}) async {
    if (onQuestion) return _revealCurrent(context);
    if (onReveal) return _hideReveal(context);
  }

  Future<void> _hideReveal(BuildContext context) async {
    _setBusy(true);
    try {
      final fs = FirebaseFirestore.instance;
      await fs.doc('quizTopics/${widget.topicId}').set({
        'phase': 'question',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack(context, 'Hide results.');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _revealCurrent(BuildContext context) async {
    final idx = widget.currentIndex ?? -1;
    if (idx < 0 || idx >= widget.quizzes.length) return;
    final startedAt = widget.questionStartedAt;
    if (startedAt == null) return;

    _setBusy(true);
    try {
      final fs = FirebaseFirestore.instance;
      final qDoc = widget.quizzes[idx];

      await fs.doc('quizTopics/${widget.topicId}').set({
        'phase': 'reveal',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      () async {
        try {
          final counts = await _computeCountsForQuiz(
            qDoc,
            startedAt: startedAt,
            endedAt: Timestamp.now(),
          );
          await fs.doc('quizTopics/${widget.topicId}/results/${qDoc.id}').set({
            'counts': counts,
            'correctIndex': (qDoc.data()['correctIndex'] as num?)?.toInt(),
            'startedAt': startedAt,
            'endedAt': FieldValue.serverTimestamp(),
            'computedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {
          _snack(context, '집계가 지연되고 있습니다. 잠시 후 자동 반영됩니다.');
        }
      }();

      _snack(context, 'Answer revealed.');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _nextOrFinish(BuildContext context) async {
    final idx = widget.currentIndex ?? -1;
    if (idx < 0 || idx >= widget.quizzes.length) return;
    final startedAt = widget.questionStartedAt;
    if (startedAt == null) return;

    _setBusy(true);
    try {
      final fs = FirebaseFirestore.instance;
      final qDoc = widget.quizzes[idx];

      try {
        final counts = await _computeCountsForQuiz(
          qDoc,
          startedAt: startedAt,
          endedAt: Timestamp.now(),
        );
        await fs.doc('quizTopics/${widget.topicId}/results/${qDoc.id}').set({
          'counts': counts,
          'correctIndex': (qDoc.data()['correctIndex'] as num?)?.toInt(),
          'startedAt': startedAt,
          'endedAt': FieldValue.serverTimestamp(),
          'computedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        _snack(context, '집계가 지연되고 있습니다. 잠시 후 자동 반영됩니다.');
      }

      if (idx == widget.quizzes.length - 1) {
        await fs.doc('quizTopics/${widget.topicId}').set({
          'status': 'stopped',
          'phase': 'finished',
          'currentIndex': null,
          'currentQuizId': null,
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'showSummaryOnDisplay': false,
        }, SetOptions(merge: true));
        _snack(context, 'Topic finished.');
      } else {
        final next = widget.quizzes[idx + 1];
        await fs.doc('quizTopics/${widget.topicId}').set({
          'phase': 'question',
          'currentIndex': idx + 1,
          'currentQuizId': next.id,
          'questionStartedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'showSummaryOnDisplay': false,
        }, SetOptions(merge: true));
        _snack(context, 'Next question.');
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _openResultsDialog(BuildContext context) async {
    final fs = FirebaseFirestore.instance;
    final quizzes = widget.quizzes;

    await fs.doc('quizTopics/${widget.topicId}').set({
      'showSummaryOnDisplay': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Results'),
          content: SizedBox(
            width: 500,
            child: FutureBuilder<List<_QuizWithResult>>(
              future: () async {
                final list = <_QuizWithResult>[];
                for (final q in quizzes) {
                  final x = q.data();
                  final res = await fs.doc('quizTopics/${widget.topicId}/results/${q.id}').get();
                  list.add(
                    _QuizWithResult(
                      question: (x['question'] as String?) ?? '',
                      choices: (x['choices'] as List?)?.map((e) => e.toString()).toList() ?? const [],
                      correctIndex: (x['correctIndex'] as num?)?.toInt(),
                      counts: ((res.data()?['counts'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
                    ),
                  );
                }
                return list;
              }(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
                }
                final data = snap.data!;
                if (data.isEmpty) return const Text('집계된 결과가 없습니다.');
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in data) ...[
                        Text(item.question, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        for (int i = 0; i < item.choices.length; i++)
                          Row(
                            children: [
                              Icon(i == item.correctIndex ? Icons.check_circle : Icons.circle_outlined,
                                  size: 16, color: i == item.correctIndex ? Colors.green : Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(child: Text('${String.fromCharCode(65 + i)}. ${item.choices[i]}')),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(' ${i < item.counts.length ? item.counts[i] : 0} '),
                              ),
                            ],
                          ),
                        const Divider(height: 18),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } finally {
      await fs.doc('quizTopics/${widget.topicId}').set({
        'showSummaryOnDisplay': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<List<int>> _computeCountsForQuiz(
    QueryDocumentSnapshot<Map<String, dynamic>> quizDoc, {
    required Timestamp startedAt,
    required Timestamp endedAt,
  }) async {
    final fs = FirebaseFirestore.instance;

    final hub = await fs.doc('hubs/$kHubId').get();
    final sid = hub.data()?['currentSessionId'] as String?;
    if (sid == null || sid.isEmpty) {
      final choiceLen = ((quizDoc.data()['choices'] as List?) ?? const []).length;
      return List<int>.filled(choiceLen, 0);
    }

    final qx = quizDoc.data();
    final List<String> triggers = (qx['triggers'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final choiceLen = triggers.length;

    final q = await fs
        .collection('sessions/$sid/events')
        .where('ts', isGreaterThanOrEqualTo: startedAt)
        .orderBy('ts', descending: false)
        .get();

    final startMs = startedAt.millisecondsSinceEpoch;
    final endMs = endedAt.millisecondsSinceEpoch;

    final Map<String, _Last> last = {};
    for (final d in q.docs) {
      final x = d.data();
      final ts = x['ts'] as Timestamp?;
      if (ts == null) continue;
      final t = ts.millisecondsSinceEpoch;
      if (t < startMs || t > endMs) continue;

      final sidStudent = x['studentId'] as String?;
      final slotIndex = x['slotIndex']?.toString();
      final clickType = (x['clickType'] as String?)?.toLowerCase();

      if (sidStudent == null) continue;
      if (slotIndex != '1' && slotIndex != '2') continue;
      if (clickType != 'click' && clickType != 'hold') continue;

      final trig = (slotIndex == '1')
          ? (clickType == 'click' ? 'S1_CLICK' : 'S1_HOLD')
          : (clickType == 'click' ? 'S2_CLICK' : 'S2_HOLD');

      last[sidStudent] = _Last(t, trig);
    }

    final counts = List<int>.filled(choiceLen, 0);
    for (final v in last.values) {
      final idx = triggers.indexOf(v.trig);
      if (idx >= 0 && idx < counts.length) counts[idx]++;
    }
    return counts;
  }
}

class _Last {
  final int t;
  final String trig;
  _Last(this.t, this.trig);
}

// ------------------- Create Quiz Page (새 화면 • 디자인 반영) -------------------

class _AddQuizFab extends StatelessWidget {
  const _AddQuizFab({required this.topicId, required this.fs});
  final String topicId;
  final FirebaseFirestore fs;

  @override
  Widget build(BuildContext context) {
    return _DraggableFabImage(
      assetPath: kFabAddQuizAsset,
      semanticsLabel: 'Add quiz',
      initialOffset: const Offset(16, 100),
      onTap: () async {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => _CreateQuizPage(topicId: topicId, fs: fs),
            fullscreenDialog: true,
          ),
        );
        if (created == true && context.mounted) {
          _snack(context, 'Quiz created.');
        }
      },
    );
  }
}

class _CreateQuizPage extends StatefulWidget {
  const _CreateQuizPage({required this.topicId, required this.fs});
  final String topicId;
  final FirebaseFirestore fs;

  @override
  State<_CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends State<_CreateQuizPage> {
  final TextEditingController _qCtrl = TextEditingController();
  final List<TextEditingController> _choiceCtrls = <TextEditingController>[
    TextEditingController(),
    TextEditingController()
  ];
  final List<String?> _triggerKeys = <String?>['S1_CLICK', 'S2_CLICK'];

  bool _allowMultiple = false;
  bool _anonymous = false;
  String _showMode = 'realtime'; // 'realtime' | 'after'

  int _correctIndex = 0; // 단일정답
  final Set<int> _correctSet = {0}; // 복수정답

  static const Map<String, String> _kTriggerOptions = <String, String>{
    'S1_CLICK': '1 • click',
    'S1_HOLD': '1 • hold',
    'S2_CLICK': '2 • click',
    'S2_HOLD': '2 • hold',
  };

  @override
  void dispose() {
    _qCtrl.dispose();
    for (final c in _choiceCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureTriggerLength() {
    while (_triggerKeys.length < _choiceCtrls.length) {
      final opts = _kTriggerOptions.keys.toList();
      final used = _triggerKeys.whereType<String>().toSet();
      final firstFree = opts.firstWhere((k) => !used.contains(k), orElse: () => opts.first);
      _triggerKeys.add(firstFree);
    }
    while (_triggerKeys.length > _choiceCtrls.length) {
      _triggerKeys.removeLast();
    }
  }

  List<String> _availableForIndex(int idx) {
    final used = _triggerKeys.toList()..removeAt(idx);
    return _kTriggerOptions.keys.where((k) => !used.contains(k)).toList();
  }

  void _addChoice() {
    if (_choiceCtrls.length >= 4) return;
    setState(() {
      _choiceCtrls.add(TextEditingController());
      _ensureTriggerLength();
      if (!_allowMultiple && _correctIndex >= _choiceCtrls.length) {
        _correctIndex = _choiceCtrls.length - 1;
      }
    });
  }

  void _removeChoice(int idx) {
    if (_choiceCtrls.length <= 2) return;
    setState(() {
      final c = _choiceCtrls.removeAt(idx);
      c.dispose();
      _ensureTriggerLength();
      if (_allowMultiple) {
        _correctSet.remove(idx);
        final newSet = <int>{};
        for (final v in _correctSet) {
          newSet.add(v > idx ? v - 1 : v);
        }
        _correctSet
          ..clear()
          ..addAll(newSet.isEmpty ? {0} : newSet);
      } else {
        if (_correctIndex >= _choiceCtrls.length) _correctIndex = _choiceCtrls.length - 1;
      }
    });
  }

  Future<void> _save() async {
  final q = _qCtrl.text.trim();
  final choices = _choiceCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
  if (q.isEmpty || choices.length < 2) {
    _snack(context, '문제와 최소 2개의 선택지를 입력하세요.');
    return;
  }
  if (_triggerKeys.length != choices.length || _triggerKeys.any((k) => k == null)) {
    _snack(context, '모든 선택지에 트리거를 지정하세요.');
    return;
  }
  final used = <String>{};
  for (final k in _triggerKeys.whereType<String>()) {
    if (!used.add(k)) {
      _snack(context, '트리거가 중복되었습니다: $k');
      return;
    }
  }

  List<int> correctIndices = const [];
  int? correctIndex;

  if (_allowMultiple) {
    correctIndices = _correctSet.where((i) => i >= 0 && i < choices.length).toList()..sort();
    if (correctIndices.isEmpty) {
      _snack(context, '복수정답 모드에서는 최소 1개 이상 정답을 선택하세요.');
      return;
    }
    correctIndex = correctIndices.first; // 보기용 대표 인덱스
  } else {
    if (_correctIndex < 0 || _correctIndex >= choices.length) {
      _snack(context, '정답 인덱스가 올바르지 않습니다.');
      return;
    }
    correctIndex = _correctIndex;
  }

  // ✅ add()에서는 FieldValue.delete() 쓰지 말 것!
  final data = <String, dynamic>{
    'question': q,
    'choices': choices,
    'triggers': _triggerKeys.whereType<String>().toList(),
    'anonymous': _anonymous,
    'allowMultiple': _allowMultiple,
    'showMode': _showMode, // 'realtime' | 'after'
    'correctIndex': correctIndex,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (_allowMultiple) {
    data['correctIndices'] = correctIndices;
  }
  // 단일정답일 땐 correctIndices를 아예 넣지 않음

  await widget.fs.collection('quizTopics/${widget.topicId}/quizzes').add(data);

  if (mounted) Navigator.pop(context, true);
}


  @override
  Widget build(BuildContext context) {
    _ensureTriggerLength();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 246, 250, 255),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text('Create quiz'),
      ),
      // ⬇️ FAB 대신 Stack으로 둥둥 저장 버튼 오버레이
      body: Stack(
        children: [
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.8, // 생성 페이지도 80%
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 180), // 좌우 마진 ↑, 하단 여유 ↑
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionCard(
                      title: 'Quiz question',
                      child: TextField(
                        controller: _qCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Did you understand today’s lesson?',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Answer Options   ·  up to 4',
                      trailing: IconButton(
                        tooltip: 'Add option',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _choiceCtrls.length >= 4 ? null : _addChoice,
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < _choiceCtrls.length; i++)
                            Padding(
                              padding: EdgeInsets.only(bottom: i == _choiceCtrls.length - 1 ? 0 : 10),
                              child: _OptionRow(
                                index: i,
                                controller: _choiceCtrls[i],
                                triggerValue: _triggerKeys[i],
                                triggerLabelMap: _kTriggerOptions,
                                availableValues: _availableForIndex(i),
                                allowMultiple: _allowMultiple,
                                selectedInMulti: _correctSet.contains(i),
                                singleSelectedIndex: _correctIndex,
                                onTriggerChanged: (v) => setState(() => _triggerKeys[i] = v),
                                onRemove: _choiceCtrls.length <= 2 ? null : () => _removeChoice(i),
                                onMarkCorrectSingle: () => setState(() => _correctIndex = i),
                                onToggleCorrectMulti: () => setState(() {
                                  if (_correctSet.contains(i)) {
                                    if (_correctSet.length == 1) return;
                                    _correctSet.remove(i);
                                  } else {
                                    _correctSet.add(i);
                                  }
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Quiz Settings',
                      child: Column(
                        children: [
                          _SettingRow(
                            label: 'Show results',
                            leading: const Text('in real time'),
                            trailing: const Text('After voting ends'),
                            valueLeft: _showMode == 'realtime',
                            onChanged: (left) => setState(() => _showMode = left ? 'realtime' : 'after'),
                          ),
                          const SizedBox(height: 8),
                          _SettingRow(
                            label: 'Anonymous',
                            leading: const Text('yes'),
                            trailing: const Text('no'),
                            valueLeft: _anonymous,
                            onChanged: (left) => setState(() => _anonymous = left),
                          ),
                          const SizedBox(height: 8),
                          _SettingRow(
                            label: 'Multiple selections',
                            leading: const Text('yes'),
                            trailing: const Text('no'),
                            valueLeft: _allowMultiple,
                            onChanged: (left) {
                              setState(() {
                                _allowMultiple = left;
                                if (_allowMultiple) {
                                  _correctSet
                                    ..clear()
                                    ..add(_correctIndex);
                                } else {
                                  _correctIndex = _correctSet.isEmpty ? 0 : _correctSet.first;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ⬇️ 둥둥 떠다니는 Save 이미지 버튼
          _SaveQuizFabImage(onTap: _save),
        ],
      ),
    );
  }
}


class _SaveQuizFabImage extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveQuizFabImage({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: 200,
          height: 200,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              hoverColor: Colors.black.withOpacity(0.05),   // 마우스 오버 효과
              splashColor: Colors.black.withOpacity(0.1),   // 클릭 잔물결 효과
              onTap: onTap,
              child: Tooltip(
                message: 'Save quiz', // 마우스 올렸을 때 표시
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Image.asset(
                    'assets/logo_bird_save.png', // 원하는 이미지 경로
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.save_alt,
                      size: 64,
                      color: Colors.indigo,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Pretty section / rows ----

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDAE2EE)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B1324),
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.index,
    required this.controller,
    required this.triggerValue,
    required this.triggerLabelMap,
    required this.availableValues,
    required this.allowMultiple,
    required this.selectedInMulti,
    required this.singleSelectedIndex,
    required this.onTriggerChanged,
    required this.onRemove,
    required this.onMarkCorrectSingle,
    required this.onToggleCorrectMulti,
  });

  final int index;
  final TextEditingController controller;
  final String? triggerValue;
  final Map<String, String> triggerLabelMap;
  final List<String> availableValues;

  final bool allowMultiple;
  final bool selectedInMulti;
  final int singleSelectedIndex;

  final ValueChanged<String?> onTriggerChanged;
  final VoidCallback? onRemove;
  final VoidCallback onMarkCorrectSingle;
  final VoidCallback onToggleCorrectMulti;

  @override
  Widget build(BuildContext context) {
    final isCorrect = allowMultiple ? selectedInMulti : (singleSelectedIndex == index);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDAE2EE)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          allowMultiple
              ? Checkbox(value: selectedInMulti, onChanged: (_) => onToggleCorrectMulti())
              : Radio<int>(value: index, groupValue: singleSelectedIndex, onChanged: (_) => onMarkCorrectSingle()),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Option',
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120, maxWidth: 150),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: triggerValue,
                items: availableValues
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(triggerLabelMap[k] ?? k),
                      ),
                    )
                    .toList()
                  ..sort((a, b) => (a.child as Text).data!.compareTo((b.child as Text).data!)),
                onChanged: onTriggerChanged,
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onPressed: onRemove,
          ),
          if (isCorrect)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.check_circle, color: Colors.green, size: 18),
            ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.leading,
    required this.trailing,
    required this.valueLeft,
    required this.onChanged,
  });

  final String label;
  final Widget leading;
  final Widget trailing;
  final bool valueLeft; // true면 왼쪽 옵션
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDAE2EE)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Row(
            children: [
              _DotRadio(
                selected: valueLeft,
                onTap: () => onChanged(true),
                child: leading,
              ),
              const SizedBox(width: 14),
              _DotRadio(
                selected: !valueLeft,
                onTap: () => onChanged(false),
                child: trailing,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DotRadio extends StatelessWidget {
  const _DotRadio({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
      ),
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 8),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2563EB),
              ),
            )
          : const SizedBox.shrink(),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Row(
        children: [
          dot,
          DefaultTextStyle.merge(
            style: TextStyle(color: selected ? const Color(0xFF0B1324) : const Color(0xFF6B7280)),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ------------------- 둥둥 떠다니는 이미지 FAB -------------------

class _DraggableFabImage extends StatefulWidget {
  const _DraggableFabImage({
    required this.assetPath,
    required this.onTap,
    required this.semanticsLabel,
    this.initialOffset = const Offset(16, 16),
    this.size = 64,
  });

  final String assetPath;
  final VoidCallback onTap;
  final String semanticsLabel;
  final Offset initialOffset;
  final double size;

  @override
  State<_DraggableFabImage> createState() => _DraggableFabImageState();
}

class _DraggableFabImageState extends State<_DraggableFabImage> {
  late Offset _offset; // from bottom-right

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaMemo(context);
    final bottom = _offset.dy;
    final right = _offset.dx;

    return Positioned(
      bottom: bottom,
      right: right,
      child: Draggable(
        feedback: _fabBody(opacity: 0.8),
        childWhenDragging: const SizedBox.shrink(),
        onDragEnd: (d) {
          final size = mq.size;
          // global → 기준 오프셋 근사치 (간단화)
          final local = d.offset;
          final newRight = (size.width - local.dx - widget.size / 2).clamp(8, size.width - 8);
          final newBottom = (size.height - local.dy - widget.size / 2).clamp(8, size.height - 8);
          setState(() {
            _offset = Offset(newRight.toDouble(), newBottom.toDouble());
          });
        },
        child: _fabBody(),
      ),
    );
  }

  Widget _fabBody({double opacity = 1}) {
    return Semantics(
      label: widget.semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: opacity,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              widget.assetPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.indigo,
                alignment: Alignment.center,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 작은 유틸: 미디어쿼리 size 캐시
class MediaMemo {
  MediaMemo(BuildContext ctx) : size = MediaQuery.of(ctx).size;
  final Size size;
}

// ------------------- 공용 -------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _QuizWithResult {
  final String question;
  final List<String> choices;
  final int? correctIndex;
  final List<int> counts;
  _QuizWithResult({
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.counts,
  });
}

void _snack(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  (m ?? ScaffoldMessenger.of(context))
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> _maybeStopRunningTopic({
  required String status,
  required String topicId,
}) async {
  if (status != 'running') return;
  final fs = FirebaseFirestore.instance;
  await fs.doc('quizTopics/$topicId').set({
    'status': 'stopped',
    'phase': 'finished',
    'currentIndex': null,
    'currentQuizId': null,
    'endedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'showSummaryOnDisplay': false,
  }, SetOptions(merge: true));
}

