// lib/pages/quiz/topic_list_and_dialogs.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';
import 'topic_detail.dart';
import 'create_topic_page.dart';

// ───────────────────────── Create Topic FAB ─────────────────────────

class CreateTopicFab extends StatelessWidget {
  const CreateTopicFab({super.key});

  Future<void> _createTopicDialog(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
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
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create'),
              ),
            ],
          ),
    );
    if (ok == true) {
      final title = c.text.trim();
      if (title.isEmpty) return;

      final hub = context.read<HubProvider>();
      final hubPath = hub.hubDocPath; // hubs/{hubId}
      if (hubPath == null) {
        _snack(context, '허브를 먼저 선택하세요.');
        c.dispose();
        return;
      }

      await FirebaseFirestore.instance.collection('$hubPath/quizTopics').add({
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
          width: 200,
          height: 200,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              hoverColor: Colors.black.withOpacity(0.05),
              splashColor: Colors.black.withOpacity(0.1),
              onTap: () async {
                final ok = await Navigator.pushNamed(
                  context,
                  '/quiz/create-topic',
                );
                if (ok == true && context.mounted) {
                  _snack(context, 'Topic created!');
                }
              },
              child: Tooltip(
                message: 'Create topic',
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Image.asset(
                    'assets/logo_bird_create.png',
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) => const Icon(
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

// ───────────────────────── Topic rename/delete dialogs ─────────────────────────

Future<void> _renameTopicDialog(
  BuildContext context,
  FirebaseFirestore fs, {
  required String topicId,
  required String initialTitle,
}) async {
  final c = TextEditingController(text: initialTitle);
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (_) => AlertDialog(
          title: const Text('Edit topic'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Topic title',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
  );
  if (ok == true) {
    final title = c.text.trim();
    if (title.isEmpty) return;

    final hubPath = context.read<HubProvider>().hubDocPath; // hubs/{hubId}
    if (hubPath == null) {
      _snack(context, '허브를 먼저 선택하세요.');
      c.dispose();
      return;
    }

    await fs.doc('$hubPath/quizTopics/$topicId').set({
      'title': title,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _snack(context, 'Topic updated.');
  }
  c.dispose();
}

Future<void> _deleteTopicWithSubcollections(
  BuildContext context,
  FirebaseFirestore fs, {
  required String topicId,
  String? status,
}) async {
  final hubPath = context.read<HubProvider>().hubDocPath; // hubs/{hubId}
  if (hubPath == null) {
    if (context.mounted) _snack(context, '허브를 먼저 선택하세요.');
    return;
  }

  final running = (status == 'running');
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete topic'),
      content: Text(
        running
            ? '이 토픽은 현재 진행 중입니다.\n삭제하면 진행이 중단되고, 모든 퀴즈/결과가 함께 삭제됩니다. 계속할까요?'
            : '토픽과 그 안의 모든 퀴즈/결과가 삭제됩니다. 계속할까요?',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  if (ok != true) return;

  // root navigator를 미리 캡쳐 (context가 dispose돼도 사용 가능)
  final rootNav = Navigator.of(context, rootNavigator: true);

  // 로딩 다이얼로그를 띄우고, 닫힘 여부 추적
  var dialogClosed = false;
  // ignore: unawaited_futures
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  ).then((_) => dialogClosed = true);

  try {
    if (running) {
      await fs.doc('$hubPath/quizTopics/$topicId').set({
        'status': 'stopped',
        'phase': 'finished',
        'currentIndex': null,
        'currentQuizId': null,
        'endedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'showSummaryOnDisplay': false,
      }, SetOptions(merge: true));
    }

    // 하위 컬렉션 페이징 삭제
    await _deleteCollectionPaged(fs, '$hubPath/quizTopics/$topicId/quizzes', pageSize: 300);
    await _deleteCollectionPaged(fs, '$hubPath/quizTopics/$topicId/results', pageSize: 300);

    // 마지막으로 토픽 문서 삭제
    await fs.doc('$hubPath/quizTopics/$topicId').delete();

    if (context.mounted) _snack(context, 'Topic deleted.');
  } catch (e) {
    if (context.mounted) _snack(context, 'Delete failed: $e');
  } finally {
    // 다이얼로그가 아직 열려 있으면 한 번만 닫기
    if (!dialogClosed && rootNav.mounted) {
      try {
        rootNav.pop();
      } catch (_) {
        // 이미 닫혀 있거나 route stack 변화로 pop 불가한 경우 무시
      }
    }
  }
}

Future<void> _deleteCollectionPaged(
  FirebaseFirestore fs,
  String path, {
  int pageSize = 300,
}) async {
  DocumentSnapshot? last;
  while (true) {
    var q = fs.collection(path).orderBy(FieldPath.documentId).limit(pageSize);
    if (last != null) q = q.startAfterDocument(last);

    final snap = await q.get();
    if (snap.docs.isEmpty) break;

    final batch = fs.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();

    last = snap.docs.last;
    if (snap.docs.length < pageSize) break;
  }
}

// ───────────────────────── Topic list ─────────────────────────

class TopicList extends StatelessWidget {
  const TopicList({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final hubPath = context.watch<HubProvider>().hubDocPath; // hubs/{hubId}

    if (hubPath == null) {
      return const _EmptyState(
        title: '허브가 선택되지 않았어요',
        subtitle: '허브를 먼저 선택/로그인 해주세요.',
      );
    }

    final stream =
        fs
            .collection('$hubPath/quizTopics')
            .orderBy('createdAt', descending: false)
            .snapshots();

    Future<int> _quizCount(String topicId) async {
      final qs =
          await fs.collection('$hubPath/quizTopics/$topicId/quizzes').get();
      return qs.size;
    }

    Future<void> _startTopic(BuildContext context, String topicId) async {
      final qSnap =
          await fs
              .collection('$hubPath/quizTopics/$topicId/quizzes')
              .orderBy('createdAt')
              .get();
      if (qSnap.docs.isEmpty) {
        _snack(context, '먼저 문제를 추가해 주세요.');
        return;
      }
      final first = qSnap.docs.first;
      await fs.doc('$hubPath/quizTopics/$topicId').set({
        'status': 'running',
        'phase': 'question',
        'currentIndex': 0,
        'currentQuizId': first.id,
        'questionStartedAt': FieldValue.serverTimestamp(),
        'questionStartedAtMs': DateTime.now().millisecondsSinceEpoch,
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'showSummaryOnDisplay': false,
      }, SetOptions(merge: true));

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TopicDetailPage(topicId: topicId)),
        );
      }
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final topics = snap.data?.docs ?? const [];

        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;

            double gutter;
            if (w >= 1600) {
              gutter = 16;
            } else if (w >= 1280) {
              gutter = 14;
            } else if (w >= 1024) {
              gutter = 12;
            } else if (w >= 768) {
              gutter = 10;
            } else {
              gutter = 8;
            }

            // 사실상 화면 가로 대부분을 쓰도록 상한을 크게 → 수정
            double maxContentWidth;
            if (w < 768) {
              // 모바일: 거의 전체 사용
              maxContentWidth = w - gutter * 2;
            } else if (w < 1200) {
              // 태블릿/창모드: 화면의 80% 정도만
              maxContentWidth = w * 0.8;
            } else {
              // 데스크톱: 최대 1000px 고정
              maxContentWidth = 1000;
            }
            final s = _uiScale(context); // 스케일

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 48),
                  itemCount: topics.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    // Create a Quiz
                    if (i == topics.length) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RowHeader(text: 'Create a Quiz', scale: s),
                          const SizedBox(height: 6),
                          _InputLikeTile(
                            title: 'Add',
                            scale: s,
                            titleStyle: const TextStyle(
                              color: Color(0xFFA2A2A2),
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              height: 34 / 24,
                            ),
                            leading: Icon(
                              Icons.add_circle_outline,
                              size: (31 * s).clamp(31, 44).toDouble(),
                              color: const Color(0xFFA2A2A2),
                            ),
                            onTap: () async {
                              final created = await Navigator.pushNamed(
                                context,
                                '/quiz/create-topic',
                              );
                              if (created == true && context.mounted) {
                                _snack(context, 'Topic created.');
                              }
                            },
                          ),
                        ],
                      );
                    }

                    final d = topics[i];
                    final x = d.data();
                    final title =
                        (x['title'] as String?)?.trim().isNotEmpty == true
                            ? (x['title'] as String).trim()
                            : 'Quiz ${i + 1}';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<int>(
                          future: _quizCount(d.id),
                          builder: (context, cntSnap) {
                            final cnt = cntSnap.data ?? 0;
                            return _RowHeader(
                              text: 'Quiz ${i + 1}',
                              scale: s,
                              onDelete:
                                  () => _deleteTopicWithSubcollections(
                                    context,
                                    fs,
                                    topicId: d.id,
                                    status: (x['status'] as String?),
                                  ),
                              trailing: _StartButton(
                                enabled: cnt != 0,
                                scale: s,
                                onPressed: () => _startTopic(context, d.id),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: (12 * s).clamp(12, 18).toDouble()),
                        _InputLikeTile(
                          title: title,
                          scale: s,
                          trailing: _MorePill(scale: s),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TopicDetailPage(topicId: d.id),
                              ),
                            );
                          },
                          onMore: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TopicDetailPage(topicId: d.id),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ───────────────────────── Scale helpers & small widgets ─────────────────────────

double _uiScale(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w >= 1920) return 1.40;
  if (w >= 1680) return 1.30;
  if (w >= 1440) return 1.20;
  if (w >= 1280) return 1.12;
  if (w >= 1120) return 1.06;
  return 1.00;
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.enabled,
    required this.onPressed,
    required this.scale,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final h = (61 * scale).clamp(61, 96).toDouble();
    final fs = (24 * scale).clamp(24, 36).toDouble();
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        Icons.play_arrow,
        size: (18 * scale).clamp(18, 28).toDouble(),
        color: Colors.black,
      ),
      label: Text(
        'START !',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black,
          fontSize: fs,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: (8 * scale).clamp(8, 16)),
        minimumSize: Size(0, h),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: Colors.black,
        disabledForegroundColor: const Color(0xFFA2A2A2),
      ),
    );
  }
}

class _MorePill extends StatelessWidget {
  const _MorePill({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    final h = (61 * scale).clamp(61, 96).toDouble();
    final w = (74 * scale).clamp(74, 120).toDouble();
    final fs = (24 * scale).clamp(24, 36).toDouble();
    return Container(
      constraints: BoxConstraints.tightFor(width: w, height: h),
      alignment: Alignment.center,
      child: Text(
        'more',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xFFA2A2A2),
          fontSize: fs,
          fontWeight: FontWeight.w400,
          height: 34 / 24,
        ),
      ),
    );
  }
}

