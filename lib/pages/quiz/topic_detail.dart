// lib/pages/quiz/topic_detail.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
            actions: [
              TextButton.icon(
                onPressed:
                    () => _editTopicDialog(
                      context,
                      topicRef: topicRef,
                      currentTitle: title,
                      currentMaxQuestions: maxQuestions,
                    ),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
              ),
            ],
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
                      SizedBox(height: (6 * s).clamp(6, 10).toDouble()),
                      // 상단 상태/요약 바
                      _StatusStrip(
                        status: status,
                        maxQuestions: maxQuestions,
                        scale: s,
                      ),
                      SizedBox(height: (14 * s).clamp(12, 18).toDouble()),

                      // ===== Questions 섹션 =====
                      _SectionHeader(
                        title: 'Questions',
                        trailing: _AddBtn(
                          enabledStream: quizzesCol.snapshots(),
                          maxQuestions: maxQuestions,
                          onAdd:
                              () => _createBlankQuestion(
                                context,
                                fs: fs,
                                topicRef: topicRef,
                              ),
                          scale: s,
                        ),
                        scale: s,
                      ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: quizzesCol.snapshots(),
                        builder: (context, qSnap) {
                          final docs = qSnap.data?.docs ?? const [];
                          if (docs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _EmptyCard(
                                text:
                                    '아직 질문이 없습니다.\n오른쪽 위 Add 버튼으로 질문을 추가해 주세요.',
                              ),
                            );
                          }

                          return Column(
                            children: [
                              const SizedBox(height: 8),
                              for (int i = 0; i < docs.length; i++) ...[
                                _QuestionRow(
                                  index: i,
                                  quizDoc: docs[i],
                                  scale: s,
                                  onTogglePublic: (v) async {
                                    await docs[i].reference.set({
                                      'public': v,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));
                                  },
                                  onMore:
                                      () => _openEditOptions(context, docs[i]),
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
                              if (docs.length >= maxQuestions)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '최대 문항 수에 도달했습니다.',
                                    style: TextStyle(
                                      color: const Color(0xFF6B7280),
                                      fontSize:
                                          (12 * s).clamp(12, 14).toDouble(),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                      SizedBox(height: (22 * s).clamp(18, 28).toDouble()),

                      // ===== Settings 섹션 =====
                      _SectionHeader(title: 'Quiz Settings', scale: s),
                      SizedBox(height: (8 * s).clamp(8, 12).toDouble()),
                      _SettingsCard(scale: s),
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
    required this.topicRef, // 🔑 topicRef 직접 받기
  });

  final String textLeft; // "Quiz 3"
  final String textRight; // "Ummmmm"
  final double scale;
  final DocumentReference<Map<String, dynamic>> topicRef; // 👈 전달받음

  @override
  Widget build(BuildContext context) {
    final fs = (35 * scale).clamp(28, 40).toDouble();
    final color = const Color(0xFF001A36);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 404),
          child: Text(
            textLeft,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: fs,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
          ),
        ),
        Text(
          ' : ',
          style: TextStyle(
            color: color,
            fontSize: fs,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
        ),
        Expanded(
          child: Text(
            textRight,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: fs,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Edit title',
          icon: const Icon(Icons.edit, size: 20, color: Color(0xFF6B7280)),
          onPressed:
              () => _editTopicDialog(
                context,
                topicRef: topicRef, // 👈 여기서 직접 topicRef 전달
                currentTitle: textRight,
                currentMaxQuestions: 1, // TODO: 실제 maxQuestions 값 넣기
              ),
        ),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.status,
    required this.maxQuestions,
    required this.scale,
  });
  final String status;
  final int maxQuestions;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDAE2EE)),
        borderRadius: BorderRadius.circular(
          (12 * scale).clamp(12, 16).toDouble(),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        (14 * scale).clamp(14, 18).toDouble(),
        (10 * scale).clamp(10, 14).toDouble(),
        (14 * scale).clamp(14, 18).toDouble(),
        (10 * scale).clamp(10, 14).toDouble(),
      ),
      child: Row(
        children: [
          _statusBadge(status),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You can add questions up to $maxQuestions.',
              style: TextStyle(
                color: const Color(0xFF6B7280),
                fontSize: (13 * scale).clamp(13, 15).toDouble(),
              ),
            ),
          ),
        ],
      ),
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
    return Padding(
      padding: EdgeInsets.only(
        left: 2,
        right: 2,
        bottom: (6 * scale).clamp(6, 10).toDouble(),
        top: (6 * scale).clamp(6, 10).toDouble(),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: (14 * scale).clamp(14, 18).toDouble(),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0B1324),
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

/* ───────────────────────── settings card (mock UI) ───────────────────────── */

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    final r = (14 * scale).clamp(12, 16).toDouble();
    final p = (16 * scale).clamp(14, 18).toDouble();
    final fs = (14 * scale).clamp(14, 16).toDouble();

    Widget row(String label, Widget right) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 180,
              child: Text(
                label,
                style: TextStyle(fontSize: fs, color: const Color(0xFF0B1324)),
              ),
            ),
            Expanded(child: right),
          ],
        ),
      );
    }

    Widget radioPair(String a, String b) {
      return Row(
        children: [_chip(a, true), const SizedBox(width: 10), _chip(b, false)],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDAE2EE)),
        borderRadius: BorderRadius.circular(r),
      ),
      padding: EdgeInsets.all(p),
      child: Column(
        children: [
          row(
            'Show results',
            Row(
              children: [
                _chip('in real time', true),
                const SizedBox(width: 10),
                _chip('After quiz ends', false),
              ],
            ),
          ),
          const Divider(height: 24),
          row('Anonymous', radioPair('yes', 'no')),
          const Divider(height: 24),
          row('Multiple selections', radioPair('yes', 'no')),
          const Divider(height: 24),
          row(
            'Time Limit',
            Row(
              children: [
                _limeDot(),
                const SizedBox(width: 8),
                Text(
                  '—  h   5  m   s',
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontSize: fs,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFB6F536) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0B1324),
        ),
      ),
    );
  }

  Widget _limeDot() => Container(
    width: 14,
    height: 14,
    decoration: const BoxDecoration(
      color: Color(0xFFB6F536),
      shape: BoxShape.circle,
    ),
  );
}

/* ───────────────────────── small shared ───────────────────────── */

Widget _statusBadge(String status) {
  Color bg, fg;
  switch (status) {
    case 'running':
      bg = const Color(0x3322C55E);
      fg = const Color(0xFF22C55E);
      break;
    case 'stopped':
      bg = const Color(0x33A1A1AA);
      fg = const Color(0xFF71717A);
      break;
    default:
      bg = const Color(0x33F59E0B);
      fg = const Color(0xFFF59E0B);
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      status,
      style: TextStyle(color: fg, fontWeight: FontWeight.w700),
    ),
  );
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
    'correctIndex': 0,
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
