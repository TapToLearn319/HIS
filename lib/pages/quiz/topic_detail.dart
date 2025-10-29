// lib/pages/quiz/topic_detail.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:dotted_border/dotted_border.dart';
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
        .where('createdAt', isGreaterThan: null)
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

                      _SectionHeader(
                        title: 'Questions',
                        scale: s,
                        trailing: Padding(
                          padding: const EdgeInsets.only(
                            right: 15,
                          ), // ✅ ← 여기가 핵심 (왼쪽으로 이동)
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Public',
                                style: TextStyle(
                                  color: Color(0xFFA2A2A2),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w400,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: quizzesCol.snapshots(),
                                builder: (context, qSnap) {
                                  if (!qSnap.hasData) return const SizedBox();
                                  final docs = qSnap.data!.docs;
                                  final allPublic =
                                      docs.isNotEmpty &&
                                      docs.every(
                                        (doc) =>
                                            (doc.data()['public'] ?? false) ==
                                            true,
                                      );
                                  return CustomMiniSwitch(
                                    value: allPublic,
                                    onChanged: (v) async {
                                      final batch =
                                          FirebaseFirestore.instance.batch();
                                      for (final doc in docs) {
                                        batch.set(doc.reference, {
                                          'public': v,
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        }, SetOptions(merge: true));
                                      }
                                      await batch.commit();
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: quizzesCol.snapshots(),
                        builder: (context, qSnap) {
                          final docs = qSnap.data?.docs ?? const [];

                          // 🔹 Topic 상태 읽기 (status, phase, currentQuizId)
                          final topicData = tSnap.data?.data() ?? {};
                          final currentQuizId = topicData['currentQuizId'];
                          final status = topicData['status'] ?? 'draft';
                          final phase = topicData['phase'] ?? 'question';

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
                                // 🔸 각 문항 렌더링
                                for (int i = 0; i < docs.length; i++) ...[
                                  Builder(
                                    builder: (context) {
                                      final d = docs[i];
                                      final isCurrent = currentQuizId == d.id;
                                      final isLast = i == docs.length - 1;

                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: _QuestionCard(
                                              index: i + 1,
                                              quizDoc: d,
                                              public:
                                                  d.data()['public'] is bool
                                                      ? d.data()['public']
                                                          as bool
                                                      : (d.data()['public'] ==
                                                          'true'),
                                              onTogglePublic: (v) async {
                                                await d.reference.set({
                                                  'public': v,
                                                  'updatedAt':
                                                      FieldValue.serverTimestamp(),
                                                }, SetOptions(merge: true));
                                              },
                                              onMore:
                                                  () => _openEditOptions(
                                                    context,
                                                    topicId,
                                                    d,
                                                  ),
                                              onDelete: () async {
                                                await _deleteQuestion(
                                                  context,
                                                  d,
                                                  status: status,
                                                );
                                              },
                                              topicRef: topicRef,
                                              phase: phase,
                                              status: status,
                                              isCurrent: isCurrent,
                                              isLast: isLast,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                              right: 4,
                                            ),
                                            child: CustomMiniSwitch(
                                              value:
                                                  (() {
                                                    final p =
                                                        d.data()['public'];
                                                    if (p is bool) return p;
                                                    if (p is String)
                                                      return p.toLowerCase() ==
                                                          'true';
                                                    return false;
                                                  })(),
                                              onChanged: (v) async {
                                                await d.reference.set({
                                                  'public': v,
                                                  'updatedAt':
                                                      FieldValue.serverTimestamp(),
                                                }, SetOptions(merge: true));
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  SizedBox(
                                    height: (8 * s).clamp(8, 12).toDouble(),
                                  ),
                                ],

                                // 🔸 새 항목 추가 입력란
                                _AddQuestionInput(
                                  topicId: topicId,
                                  onAdd: (text) async {
                                    if (text.trim().isEmpty) return;
                                    await topicRef.collection('quizzes').add({
                                      'question': text.trim(),
                                      'choices': ['A', 'B'],
                                      'triggers': ['S1_CLICK', 'S2_CLICK'],
                                      'counts': [0, 0],
                                      'correctIndex': 0,
                                      'correctIndices': [0],
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
        bottom: (2 * scale).clamp(6, 10).toDouble(),
        top: (2 * scale).clamp(6, 10).toDouble(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.scale,
    required this.topicRef,
    required this.showResultsMode,
    required this.anonymous,
    required this.timeLimitEnabled,
    required this.timeLimitSeconds,
  });

  final double scale;
  final DocumentReference<Map<String, dynamic>> topicRef;

  // 현재 설정값들
  final String showResultsMode; // 'realtime' | 'afterEnd'
  final bool anonymous;
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
                  label: 'after quiz ends',
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

Future<void> _deleteQuestion(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> doc, {
  required String status,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder:
        (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: DottedBorder(
            options: const RoundedRectDottedBorderOptions(
              dashPattern: [6, 4],
              strokeWidth: 4,
              radius: Radius.circular(10),
              color: Color(0xFFA2A2A2),
            ),
            child: Container(
              width: 357,
              height: 167,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Would you like to delete it?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF001A36),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, // ✅ 가운데 정렬
                    children: [
                      // 🟣 Delete 버튼
                      DottedBorder(
                        options: const RoundedRectDottedBorderOptions(
                          dashPattern: [6, 4],
                          strokeWidth: 2,
                          radius: Radius.circular(10),
                          color: Color(0xFFA2A2A2),
                        ),
                        child: SizedBox(
                          width: 120, // ✅ 고정된 버튼 폭
                          height: 43,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFF6F6F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF001A36),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 🟣 Cancel 버튼
                      DottedBorder(
                        options: const RoundedRectDottedBorderOptions(
                          dashPattern: [6, 4],
                          strokeWidth: 2,
                          radius: Radius.circular(10),
                          color: Color(0xFFA2A2A2),
                        ),
                        child: SizedBox(
                          width: 120, // ✅ Delete와 동일한 고정 폭
                          height: 43,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFF6F6F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF001A36),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
  );
  if (ok == true) {
    final ref = doc.reference;

    await doc.reference.delete();

    if (context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _snack(context, 'Question deleted.');
      });
    }
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

  // ✅ 1. timeLimitSeconds 값이 있을 때 → timerSeconds에 복사
  if (merged.containsKey('timeLimitSeconds')) {
    merged['timerSeconds'] = merged['timeLimitSeconds'];
  }

  // ✅ 2. timeLimitEnabled가 false일 때는 타이머 관련 필드 제거
  if (merged['timeLimitEnabled'] == false) {
    merged['timeLimitSeconds'] = FieldValue.delete();
    merged['timerSeconds'] = FieldValue.delete();
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
  String topicId,
  QueryDocumentSnapshot<Map<String, dynamic>> quizDoc,
) {
  try {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) {
      debugPrint('❗ hubId is null in _openEditOptions');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('허브를 먼저 선택하세요.')));
      return;
    }
    debugPrint(
      '✅ Opening EditQuestionPage → topic=$topicId, quiz=${quizDoc.id}',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          final data = quizDoc.data();
          // ✅ 필드 방어
          final hasChoices = data.containsKey('choices');
          final hasTriggers = data.containsKey('triggers');
          if (!hasChoices || !hasTriggers) {
            debugPrint('⚠️ Missing choices/triggers in quiz ${quizDoc.id}');
          }
          return EditQuestionPage(
            hubId: hubId,
            topicId: topicId,
            quizId: quizDoc.id,
          );
        },
      ),
    );
  } catch (e, st) {
    debugPrint('🔥 openEditOptions failed: $e\n$st');
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final QueryDocumentSnapshot<Map<String, dynamic>> quizDoc;
  final bool public;
  final bool isCurrent;
  final bool isLast;
  final ValueChanged<bool> onTogglePublic;
  final VoidCallback onMore;
  final VoidCallback onDelete;
  final DocumentReference topicRef;

  final String phase;
  final String status;

  const _QuestionCard({
    required this.index,
    required this.quizDoc,
    required this.public,
    required this.onTogglePublic,
    required this.onMore,
    required this.onDelete,
    required this.topicRef,
    this.isCurrent = false,
    this.isLast = false,
    this.phase = 'question',
    this.status = 'draft',
  });

  @override
  Widget build(BuildContext context) {
    final question = quizDoc.data()['question'] ?? '';
    final data = quizDoc.data();
    final p = data.containsKey('public') ? data['public'] : false;
    final public = (p is bool) ? p : (p is String && p.toLowerCase() == 'true');

    final boxColor = isCurrent ? const Color(0x3344A0FF) : Colors.white;

    final running = isCurrent;
    final btnLabel = running ? 'Done !' : (isLast ? 'Finish !' : 'Next !');
    final icon = Icons.play_arrow_rounded;

    final showButton = () {
      // 퀴즈 시작 전에는 첫 번째 문항만 Next 표시
      if (status == 'draft' || status == 'ready') {
        return index == 1;
      }

      // 퀴즈 실행 중에는 현재 문항만 표시
      if (status == 'running') {
        return isCurrent;
      }

      // 그 외(종료 등)에는 숨김
      return false;
    }();

    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 6, bottom: 6),
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

          // 메인 카드
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: boxColor,
                border: Border.all(color: const Color(0xFFDAE2EE)),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 질문 + 버튼 묶음
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            question,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFF001A36),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),

                        if (showButton)
                          SizedBox(
                            width: 118,
                            height: 40,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFF001A36),
                                  width: 1,
                                ),
                              ),
                              onPressed: () async {
                                final fs = FirebaseFirestore.instance;
                                final topicRef = this.topicRef;
                                final quizCol = topicRef.collection('quizzes');
                                final currentId = quizDoc.id;

                                if (phase == 'question') {
                                  await topicRef.update({
                                    'phase': 'reveal',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                                } else if (phase == 'reveal') {
                                  final qs =
                                      await quizCol.orderBy('createdAt').get();
                                  final docs = qs.docs;
                                  final curIdx = docs.indexWhere(
                                    (d) => d.id == currentId,
                                  );

                                  String? nextPublicId;
                                  for (
                                    int i = curIdx + 1;
                                    i < docs.length;
                                    i++
                                  ) {
                                    final dData = docs[i].data();
                                    final p = dData['public'];
                                    final isPublic =
                                        (p is bool)
                                            ? p
                                            : (p is String &&
                                                p.toLowerCase() == 'true');
                                    if (isPublic) {
                                      nextPublicId = docs[i].id;
                                      break;
                                    }
                                  }

                                  if (nextPublicId == null) {
                                    await topicRef.update({
                                      'status': 'finished',
                                      'phase': 'finished',
                                      'currentQuizId': null,
                                      'questionStartedAt': null,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                  } else {
                                    await topicRef.update({
                                      'phase': 'question',
                                      'currentQuizId': nextPublicId,
                                      'currentQuizIndex': curIdx + 2,
                                      'questionStartedAt':
                                          FieldValue.serverTimestamp(),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                  }
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 24,
                                    color: Color(0xFF001A36),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    phase == 'question' ? 'Done !' : 'Next !',
                                    style: const TextStyle(
                                      color: Color(0xFF001A36),
                                      fontSize: 19,
                                      fontWeight: FontWeight.w600,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 오른쪽 고정 아이콘
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final hubId = context.read<HubProvider>().hubId;
                          if (hubId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => EditQuestionPage(
                                      hubId: hubId,
                                      topicId: topicRef.id.split('/').last,
                                      quizId: quizDoc.id,
                                    ),
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: const [
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: Color(0xFFA2A2A2),
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                                height: 34 / 21,
                              ),
                            ),
                            Icon(
                              Icons.edit_outlined,
                              size: 23,
                              color: Color(0xFFA2A2A2),
                            ),
                            SizedBox(width: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(
                          Icons.delete_outline,
                          size: 24,
                          color: Color(0xFFFF9A6E),
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
        width: 28.47,
        height: 14,
        decoration: BoxDecoration(
          color: value ? const Color(0xFFA9E817) : const Color(0xFFA2A2A2),
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
      padding: const EdgeInsets.only(left: 28, right: 4, top: 6, bottom: 6),
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

          Flexible(
            child: GestureDetector(
              onTap: () {
                final hubId = context.read<HubProvider>().hubId;
                if (hubId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('허브를 먼저 선택하세요.')),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => CreateQuestionPage(
                          hubId: hubId, // ✅ hubId 추가
                          topicId: widget.topicId,
                        ),
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
