// lib/pages/quiz/presenter_quiz_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const String kHubId = 'hub-001'; // 집계용: hubs/{hubId}.currentSessionId 사용

/// Presenter Quiz (Top-level: quizTopics/{topicId}/quizzes/{quizId})
/// - Topic: title, status(draft|running|stopped), startedAt, endedAt,
///          currentIndex, currentQuizId, phase('question'|'reveal'|'finished'),
///          questionStartedAt, showSummaryOnDisplay
/// - Quiz: question, choices[2..4], correctIndex, triggers[per choice]
///         triggers values: S1_CLICK, S1_HOLD, S2_CLICK, S2_HOLD
/// - Result: quizTopics/{topicId}/results/{quizId}
///           { counts: int[], correctIndex, startedAt, endedAt, computedAt }
class PresenterQuizPage extends StatelessWidget {
  const PresenterQuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Quiz (Presenter)'),
        actions: [
          IconButton(
            tooltip: 'Create topic',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _createTopicDialog(context),
          ),
        ],
      ),
      body: const _TopicList(),
    );
  }

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
        'phase': 'finished', // 초기엔 진행 아님
        'questionStartedAt': null,
        'showSummaryOnDisplay': false,
      });
      _snack(context, 'Topic created.');
    }
  }
}

class _TopicList extends StatelessWidget {
  const _TopicList();