/* ───────────── 작은 컴포넌트들 ───────────── */

class _RowHeader extends StatelessWidget {
  const _RowHeader({
    required this.text,
    this.onDelete,
    this.trailing,
    required this.scale,
  });

  final String text;
  final VoidCallback? onDelete;
  final Widget? trailing;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final fs = (24 * scale).clamp(24, 36).toDouble();
    final iconSize = (18 * scale).clamp(18, 28).toDouble();
    final h = (34 * scale).clamp(34, 48).toDouble();

    return SizedBox(
      height: h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF001A36),
              height: 1.0,
            ),
          ),
          if (onDelete != null) ...[
            SizedBox(width: (6 * scale).clamp(6, 10).toDouble()),
            IconButton(
              icon: Icon(
                Icons.close,
                size: iconSize,
                color: const Color(0xFF001A36),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _InputLikeTile extends StatelessWidget {
  const _InputLikeTile({
    required this.title,
    this.titleStyle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onMore,
    required this.scale,
  });

  final String title;
  final TextStyle? titleStyle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final h = (61 * scale).clamp(61, 96).toDouble();
    final hp = (14 * scale).clamp(14, 20).toDouble();
    final gap = (8 * scale).clamp(8, 12).toDouble();
    final fs = (24 * scale).clamp(24, 36).toDouble();
    final r = (10 * scale).clamp(10, 14).toDouble();

    return InkWell(
      borderRadius: BorderRadius.circular(r),
      onTap: onTap,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: const Color(0xFFD2D2D2), width: 1),
        ),
        padding: EdgeInsets.symmetric(horizontal: hp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, SizedBox(width: gap)],
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      titleStyle ??
                      TextStyle(
                        color: Colors.black,
                        fontSize: fs,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                      ),
                ),
              ),
            ),
            SizedBox(width: gap),
            GestureDetector(
              onTap: onMore ?? onTap,
              child: trailing ?? const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Small shared widget ─────────────────────────

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
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              '허브를 먼저 선택/로그인 해주세요.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Local util ─────────────────────────

void _snack(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  (m ?? ScaffoldMessenger.of(context))
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
