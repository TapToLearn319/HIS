// lib/pages/quiz/topic_detail.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';
import 'question_options_page.dart';
import 'edit_question_page.dart';
import 'create_question_page.dart';

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
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: _QuestionCard(
                                          index: i + 1,
                                          quizDoc: docs[i],
                                          public:
                                              (docs[i].data()['public']
                                                  as bool?) ??
                                              false,
                                          onTogglePublic: (v) async {
                                            await docs[i].reference.set({
                                              'public': v,
                                              'updatedAt':
                                                  FieldValue.serverTimestamp(),
                                            }, SetOptions(merge: true));
                                          },
                                          onMore: () {
                                            _openEditOptions(context, docs[i]);
                                          },
                                          onDelete: () async {
                                            await _deleteQuestion(
                                              context,
                                              docs[i],
                                              status: status,
                                            );
                                          },
                                        ),
                                      ),
                                      Container(
                                        alignment: Alignment.center,
                                        margin: const EdgeInsets.only(
                                          left: 12,
                                          right: 20,
                                        ),
                                        child: IconButton(
                                          tooltip: 'Delete question',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Color(0xFFFF9A6E),
                                            size: 32, // 약간 키워서 비율 맞춤
                                          ),
                                          onPressed: () async {
                                            await _deleteQuestion(
                                              context,
                                              docs[i],
                                              status: status,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: (8 * s).clamp(8, 12).toDouble(),
                                  ),
                                ],

                                // 새 항목 추가 입력란
                                _AddQuestionInput(
                                  topicId: topicId,
                                  onAdd: (text) async {
                                    if (text.trim().isEmpty) return;
                                    await topicRef.collection('quizzes').add({
                                      'question': text.trim(),
                                      'choices': ['A', 'B'],
                                      'triggers': ['S1_CLICK', 'S2_CLICK'],
                                      'counts': [0, 0],
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
          (_) => EditQuestionPage(
            topicId: quizDoc.reference.parent.parent!.id,
            quizId: quizDoc.id,
          ),
    ),
  );
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final DocumentSnapshot quizDoc;
  final bool public;
  final ValueChanged<bool> onTogglePublic;
  final VoidCallback onMore;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.index,
    required this.quizDoc,
    required this.public,
    required this.onTogglePublic,
    required this.onMore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, right: 20, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 번호
          SizedBox(
            width: 24,
            child: Text(
              '$index.',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF000000),
              ),
            ),
          ),
          const SizedBox(width: 36),

          // 문항 박스
          Flexible(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Color(0xFFDAE2EE)),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 질문 내용
                  Expanded(
                    child: Text(
                      quizDoc['question'] ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF001A36),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 오른쪽 버튼 그룹
                  Row(
                    children: [
                      const Text(
                        'Public',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF8A8A8A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch(
                        value: public,
                        activeColor: Color(0xFFA9E817),
                        onChanged: onTogglePublic,
                      ),
                      const SizedBox(width: 20),
                      InkWell(
                        onTap: onMore,
                        child: const Row(
                          children: [
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF6E6E6E),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(
                              Icons.edit,
                              size: 16,
                              color: Color(0xFF6E6E6E),
                            ),
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
    );
  }
}

class CustomMiniSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const CustomMiniSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28.5,
        height: 14,
        decoration: BoxDecoration(
          color: value ? const Color(0xFFA9E817) : const Color(0xFFD2D2D2),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _Binding {
  final int button;
  final String gesture;
  const _Binding({required this.button, required this.gesture});
}

class _AddQuestionInput extends StatefulWidget {
  const _AddQuestionInput({
    required this.topicId,
    required this.onAdd,
    required this.index,
    required this.scale,
  });

  final String topicId;
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
    return Padding(
      padding: const EdgeInsets.only(left: 28, right: 36, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 번호
          SizedBox(
            width: 24,
            child: Text(
              '${widget.index}.',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF000000),
              ),
            ),
          ),
          const SizedBox(width: 36),

          // 문항 입력 박스 (디자인 그대로)
          Flexible(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateQuestionPage(topicId: widget.topicId),
                  ),
                );
              },
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFDAE2EE)),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.centerLeft,
                child: const Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline_outlined,
                      color: Color(0xFFD2D2D2),
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Add Question',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