  Color _statusColor(String s) {
    switch (s) {
      case 'running':
        return Colors.green;
      case 'stopped':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final stream = fs
        .collection('quizTopics')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const _EmptyState(
            title: 'No topics yet',
            subtitle: '우측 상단 + 아이콘으로 토픽을 만들어 주세요.',
          );
        }

        final topics = snap.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) {
            final d = topics[i];
            final x = d.data();
            final title = (x['title'] as String?) ?? '(untitled)';
            final status = (x['status'] as String?) ?? 'draft';
            final color = _statusColor(status);

            return Card(
              child: ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color),
                      ),
                      child: Text(
                        (status).toUpperCase(),
                        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(d.id, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: IconButton(
                  tooltip: 'Delete topic',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete topic'),
                        content: const Text('이 토픽과 그 안의 퀴즈/결과가 모두 삭제됩니다. 계속할까요?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      // 하위 quizzes, results 삭제
                      final qs = await fs.collection('quizTopics/${d.id}/quizzes').get();
                      final rs = await fs.collection('quizTopics/${d.id}/results').get();
                      final batch = fs.batch();
                      for (final q in qs.docs) batch.delete(q.reference);
                      for (final r in rs.docs) batch.delete(r.reference);
                      batch.delete(d.reference);
                      await batch.commit();
                      _snack(context, 'Topic deleted.');
                    }
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _TopicDetailPage(topicId: d.id),
                    ),
                  );
                },
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: topics.length,
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
    final quizzesStream = fs
        .collection('quizTopics/$topicId/quizzes')
        .orderBy('createdAt', descending: false) // 진행 순서 = 생성 순서
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
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text('Topic • $title'),
                actions: [
                  IconButton(
                    tooltip: 'Create quiz',
                    icon: const Icon(Icons.note_add_outlined),
                    onPressed: () => _createQuizDialog(context, fs),
                  ),
                ],
              ),
              body: Column(
                children: [
                  // 진행 컨트롤 바
                  _RunBar(
                    topicId: topicId,
                    quizzes: quizzes,
                    status: status,
                    phase: phase,
                    currentIndex: currentIndex,
                    currentQuizId: currentQuizId,
                    questionStartedAt: questionStartedAt,
                  ),
                  const Divider(height: 0),
                  // 퀴즈 목록
                  Expanded(
                    child: quizzes.isEmpty
                        ? const _EmptyState(
                            title: 'No quizzes',
                            subtitle: '우측 상단 + 아이콘으로 퀴즈를 만들어 주세요.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemBuilder: (_, i) => _quizCard(context, fs, quizzes[i], topic,
                                isCurrent: currentQuizId == quizzes[i].id),
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemCount: quizzes.length,
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 개별 퀴즈 카드 + 최근 결과 표시 + 편집/삭제
  Widget _quizCard(
    BuildContext context,
    FirebaseFirestore fs,
    QueryDocumentSnapshot<Map<String, dynamic>> d,
    Map<String, dynamic>? topic, {
    required bool isCurrent,
  }) {
    final x = d.data();
    final question = (x['question'] as String?) ?? '(no question)';
    final List choices = (x['choices'] as List?) ?? const [];
    final correct = (x['correctIndex'] as num?)?.toInt();
    final List triggers = (x['triggers'] as List?) ?? const [];
    final status = (topic?['status'] as String?) ?? 'draft';

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: fs.doc('quizTopics/$topicId/results/${d.id}').get(),
      builder: (context, resSnap) {
        final res = resSnap.data?.data();
        final List? counts = res?['counts'] as List?;
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목 + 액션
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(question, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      tooltip: 'Edit quiz',
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editQuizDialog(context, fs, quizId: d.id, initial: x),
                    ),
                    IconButton(
                      tooltip: 'Delete quiz',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        // 진행 중이고 현재 문제면 삭제 차단(안전)
                        if (status == 'running' && isCurrent) {
                          _snack(context, '현재 진행 중인 퀴즈는 삭제할 수 없습니다. Next/Finish 후 삭제하세요.');
                          return;
                        }
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete quiz'),
                            content: const Text('이 퀴즈와 해당 결과가 삭제됩니다. 계속할까요?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          final batch = fs.batch();
                          batch.delete(fs.doc('quizTopics/$topicId/quizzes/${d.id}'));
                          batch.delete(fs.doc('quizTopics/$topicId/results/${d.id}'));
                          await batch.commit();
                          _snack(context, 'Quiz deleted.');
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 본문
                for (int idx = 0; idx < choices.length; idx++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          idx == correct ? Icons.check_circle : Icons.circle_outlined,
                          size: 18,
                          color: idx == correct ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${String.fromCharCode(65 + idx)}. ${choices[idx]}')),
                        const SizedBox(width: 8),
                        _triggerChip(triggers.length > idx ? (triggers[idx] as String?) : null),
                        if (counts != null && idx < counts.length)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(' ${counts[idx]} '),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Create quiz dialog (choices + correct + Flic trigger mapping) ──
  static const _kTriggerOptions = <String, String>{
    'S1_CLICK': 'Slot 1 • Click',
    'S1_HOLD' : 'Slot 1 • Hold',
    'S2_CLICK': 'Slot 2 • Click',
    'S2_HOLD' : 'Slot 2 • Hold',
  };

  Widget _triggerChip(String? key) {
    final label = key == null ? 'No trigger' : _kTriggerOptions[key] ?? key;
    final color = key == null ? Colors.grey : Colors.indigo;
    return Chip(
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color),
      backgroundColor: color.withOpacity(0.08),
      label: Text(label, style: TextStyle(color: color)),
    );
  }

  Future<void> _createQuizDialog(BuildContext context, FirebaseFirestore fs) async {
    final qCtrl = TextEditingController();
    final choiceCtrls = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];
    int correctIndex = 0;
    final triggerKeys = <String?>['S1_CLICK', 'S2_CLICK']; // 기본값 2개

    List<String> _availableForIndex(int idx) {
      final used = triggerKeys.toList()..removeAt(idx);
      return _kTriggerOptions.keys.where((k) => !used.contains(k)).toList();
    }

    void _ensureTriggerLength() {
      while (triggerKeys.length < choiceCtrls.length) {
        final opts = _kTriggerOptions.keys.toList();
        final used = triggerKeys.whereType<String>().toSet();
        final firstFree = opts.firstWhere((k) => !used.contains(k), orElse: () => opts.first);
        triggerKeys.add(firstFree);
      }
      while (triggerKeys.length > choiceCtrls.length) {
        triggerKeys.removeLast();
      }
    }

    void addChoiceSync() {
      if (choiceCtrls.length >= 4) return;
      choiceCtrls.add(TextEditingController());
      _ensureTriggerLength();
    }

    void removeChoiceSync(int idx) {
      if (choiceCtrls.length <= 2) return;
      final c = choiceCtrls.removeAt(idx);
      c.dispose();
      _ensureTriggerLength();
      if (correctIndex >= choiceCtrls.length) {
        correctIndex = choiceCtrls.length - 1;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            _ensureTriggerLength();
            return AlertDialog(
              title: const Text('Create quiz'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Question
                    TextField(
                      controller: qCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Question',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Choices 2~4 + trigger dropdown per choice + radio(correct)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Choices (2~4)', style: TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(
                          tooltip: 'Add choice',
                          onPressed: choiceCtrls.length >= 4
                              ? null
                              : () => setState(() {
                                    addChoiceSync();
                                  }),
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
                            // Correct radio
                            Radio<int>(
                              value: i,
                              groupValue: correctIndex,
                              onChanged: (v) => setState(() => correctIndex = v ?? correctIndex),
                            ),
                            // Choice text
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
                            // Trigger dropdown (unique per choice)
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
                                              child: Text(_kTriggerOptions[k] ?? k),
                                            ))
                                        .toList()
                                      ..sort((a, b) => (a.child as Text).data!
                                          .compareTo((b.child as Text).data!)),
                                    onChanged: (v) => setState(() {
                                      triggerKeys[i] = v;
                                    }),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Remove
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: choiceCtrls.length <= 2
                                  ? null
                                  : () => setState(() {
                                        removeChoiceSync(i);
                                      }),
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
                    // triggers 검증
                    if (triggerKeys.length != choices.length || triggerKeys.any((k) => k == null)) {
                      _snack(context, '모든 선택지에 트리거를 지정하세요.');
                      return;
                    }
                    final setCheck = <String>{};
                    for (final k in triggerKeys.whereType<String>()) {
                      if (!setCheck.add(k)) {
                        _snack(context, '트리거가 중복되었습니다: $k');
                        return;
                      }
                    }

                    await fs.collection('quizTopics/$topicId/quizzes').add({
                      'question': q,
                      'choices': choices,
                      'correctIndex': correctIndex,
                      'triggers': triggerKeys.whereType<String>().toList(),
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(context, true);
                    _snack(context, 'Quiz created.');
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    // clean up
    qCtrl.dispose();
    for (final c in choiceCtrls) {
      c.dispose();
    }
  }

  // ── Edit quiz dialog ──
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

    final choiceCtrls = <TextEditingController>[
      for (final c in initChoices) TextEditingController(text: c.toString()),
    ];
    if (choiceCtrls.length < 2) {
      choiceCtrls.addAll([TextEditingController(), TextEditingController()]);
    }
    final triggerKeys = <String?>[
      ...initTriggers.map((e) => e?.toString()).cast<String?>(),
    ];
    while (triggerKeys.length < choiceCtrls.length) {
      triggerKeys.add(null);
    }

    List<String> _availableForIndex(int idx) {
      final used = triggerKeys.toList()..removeAt(idx);
      return _kTriggerOptions.keys.where((k) => !used.contains(k)).toList();
    }

    void _ensureTriggerLength() {
      while (triggerKeys.length < choiceCtrls.length) {
        triggerKeys.add(null);
      }
      while (triggerKeys.length > choiceCtrls.length) {
        triggerKeys.removeLast();
      }
    }

    void addChoiceSync(StateSetter setState) {
      if (choiceCtrls.length >= 4) return;
      choiceCtrls.add(TextEditingController());
      setState(() {
        _ensureTriggerLength();
      });
    }

    void removeChoiceSync(StateSetter setState, int idx) {
      if (choiceCtrls.length <= 2) return;
      final c = choiceCtrls.removeAt(idx);
      c.dispose();
      if (correctIndex >= choiceCtrls.length) correctIndex = choiceCtrls.length - 1;
      setState(() {
        _ensureTriggerLength();
      });
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            _ensureTriggerLength();
            return AlertDialog(
              title: const Text('Edit quiz'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Question
                    TextField(
                      controller: qCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Question',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Choices 2~4 + trigger dropdown per choice + radio(correct)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Choices (2~4)', style: TextStyle(fontWeight: FontWeight.w700)),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Add choice',
                              onPressed: choiceCtrls.length >= 4
                                  ? null
                                  : () => addChoiceSync(setState),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
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
                            // Correct radio
                            Radio<int>(
                              value: i,
                              groupValue: correctIndex,
                              onChanged: (v) => setState(() => correctIndex = v ?? correctIndex),
                            ),
                            // Choice text
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
                            // Trigger dropdown
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
                                              child: Text(_kTriggerOptions[k] ?? k),
                                            ))
                                        .toList()
                                      ..sort((a, b) => (a.child as Text).data!
                                          .compareTo((b.child as Text).data!)),
                                    onChanged: (v) => setState(() {
                                      triggerKeys[i] = v;
                                    }),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Remove
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: choiceCtrls.length <= 2
                                  ? null
                                  : () => removeChoiceSync(setState, i),
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
                    // 중복 트리거 방지
                    final used = <String>{};
                    for (final k in triggerKeys.whereType<String>()) {
                      if (!used.add(k)) {
                        _snack(context, '트리거가 중복되었습니다: $k');
                        return;
                      }
                    }

                    await fs.doc('quizTopics/$topicId/quizzes/$quizId').set({
                      'question': q,
                      'choices': choices,
                      'correctIndex': correctIndex,
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

    // clean up
    qCtrl.dispose();
    for (final c in choiceCtrls) {
      c.dispose();
    }
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

    final current =
        (idx >= 0 && idx < widget.quizzes.length) ? widget.quizzes[idx] : null;
    final currentQ = current?.data();

    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태/현재 문제 표시
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
          const SizedBox(height: 8),

          // 버튼들 (로딩 오버레이/바 없음, 버튼만 잠깐 비활성화)
          Row(
            children: [
              // Start
              ElevatedButton.icon(
                onPressed: (!_busy && hasQuizzes && !isRunning)
                    ? () => _startTopic(context)
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start topic'),
              ),
              const SizedBox(width: 8),

              // Reveal 토글
              ElevatedButton.icon(
                onPressed: (!_busy && (onQuestion || onReveal))
                    ? () => _toggleReveal(context, onQuestion: onQuestion, onReveal: onReveal)
                    : null,
                icon: Icon(onReveal ? Icons.visibility_off : Icons.visibility),
                label: Text(onReveal ? 'Hide results' : 'Reveal answer'),
              ),
              const SizedBox(width: 8),

              // Next/Finish
              ElevatedButton.icon(
                onPressed: (!_busy && (onQuestion || onReveal))
                    ? () => _nextOrFinish(context)
                    : null,
                icon: const Icon(Icons.skip_next),
                label: Text((idx >= 0 && idx == widget.quizzes.length - 1) ? 'Finish' : 'Next'),
              ),
              const Spacer(),

              // 결과 보기 (stopped 상태): 디스플레이와 동기화
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

  // Reveal 토글
  Future<void> _toggleReveal(BuildContext context, {required bool onQuestion, required bool onReveal}) async {
    if (onQuestion) {
      // question -> reveal : 기존 로직 재사용 (집계 수행)
      return _revealCurrent(context);
    }
    if (onReveal) {
      // reveal -> question : 집계 없이 화면만 되돌림 (타임윈도우 유지)
      return _hideReveal(context);
    }
  }

  /// 리빌 해제: phase만 question 으로 되돌림 (questionStartedAt 유지)
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

    // 버튼만 잠깐 비활성화(시각적 로딩 표시 없음)
    _setBusy(true);
    try {
      final fs = FirebaseFirestore.instance;
      final qDoc = widget.quizzes[idx];

      // 1) 먼저 phase만 'reveal'로 바꿔 디스플레이가 즉시 전환되게 함
      await fs.doc('quizTopics/${widget.topicId}').set({
        'phase': 'reveal',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2) 집계는 백그라운드로 수행 (await하지 않음 → 오버레이/로딩 없음)
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
        } catch (e) {
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

      // 현재 퀴즈 최종 집계 저장(덮어쓰기) - 버튼만 잠깐 비활성화, 로딩표시 없음
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

      // 다음으로 이동 or 종료
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

    // 디스플레이에 결과 띄우기 ON
    await fs.doc('quizTopics/${widget.topicId}').set({
      'showSummaryOnDisplay': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
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
      // Dialog 닫히면 디스플레이 결과 OFF
      await fs.doc('quizTopics/${widget.topicId}').set({
        'showSummaryOnDisplay': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ------------- 집계 로직 -------------
  // events → 학생별 마지막 트리거 → 선택지 index 매핑 → counts[]
  Future<List<int>> _computeCountsForQuiz(
    QueryDocumentSnapshot<Map<String, dynamic>> quizDoc, {
    required Timestamp startedAt,
    required Timestamp endedAt,
  }) async {
    final fs = FirebaseFirestore.instance;

    // 세션 확인 (허브 현재 세션)
    final hub = await fs.doc('hubs/$kHubId').get();
    final sid = hub.data()?['currentSessionId'] as String?;
    if (sid == null || sid.isEmpty) {
      final choiceLen = ((quizDoc.data()['choices'] as List?) ?? const []).length;
      return List<int>.filled(choiceLen, 0);
    }

    // 퀴즈 정의
    final qx = quizDoc.data();
    final List<String> triggers = (qx['triggers'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final choiceLen = triggers.length;

    // 이벤트: 시작~종료 구간
    final q = await fs
        .collection('sessions/$sid/events')
        .where('ts', isGreaterThanOrEqualTo: startedAt)
        .orderBy('ts', descending: false)
        .get();

    final startMs = startedAt.millisecondsSinceEpoch;
    final endMs = endedAt.millisecondsSinceEpoch;

    // 학생별 마지막 트리거
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

    // counts
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

/// snack helper
void _snack(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  (m ?? ScaffoldMessenger.of(context))
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
