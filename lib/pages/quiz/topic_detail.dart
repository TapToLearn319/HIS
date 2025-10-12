// lib/pages/quiz/topic_detail.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';
import 'question_options_page.dart';

class TopicDetailPage extends StatelessWidget {
  const TopicDetailPage({required this.topicId, super.key});
  final String topicId;

  Future<int?> _loadOrdinal({
    required FirebaseFirestore fs,
    required String hubId,
    required String topicId,
  }) async {
    final qs =
        await fs
            .collection('hubs/$hubId/quizTopics')
            .orderBy('createdAt', descending: false)
            .get();
    for (var i = 0; i < qs.docs.length; i++) {
      if (qs.docs[i].id == topicId) return i + 1; // 1-base index
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hubId = context.watch<HubProvider>().hubId;
    if (hubId == null) {
      return const Scaffold(body: Center(child: Text('허브를 먼저 선택하세요.')));
    }

    final fs = FirebaseFirestore.instance;
    final prefix = 'hubs/$hubId';

    final topicRef = fs.doc('$prefix/quizTopics/$topicId');

    _ensureDefaultSettings(topicRef);

    final quizzesCol = fs
        .collection('$prefix/quizTopics/$topicId/quizzes')
        .orderBy('createdAt', descending: false);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: topicRef.snapshots(),
      builder: (context, tSnap) {
        final t = tSnap.data?.data();
        final title = (t?['title'] as String?) ?? '(untitled)';
        final status = (t?['status'] as String?) ?? 'draft';
        final int maxQuestions = (t?['maxQuestions'] as num?)?.toInt() ?? 1;

        final showResultsMode =
            (t?['showResultsMode'] as String?) ?? 'realtime';
        final anonymous = (t?['anonymous'] as bool?) ?? true;
        final multipleSelections = (t?['multipleSelections'] as bool?) ?? false;
        final timeLimitEnabled = (t?['timeLimitEnabled'] as bool?) ?? false;
        final timeLimitSeconds =
            (t?['timeLimitSeconds'] as num?)?.toInt() ?? 300;

        // 반응형 스케일 (넓을수록 살짝 크게)
        final s = _uiScale(MediaQuery.of(context).size.width);

        return Scaffold(
          backgroundColor: const Color(0xFFF6FAFF),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: const Color(0xFFF6FAFF),
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  Navigator.of(context, rootNavigator: true).maybePop();
                }
              },
            ),
            title: Text(
              'Quiz • $title',
              style: TextStyle(fontSize: (16 * s).clamp(16, 22).toDouble()),
            ),
          ),
          body: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              // 내용 폭: 모바일 거의 전체, 데스크톱은 820~1060px 근처
              final maxW = w < 768 ? (w * .94) : (w * .82).clamp(820.0, 1060.0);

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [
                      // ===== Title row (Quiz n : Title) =====
                      FutureBuilder<int?>(
                        future: _loadOrdinal(
                          fs: fs,
                          hubId: hubId,
                          topicId: topicId,
                        ),
                        builder: (context, ordSnap) {
                          final ord = ordSnap.data;
                          return _TitleRow(
                            textLeft: ord == null ? 'Quiz' : 'Quiz $ord',
                            textRight: title,
                            scale: s,
                            topicRef: topicRef, // 👈 topicRef를 그대로 넘겨줌
                          );
                        },
                      ),
                      SizedBox(height: (14 * s).clamp(12, 18).toDouble()),

                      // ===== Questions 섹션 =====
                      _SectionHeader(title: 'Questions', scale: s),

                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: quizzesCol.snapshots(),
                        builder: (context, qSnap) {
                          final docs = qSnap.data?.docs ?? const [];

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFDAE2EE),
                              ),
                              borderRadius: BorderRadius.circular(
                                (12 * s).clamp(12, 16),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: (10 * s).clamp(10, 14).toDouble(),
                              horizontal: (10 * s).clamp(10, 14).toDouble(),
                            ),
                            child: Column(
                              children: [
                                // 질문 목록
                                for (int i = 0; i < docs.length; i++) ...[
                                  _QuestionCard(
                                    key: ValueKey(
                                      '${docs[i].id}-$multipleSelections',
                                    ),
                                    index: i,
                                    quizDoc: docs[i],
                                    scale: s,
                                    multipleSelections: multipleSelections,
                                    onTogglePublic: (v) async {
                                      await docs[i].reference.set({
                                        'public': v,
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));
                                    },
                                    onMore:
                                        () =>
                                            _openEditOptions(context, docs[i]),
                                    onDelete: () async {
                                      await _deleteQuestion(
                                        context,
                                        docs[i],
                                        status: status,
                                      );
                                    },
                                  ),
                                  SizedBox(
                                    height: (8 * s).clamp(8, 12).toDouble(),
                                  ),
                                ],

                                // 새 항목 추가 입력란
                                _AddQuestionInput(
                                  onAdd: (text) async {
                                    if (text.trim().isEmpty) return;
                                    await topicRef.collection('quizzes').add({
                                      'question': text.trim(),
                                      'choices': ['A', 'B'],
                                      'triggers': ['S1_CLICK', 'S2_CLICK'],
                                      'correctIndexes': [0],
                                      'public': true,
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                  },
                                  index: docs.length + 1,
                                  scale: s,
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      SizedBox(height: (22 * s).clamp(18, 28).toDouble()),

                      // ===== Settings 섹션 =====
                      _SectionHeader(title: 'Quiz Settings', scale: s),
                      SizedBox(height: (8 * s).clamp(8, 12).toDouble()),
                      _SettingsCard(
                        scale: s,
                        topicRef: topicRef,
                        showResultsMode: showResultsMode,
                        anonymous: anonymous,
                        multipleSelections: multipleSelections,
                        timeLimitEnabled: timeLimitEnabled,
                        timeLimitSeconds: timeLimitSeconds,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // 시안의 상단-오른쪽 SAVE 새(아이콘) 위치는 프로젝트 자산에 맞춰 별도 배치해도 됨.
        );
      },
    );
  }
}

/* ───────────────────────── helpers ───────────────────────── */

double _uiScale(double width) {
  if (width >= 1680) return 1.22;
  if (width >= 1440) return 1.16;
  if (width >= 1280) return 1.10;
  if (width >= 1120) return 1.06;
  return 1.00;
}

/* ───────────────────────── section widgets ───────────────────────── */

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.textLeft,
    required this.textRight,
    required this.scale,
    required this.topicRef,
  });

  final String textLeft;
  final String textRight;
  final double scale;
  final DocumentReference<Map<String, dynamic>> topicRef;

  @override
  Widget build(BuildContext context) {
    final fs = (35 * scale).clamp(28, 40).toDouble();
    final color = const Color(0xFF001A36);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            '$textLeft : $textRight',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: fs,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
          ),
        ),

        const SizedBox(width: 12),
        TextButton.icon(
          onPressed:
              () => _editTopicDialog(
                context,
                topicRef: topicRef,
                currentTitle: textRight,
                currentMaxQuestions: 1,
              ),
          icon: const Icon(
            Icons.edit_outlined,
            size: 22,
            color: Color(0xFFA2A2A2),
          ),
          label: const Text(
            'Edit',
            style: TextStyle(
              color: Color(0xFFA2A2A2),
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    required this.scale,
  });
  final String title;
  final Widget? trailing;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF001A36);
    final fs = (24 * scale).clamp(20, 26).toDouble();

    return Padding(
      padding: EdgeInsets.only(
        left: 2,
        right: 2,
        bottom: (6 * scale).clamp(6, 10).toDouble(),
        top: (6 * scale).clamp(6, 10).toDouble(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: fs,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _AddBtn extends StatelessWidget {
  const _AddBtn({
    required this.enabledStream,
    required this.maxQuestions,
    required this.onAdd,
    required this.scale,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> enabledStream;
  final int maxQuestions;
  final VoidCallback onAdd;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: enabledStream,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        final enabled = count < maxQuestions;
        final sz = (36 * scale).clamp(36, 44).toDouble();

        return SizedBox(
          height: sz,
          child: OutlinedButton.icon(
            onPressed: enabled ? onAdd : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: Size(sz * 2.2, sz),
              side: const BorderSide(color: Color(0xFFDAE2EE)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  (10 * scale).clamp(10, 12).toDouble(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ───────────────────────── question row ───────────────────────── */

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.index,
    required this.quizDoc,
    required this.onTogglePublic,
    required this.onMore,
    required this.onDelete,
    required this.scale,
  });

  final int index;
  final QueryDocumentSnapshot<Map<String, dynamic>> quizDoc;
  final ValueChanged<bool> onTogglePublic;
  final VoidCallback onMore;
  final VoidCallback onDelete;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final x = quizDoc.data();
    final question = (x['question'] as String?) ?? '(no question)';
    final public = (x['public'] as bool?) ?? true;

    final h = (56 * scale).clamp(56, 68).toDouble();
    final r = (12 * scale).clamp(12, 14).toDouble();
    final fs = (16 * scale).clamp(16, 18).toDouble();

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDAE2EE)),
        borderRadius: BorderRadius.circular(r),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: (12 * scale).clamp(12, 16).toDouble(),
      ),
      child: Row(
        children: [
          // 번호
          SizedBox(
            width: (28 * scale).clamp(28, 34).toDouble(),
            child: Text(
              '${index + 1}.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: (14 * scale).clamp(14, 16).toDouble(),
                color: const Color(0xFF0B1324),
              ),
            ),
          ),
          SizedBox(width: (10 * scale).clamp(10, 12).toDouble()),

          // 질문 제목
          Expanded(
            child: Text(
              question,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: fs),
            ),
          ),
          SizedBox(width: (10 * scale).clamp(8, 12).toDouble()),

          // "Public" pill + 스위치 느낌
          _PublicSwitch(
            public: public,
            onChanged: (v) => onTogglePublic(v),
            scale: scale,
          ),
          SizedBox(width: (8 * scale).clamp(8, 12).toDouble()),

          // more (편집)
          _MoreChevron(onTap: onMore, scale: scale),

          // 제거 아이콘(시안에는 잘 안 보이니 옅게)
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _PublicSwitch extends StatelessWidget {
  const _PublicSwitch({
    required this.public,
    required this.onChanged,
    required this.scale,
  });
  final bool public;
  final ValueChanged<bool> onChanged;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final h = (22 * scale).clamp(22, 24).toDouble();
    final w = (40 * scale).clamp(40, 44).toDouble();
    final dot = (h - 8);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(!public),
      child: Row(
        children: [
          Text(
            'Public',
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontSize: (12 * scale).clamp(12, 14).toDouble(),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: w,
            height: h,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: public ? const Color(0xFFB6F536) : const Color(0xFFBDBDBD),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: public ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: dot,
              height: dot,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreChevron extends StatelessWidget {
  const _MoreChevron({required this.onTap, required this.scale});
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final w = (56 * scale).clamp(56, 68).toDouble();
    final h = (32 * scale).clamp(32, 36).toDouble();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Icon(
          Icons.chevron_right,
          size: 20,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.scale,
    required this.topicRef,
    required this.showResultsMode,
    required this.anonymous,
    required this.multipleSelections,
    required this.timeLimitEnabled,
    required this.timeLimitSeconds,
  });

  final double scale;
  final DocumentReference<Map<String, dynamic>> topicRef;

  // 현재 설정값들
  final String showResultsMode; // 'realtime' | 'afterEnd'
  final bool anonymous;
  final bool multipleSelections;
  final bool timeLimitEnabled;
  final int timeLimitSeconds;

  @override
  Widget build(BuildContext context) {
    // 좌측 라벨 스타일(요청하신 타이포)
    Widget row(String label, Widget right) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 277,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF001A36),
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  height: 46 / 24,
                ),
              ),
            ),
            Expanded(child: right),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDAE2EE)),
        borderRadius: BorderRadius.circular((14 * scale).clamp(12, 16)),
      ),
      padding: const EdgeInsets.fromLTRB(40, 20, 40, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            'Show results',
            Wrap(
              spacing: 48,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _LimeRadioOption(
                  label: 'in real time',
                  selected: showResultsMode == 'realtime',
                  onTap:
                      () => _updateTopic(topicRef, {
                        'showResultsMode': 'realtime',
                      }),
                ),
                _LimeRadioOption(
                  label: 'After quiz ends',
                  selected: showResultsMode == 'afterEnd',
                  onTap:
                      () => _updateTopic(topicRef, {
                        'showResultsMode': 'afterEnd',
                      }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          row(
            'Anonymous',
            Wrap(
              spacing: 48,
              children: [
                _LimeRadioOption(
                  label: 'yes',
                  selected: anonymous,
                  onTap: () => _updateTopic(topicRef, {'anonymous': true}),
                ),
                _LimeRadioOption(
                  label: 'no',
                  selected: !anonymous,
                  onTap: () => _updateTopic(topicRef, {'anonymous': false}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          row(
            'Multiple selections',
            Wrap(
              spacing: 48,
              children: [
                _LimeRadioOption(
                  label: 'yes',
                  selected: multipleSelections,
                  onTap:
                      () =>
                          _updateTopic(topicRef, {'multipleSelections': true}),
                ),
                _LimeRadioOption(
                  label: 'no',
                  selected: !multipleSelections,
                  onTap:
                      () =>
                          _updateTopic(topicRef, {'multipleSelections': false}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          row(
            'Time Limit',
            Row(
              children: [
                GestureDetector(
                  onTap:
                      () => _updateTopic(topicRef, {
                        'timeLimitEnabled': !timeLimitEnabled,
                      }),
                  child: _LimeDot(selected: timeLimitEnabled),
                ),
                const SizedBox(width: 12),
                if (timeLimitEnabled)
                  _TimeLimitInput(
                    seconds: timeLimitSeconds,
                    onChanged:
                        (v) => _updateTopic(topicRef, {'timeLimitSeconds': v}),
                  )
                else
                  const Text(
                    'Disabled',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LimeRadioOption extends StatelessWidget {
  const _LimeRadioOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LimeDot(selected: selected),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF000000),
              fontSize: 20,
              fontWeight: FontWeight.w400,
              height: 46 / 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _LimeDot extends StatelessWidget {
  const _LimeDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFFA9E817) : Colors.white,
        border: Border.all(
          color: selected ? Colors.transparent : const Color(0xFFA2A2A2),
          width: 1,
        ),
      ),
    );
  }
}

class _TimeLimitInput extends StatefulWidget {
  const _TimeLimitInput({required this.seconds, required this.onChanged});
  final int seconds; // 총 초 단위
  final ValueChanged<int> onChanged;

  @override
  State<_TimeLimitInput> createState() => _TimeLimitInputState();
}

class _TimeLimitInputState extends State<_TimeLimitInput> {
  late int hours;
  late int minutes;
  late int seconds;

  @override
  void initState() {
    super.initState();
    hours = widget.seconds ~/ 3600;
    minutes = (widget.seconds % 3600) ~/ 60;
    seconds = widget.seconds % 60;
  }

  void _update() {
    final total = hours * 3600 + minutes * 60 + seconds;
    widget.onChanged(total);
  }

  Widget _underlineBox({
    required int value,
    required void Function(int) onChanged,
  }) {
    final controller = TextEditingController(text: value.toString());
    return SizedBox(
      width: 50,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Color(0xFF001A36),
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1.4),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFB6F536), width: 2.0),
          ),
        ),
        onSubmitted: (text) {
          final n = int.tryParse(text) ?? 0;
          onChanged(n.clamp(0, 59)); // 시 제외, 0~59 제한
          _update();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _underlineBox(
          value: hours,
          onChanged: (v) => setState(() => hours = v),
        ),
        const Text(
          ' h  ',
          style: TextStyle(
            color: Color(0xFF001A36),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        _underlineBox(
          value: minutes,
          onChanged: (v) => setState(() => minutes = v),
        ),
        const Text(
          ' m  ',
          style: TextStyle(
            color: Color(0xFF001A36),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        _underlineBox(
          value: seconds,
          onChanged: (v) => setState(() => seconds = v),
        ),
        const Text(
          ' s',
          style: TextStyle(
            color: Color(0xFF001A36),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFDAE2EE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

/* ───────────────────────── dialogs & actions ───────────────────────── */

Future<void> _createBlankQuestion(
  BuildContext context, {
  required FirebaseFirestore fs,
  required DocumentReference<Map<String, dynamic>> topicRef,
}) async {
  await topicRef.collection('quizzes').add({
    'question': 'New question',
    'choices': ['A', 'B'],
    'triggers': ['S1_CLICK', 'S2_CLICK'],
    'correctIndexes': [0],
    'public': true,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  _snack(context, 'Question added.');
}

Future<void> _deleteQuestion(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> doc, {
  required String status,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (_) => AlertDialog(
          title: const Text('Delete question'),
          content: const Text('이 질문과 관련 결과가 삭제됩니다. 계속할까요?'),
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
    await doc.reference.delete();
    _snack(context, 'Question deleted.');
  }
}

Future<void> _editTopicDialog(
  BuildContext context, {
  required DocumentReference<Map<String, dynamic>> topicRef,
  required String currentTitle,
  required int currentMaxQuestions,
}) async {
  final fs = FirebaseFirestore.instance;
  final cTitle = TextEditingController(text: currentTitle);
  int tempMax = currentMaxQuestions;

  int existingCount = 0;
  try {
    final qs = await fs.collection('${topicRef.path}/quizzes').get();
    existingCount = qs.size;
  } catch (_) {}

  final ok = await showDialog<bool>(
    context: context,
    builder:
        (_) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit quiz'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: cTitle,
                      decoration: const InputDecoration(
                        labelText: 'Quiz name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Text('Number of questions')),
                        _stepper(
                          value: tempMax,
                          onMinus:
                              tempMax > 1
                                  ? () => setState(() => tempMax--)
                                  : null,
                          onPlus:
                              tempMax < 20
                                  ? () => setState(() => tempMax++)
                                  : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '현재 문항 수: $existingCount',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (tempMax < existingCount) {
                      _snack(
                        context,
                        '이미 생성된 문항 수($existingCount)보다 적게 설정할 수 없습니다.',
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ),
  );

  if (ok == true) {
    final title =
        cTitle.text.trim().isEmpty ? currentTitle : cTitle.text.trim();
    await topicRef.set({
      'title': title,
      'maxQuestions': tempMax,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _snack(context, 'Quiz updated.');
  }

  cTitle.dispose();
}

Future<void> _updateTopic(
  DocumentReference<Map<String, dynamic>> ref,
  Map<String, dynamic> data,
) async {
  final merged = {...data};
  if (merged.containsKey('timeLimitSeconds')) {
    merged['timerSeconds'] = merged['timeLimitSeconds'];
  }

  await ref.set({
    ...merged,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> _ensureDefaultSettings(
  DocumentReference<Map<String, dynamic>> ref,
) async {
  final snap = await ref.get();
  if (!snap.exists) return;
  final x = snap.data() ?? {};
  if (!x.containsKey('showResultsMode')) {
    await ref.set({
      'showResultsMode': 'realtime',
      'anonymous': true,
      'multipleSelections': false,
      'timeLimitEnabled': false,
      'timeLimitSeconds': 300,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/* ───────────────────────── utilities ───────────────────────── */

void _snack(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  (m ?? ScaffoldMessenger.of(context))
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Widget _stepper({
  required int value,
  VoidCallback? onMinus,
  VoidCallback? onPlus,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _stepBtn(Icons.remove, onMinus),
      Container(
        width: 56,
        height: 40,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDAE2EE)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$value',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      _stepBtn(Icons.add, onPlus),
    ],
  );
}

Widget _stepBtn(IconData icon, VoidCallback? onTap) {
  return SizedBox(
    width: 40,
    height: 40,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFDAE2EE)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.white,
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      child: Icon(
        icon,
        size: 18,
        color: onTap == null ? Colors.grey : const Color(0xFF0B1324),
      ),
    ),
  );
}

void _openEditOptions(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> quizDoc,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) => QuestionOptionsPage(
            topicId:
                quizDoc.reference.parent.parent!.id, // quizzes 상위 = topicId
            quizId: quizDoc.id,
          ),
    ),
  );
}

class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    super.key,
    required this.index,
    required this.quizDoc,
    required this.onTogglePublic,
    required this.scale,
    required this.onMore,
    required this.onDelete,
    required this.multipleSelections,
  });

  final int index;
  final QueryDocumentSnapshot<Map<String, dynamic>> quizDoc;
  final ValueChanged<bool> onTogglePublic;
  final double scale;
  final VoidCallback onMore;
  final VoidCallback onDelete;
  final bool multipleSelections;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard>
    with SingleTickerProviderStateMixin {
  bool expanded = false;
  late List<int> correctIndexes; // 로컬 상태 캐시

  @override
  void initState() {
    super.initState();
    final data = widget.quizDoc.data();
    final correctIndexRaw = data['correctIndexes'] ?? data['correctIndex'];
    correctIndexes =
        correctIndexRaw is List
            ? List<int>.from(correctIndexRaw)
            : [if (correctIndexRaw is int) correctIndexRaw];
  }

  @override
  void didUpdateWidget(covariant _QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Firestore snapshot이 갱신되더라도, 로컬에서 수동 클릭 중이면 덮어쓰지 않음
    final newData = widget.quizDoc.data();
    final correctIndexRaw =
        newData['correctIndexes'] ?? newData['correctIndex'];
    final newIndexes =
        correctIndexRaw is List
            ? List<int>.from(correctIndexRaw)
            : [if (correctIndexRaw is int) correctIndexRaw];
    if (!listEquals(newIndexes, correctIndexes)) {
      correctIndexes = newIndexes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.quizDoc.data();
    final question = (data['question'] as String?) ?? '';
    final public = (data['public'] as bool?) ?? true;
    final choices = List<String>.from(data['choices'] ?? []);
    final triggers = List<String>.from(data['triggers'] ?? []);
    final multipleSelections = widget.multipleSelections;

    Color updatedColor(int index) {
      if (multipleSelections) {
        return correctIndexes.contains(index)
            ? const Color(0xFFA9E817)
            : Colors.white;
      } else {
        return (correctIndexes.isNotEmpty && correctIndexes.first == index)
            ? const Color(0xFFA9E817)
            : Colors.white;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ───────── 질문 행 ─────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: (41 * widget.scale).clamp(41, 45),
              child: Text(
                '${widget.index + 1}.',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: (61 * widget.scale).clamp(56, 68),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFDAE2EE)),
                  borderRadius: BorderRadius.circular(
                    (12 * widget.scale).clamp(12, 14),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 왼쪽: 질문 + Public 스위치
                    Row(
                      children: [
                        Text(
                          question,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Row(
                          children: [
                            const Text(
                              'Public',
                              style: TextStyle(
                                color: Color(0xFFA2A2A2),
                                fontSize: 20,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.95,
                              child: Switch(
                                value: public,
                                onChanged: widget.onTogglePublic,
                                activeColor: Colors.white,
                                activeTrackColor: const Color(0xFFA9E817),
                                inactiveTrackColor: const Color(0xFFA2A2A2),
                                inactiveThumbColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // 오른쪽 more/less + 삭제 버튼
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Delete question',
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFEF4444),
                            size: 26,
                          ),
                          onPressed: widget.onDelete, // ✅ 부모 콜백 사용
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => expanded = !expanded),
                          child: Row(
                            children: const [
                              Text(
                                'more',
                                style: TextStyle(
                                  color: Color(0xFFA2A2A2),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Icon(Icons.expand_more, color: Color(0xFFA2A2A2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child:
              expanded
                  ? Container(
                    margin: const EdgeInsets.only(
                      left: 52,
                      top: 10,
                      bottom: 20,
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const [
                            Text(
                              'Answer Options',
                              style: TextStyle(
                                color: Color(0xFF001A36),
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '*Up to 4',
                              style: TextStyle(
                                color: Color(0xFF001A36),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFDAE2EE)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < choices.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          setState(() {
                                            if (correctIndexes.contains(i)) {
                                              correctIndexes.remove(i);
                                            } else {
                                              if (multipleSelections) {
                                                correctIndexes.add(i);
                                              } else {
                                                correctIndexes
                                                  ..clear()
                                                  ..add(i);
                                              }
                                            }
                                          });
                                          await widget.quizDoc.reference.set({
                                            'correctIndexes': List<int>.from(
                                              correctIndexes,
                                            ),
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                          }, SetOptions(merge: true));
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                correctIndexes.contains(i)
                                                    ? const Color(
                                                      0xFFA9E817,
                                                    ) // ✅ 선택됨 (#A9E817)
                                                    : Colors
                                                        .transparent, // ✅ 선택 안됨: 투명
                                            border: Border.all(
                                              color:
                                                  correctIndexes.contains(i)
                                                      ? Colors
                                                          .transparent // 선택된 상태는 외곽선 없음
                                                      : const Color(
                                                        0xFFA2A2A2,
                                                      ), // 선택 안됨: 회색 외곽선
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // 옵션 입력 필드
                                      Expanded(
                                        child: Container(
                                          height: 49,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                              color: const Color(0xFFD2D2D2),
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              32.5,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      TextEditingController(
                                                        text: choices[i],
                                                      ),
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF001A36),
                                                  ),
                                                  decoration:
                                                      const InputDecoration(
                                                        border:
                                                            InputBorder.none,
                                                        enabledBorder:
                                                            InputBorder.none,
                                                        focusedBorder:
                                                            InputBorder.none,
                                                        disabledBorder:
                                                            InputBorder.none,
                                                        isCollapsed: true,
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                      ),
                                                  onSubmitted: (v) async {
                                                    choices[i] = v;
                                                    await widget
                                                        .quizDoc
                                                        .reference
                                                        .set(
                                                          {
                                                            'choices': choices,
                                                            'updatedAt':
                                                                FieldValue.serverTimestamp(),
                                                          },
                                                          SetOptions(
                                                            merge: true,
                                                          ),
                                                        );
                                                  },
                                                ),
                                              ),
                                              // 드롭다운 (트리거 매핑)
                                              DropdownButton<String>(
                                                value: triggers[i],
                                                underline: const SizedBox(),
                                                icon: const Icon(
                                                  Icons.arrow_drop_down,
                                                  color: Color(0xFF6B7280),
                                                ),
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: 'S1_CLICK',
                                                    child: Text('1 - single'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'S1_HOLD',
                                                    child: Text('1 - hold'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'S2_CLICK',
                                                    child: Text('2 - single'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'S2_HOLD',
                                                    child: Text('2 - hold'),
                                                  ),
                                                ],
                                                onChanged: (v) async {
                                                  if (v == null) return;
                                                  String newTrigger = v;
                                                  final used = Set<String>.from(
                                                    triggers,
                                                  );

                                                  // 중복 트리거 방지
                                                  if (used.contains(
                                                        newTrigger,
                                                      ) &&
                                                      triggers[i] !=
                                                          newTrigger) {
                                                    const all = [
                                                      'S1_CLICK',
                                                      'S1_HOLD',
                                                      'S2_CLICK',
                                                      'S2_HOLD',
                                                    ];
                                                    final available =
                                                        all
                                                            .where(
                                                              (t) =>
                                                                  !used
                                                                      .contains(
                                                                        t,
                                                                      ),
                                                            )
                                                            .toList();
                                                    if (available.isNotEmpty) {
                                                      newTrigger =
                                                          available.first;
                                                    } else {
                                                      debugPrint(
                                                        '⚠️ No available triggers left.',
                                                      );
                                                      return;
                                                    }
                                                  }

                                                  triggers[i] = newTrigger;
                                                  await widget.quizDoc.reference.set({
                                                    'triggers': triggers,
                                                    'updatedAt':
                                                        FieldValue.serverTimestamp(),
                                                  }, SetOptions(merge: true));
                                                  setState(() {});
                                                },
                                              ),

                                              // 삭제 버튼
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints.tightFor(
                                                      width: 28,
                                                      height: 28,
                                                    ),
                                                icon: const Icon(
                                                  Icons.more_vert,
                                                  color: Color(0xFFA2A2A2),
                                                  size: 22,
                                                ),
                                                onPressed: () async {
                                                  final confirm = await showModalBottomSheet<
                                                    bool
                                                  >(
                                                    context: context,
                                                    shape: const RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                  16,
                                                                ),
                                                          ),
                                                    ),
                                                    builder:
                                                        (_) => SafeArea(
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  20,
                                                                ),
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text(
                                                                  'Delete this option?',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        20,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 16,
                                                                ),
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .end,
                                                                  children: [
                                                                    TextButton(
                                                                      onPressed:
                                                                          () => Navigator.pop(
                                                                            context,
                                                                            false,
                                                                          ),
                                                                      child: const Text(
                                                                        'Cancel',
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    ElevatedButton(
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor:
                                                                            Colors.red,
                                                                      ),
                                                                      onPressed:
                                                                          () => Navigator.pop(
                                                                            context,
                                                                            true,
                                                                          ),
                                                                      child: const Text(
                                                                        'Delete',
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                  );

                                                  if (confirm == true) {
                                                    choices.removeAt(i);
                                                    triggers.removeAt(i);
                                                    await widget
                                                        .quizDoc
                                                        .reference
                                                        .set(
                                                          {
                                                            'choices': choices,
                                                            'triggers':
                                                                triggers,
                                                            'updatedAt':
                                                                FieldValue.serverTimestamp(),
                                                          },
                                                          SetOptions(
                                                            merge: true,
                                                          ),
                                                        );
                                                    setState(() {});
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              if (choices.length < 4)
                                Builder(
                                  builder: (context) {
                                    final addController =
                                        TextEditingController();

                                    return Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      height: 49,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: const Color(0xFFD2D2D2),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          32.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                      ),
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        children: [
                                          // 입력창
                                          Expanded(
                                            child: TextField(
                                              controller: addController,
                                              decoration: const InputDecoration(
                                                hintText: 'Type your option...',
                                                hintStyle: TextStyle(
                                                  color: Color(0xFFA2A2A2),
                                                  fontSize: 20,
                                                ),
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                isCollapsed: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 20,
                                                color: Color(0xFF001A36),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),

                                          // 추가 버튼 (+)
                                          GestureDetector(
                                            onTap: () async {
                                              final newText =
                                                  addController.text.trim();
                                              if (newText.isEmpty) return;

                                              choices.add(newText);
                                              triggers.add('S1_CLICK');
                                              await widget.quizDoc.reference.set({
                                                'choices': choices,
                                                'triggers': triggers,
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                              }, SetOptions(merge: true));

                                              addController.clear();
                                              setState(() {});
                                            },
                                            child: const Icon(
                                              Icons.add_circle_outline,
                                              color: Color(0xFFA2A2A2),
                                              size: 28,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _AddQuestionInput extends StatefulWidget {
  const _AddQuestionInput({
    required this.onAdd,
    required this.index,
    required this.scale,
  });
  final Function(String) onAdd;
  final int index;
  final double scale;

  @override
  State<_AddQuestionInput> createState() => _AddQuestionInputState();
}

class _AddQuestionInputState extends State<_AddQuestionInput> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final h = (56 * widget.scale).clamp(56, 68).toDouble();
    final r = (12 * widget.scale).clamp(12, 14).toDouble();
    final fs = (16 * widget.scale).clamp(16, 18).toDouble();

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: (4 * widget.scale).clamp(4, 8).toDouble(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: (41 * widget.scale).clamp(41, 45).toDouble(),
            child: Text(
              '${widget.index}.',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF000000),
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Container(
              height: h,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFDAE2EE)),
                borderRadius: BorderRadius.circular(r),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: controller,
                style: TextStyle(
                  fontSize: fs,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF001A36),
                ),
                decoration: const InputDecoration(
                  hintText: 'Type your question...',
                  hintStyle: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (text) {
                  widget.onAdd(text);
                  controller.clear();
                },
              ),
            ),
          ),

          const SizedBox(width: 10),

          GestureDetector(
            onTap: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              widget.onAdd(text);
              controller.clear();
            },
            child: const Icon(
              Icons.add_circle_outline_outlined,
              color: Color(0xFFD2D2D2),
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}
