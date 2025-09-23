// lib/pages/quiz/topic_detail.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/hub_provider.dart';
import 'create_quiz_page.dart'; // CreateQuizPage (다른 파일)

// ───────────────────────── Topic Detail Page ─────────────────────────

class TopicDetailPage extends StatelessWidget {
  const TopicDetailPage({required this.topicId});
  final String topicId;

  @override
  Widget build(BuildContext context) {
    final hubId = context.watch<HubProvider>().hubId;
    if (hubId == null) {
      return const Scaffold(
        body: Center(child: Text('허브를 먼저 선택하세요.')),
      );
    }

    final fs = FirebaseFirestore.instance;
    final String prefix = 'hubs/$hubId';
    final topicStream = fs.doc('$prefix/quizTopics/$topicId').snapshots();
    final quizzesStream = fs
        .collection('$prefix/quizTopics/$topicId/quizzes')
        .orderBy('createdAt', descending: false)
        .snapshots();

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
            return WillPopScope(
              onWillPop: () async {
                await _maybeStopRunningTopic(
                  fs: fs,
                  hubId: hubId,
                  status: status,
                  topicId: topicId,
                );
                return true;
              },
              child: Scaffold(
                backgroundColor: const Color.fromARGB(255, 246, 250, 255),
                appBar: AppBar(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  leading: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () async {
                      await _maybeStopRunningTopic(
                        fs: fs,
                        hubId: hubId,
                        status: status,
                        topicId: topicId,
                      );
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
                              hubId: hubId,
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
                                        hubId: hubId,
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
                      hubId: hubId,
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

// ───────────────────────── Create Quiz FAB (floating image) ─────────────────────────

class _CreateQuizFabImage extends StatelessWidget {
  const _CreateQuizFabImage({
    required this.hubId,
    required this.topicId,
    required this.fs,
    this.isRunning = false,
  });

  final String hubId;
  final String topicId;
  final FirebaseFirestore fs;
  final bool isRunning;

  Future<void> _handleStartStop(BuildContext context) async {
    // CreateQuizPage도 내부에서 HubProvider를 읽어 경로를 prefix(hubs/{hubId})로 사용하도록 구현되어 있어야 해요.
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateQuizPage(topicId: topicId, fs: fs),
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

// ───────────────────────── Quiz Card (with "more") ─────────────────────────

class _QuizCardTile extends StatefulWidget {
  const _QuizCardTile({
    required this.hubId,
    required this.topicId,
    required this.fs,
    required this.quizDoc,
    required this.isCurrent,
    required this.topicStatus,
  });

  final String hubId;
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

    final prefix = 'hubs/${widget.hubId}';

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: widget.fs.doc('$prefix/quizTopics/${widget.topicId}/results/${d.id}').get(),
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
                // 헤더
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
                    IconButton(
                      tooltip: _showMore ? 'Less' : 'More',
                      icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
                      onPressed: () => setState(() => _showMore = !_showMore),
                    ),
                    IconButton(
                      tooltip: 'Edit (설정)',
                      icon: const Icon(Icons.edit),
                      onPressed: () =>
                          _editQuizDialog(context, widget.fs, prefix: prefix, topicId: widget.topicId, quizId: d.id, initial: x),
                    ),
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
                            final quizRef = widget.fs.doc('$prefix/quizTopics/${widget.topicId}/quizzes/${d.id}');
                            final resRef  = widget.fs.doc('$prefix/quizTopics/${widget.topicId}/results/${d.id}');
                            batch.delete(quizRef);
                            batch.delete(resRef);
                            await batch.commit();

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

                // more
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

                  Row(
                    children: const [
                      Icon(Icons.touch_app, size: 18, color: Colors.indigo),
                      SizedBox(width: 6),
                      Text(
                        '누르는 방식 및 인원수',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.indigo),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  for (int i = 0; i < choices.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _triggerChip(triggers.length > i ? (triggers[i] as String?) : null),
                          const SizedBox(width: 8),
                          Icon(
                            _isCorrectIdx(i) ? Icons.check_circle : Icons.circle_outlined,
                            size: 18,
                            color: _isCorrectIdx(i) ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${String.fromCharCode(65 + i)}. ${choices[i]}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(' ${i < counts.length ? counts[i] : 0} '),
                          ),
                        ],
                      ),
                    ),

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

// ───────────────────────── Trigger label & chip ─────────────────────────

const _kTriggerLabel = <String, String>{
  'S1_CLICK': 'Button 1 • Click',
  'S1_HOLD': 'Button 1 • Hold',
  'S2_CLICK': 'Button 2 • Click',
  'S2_HOLD': 'Button 2 • Hold',
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

// ───────────────────────── Edit Quiz Dialog (single-answer) ─────────────────────────

Future<void> _editQuizDialog(
  BuildContext context,
  FirebaseFirestore fs, {
  required String prefix, // hubs/{hubId}
  required String topicId,
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
  if (choiceCtrls.length < 2) {
    choiceCtrls.addAll([TextEditingController(), TextEditingController()]);
  }
  final List<String?> triggerKeys =
      <String?>[...initTriggers.map((e) => e?.toString()).cast<String?>()];
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
                    decoration: const InputDecoration(
                      labelText: 'Question',
                      border: OutlineInputBorder(),
                    ),
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
                                      .map((k) => DropdownMenuItem(
                                            value: k,
                                            child: Text(_kTriggerLabel[k] ?? k),
                                          ))
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
                    child: Text(
                      '라디오가 선택된 항목이 정답입니다. 각 선택지에는 Flic 입력 트리거를 하나씩 매핑하세요.',
                      style: TextStyle(color: Colors.grey),
                    ),
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

                  await fs.doc('$prefix/quizTopics/$topicId/quizzes/$quizId').set({
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

// ───────────────────────── Run Bar (start/reveal/next/results) ─────────────────────────

class _RunBar extends StatefulWidget {
  const _RunBar({
    required this.hubId,
    required this.topicId,
    required this.quizzes,
    required this.status,
    required this.phase,
    required this.currentIndex,
    required this.currentQuizId,
    required this.questionStartedAt,
  });

  final String hubId;
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isRunning ? (onReveal ? 'Running • Reveal' : 'Running • Question') : (widget.status == 'stopped' ? 'Stopped' : 'Draft'),
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
          const SizedBox(height: 10),
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

  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  String get _prefix => 'hubs/${widget.hubId}';

  Future<void> _startTopic(BuildContext context) async {
    if (widget.quizzes.isEmpty) return;
    _setBusy(true);
    try {
      final first = widget.quizzes.first;
      await _fs.doc('$_prefix/quizTopics/${widget.topicId}').set({
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
      await _fs.doc('$_prefix/quizTopics/${widget.topicId}').set({
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
      final qDoc = widget.quizzes[idx];

      await _fs.doc('$_prefix/quizTopics/${widget.topicId}').set({
        'phase': 'reveal',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      () async {
        try {
          final counts = await _computeCountsForQuiz(
            qDoc,
            startedAt: startedAt,
            endedAt: Timestamp.now(),
            prefix: _prefix,
          );
          await _fs.doc('$_prefix/quizTopics/${widget.topicId}/results/${qDoc.id}').set({
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
      final qDoc = widget.quizzes[idx];

      try {
        final counts = await _computeCountsForQuiz(
          qDoc,
          startedAt: startedAt,
          endedAt: Timestamp.now(),
          prefix: _prefix,
        );
        await _fs.doc('$_prefix/quizTopics/${widget.topicId}/results/${qDoc.id}').set({
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
        await _fs.doc('$_prefix/quizTopics/${widget.topicId}').set({
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
        await _fs.doc('$_prefix/quizTopics/${widget.topicId}').set({
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
    final quizzes = widget.quizzes;

    await _fs.doc('$_prefix/quizTopics/${widget.topicId}').set({
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
                  final res =
                      await _fs.doc('$_prefix/quizTopics/${widget.topicId}/results/${q.id}').get();
                  list.add(
                    _QuizWithResult(
                      question: (x['question'] as String?) ?? '',
                      choices: (x['choices'] as List?)?.map((e) => e.toString()).toList() ?? const [],
                      correctIndex: (x['correctIndex'] as num?)?.toInt(),
                      counts: ((res.data()?['counts'] as List?) ?? const [])
                          .map((e) => (e as num).toInt())
                          .toList(),
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
                              Icon(
                                i == item.correctIndex ? Icons.check_circle : Icons.circle_outlined,
                                size: 16,
                                color: i == item.correctIndex ? Colors.green : Colors.grey,
                              ),
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
      await _fs.doc('$_prefix/quizTopics/${widget.topicId}').set({
        'showSummaryOnDisplay': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<List<int>> _computeCountsForQuiz(
    QueryDocumentSnapshot<Map<String, dynamic>> quizDoc, {
    required Timestamp startedAt,
    required Timestamp endedAt,
    required String prefix, // hubs/{hubId}
  }) async {
    // hubs/{hubId} 문서에서 currentSessionId 참조
    final hubDoc = await _fs.doc(prefix).get();
    final sid = hubDoc.data()?['currentSessionId'] as String?;
    if (sid == null || sid.isEmpty) {
      final choiceLen = ((quizDoc.data()['choices'] as List?) ?? const []).length;
      return List<int>.filled(choiceLen, 0);
    }

    final qx = quizDoc.data();
    final List<String> triggers =
        (qx['triggers'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final choiceLen = triggers.length;

    final q = await _fs
        .collection('$prefix/sessions/$sid/events')
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

// ───────────────────────── Small shared widget & models ─────────────────────────

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
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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

// ───────────────────────── Local utils ─────────────────────────

void _snack(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  (m ?? ScaffoldMessenger.of(context))
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> _maybeStopRunningTopic({
  required FirebaseFirestore fs,
  required String hubId,
  required String status,
  required String topicId,
}) async {
  if (status != 'running') return;
  final prefix = 'hubs/$hubId';
  await fs.doc('$prefix/quizTopics/$topicId').set({
    'status': 'stopped',
    'phase': 'finished',
    'currentIndex': null,
    'currentQuizId': null,
    'endedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'showSummaryOnDisplay': false,
  }, SetOptions(merge: true));
}

class _Last {
  final int t;
  final String trig;
  _Last(this.t, this.trig);
}
