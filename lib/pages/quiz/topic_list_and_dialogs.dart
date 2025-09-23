// lib/pages/quiz/topic_list_and_dialogs.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';
import 'topic_detail.dart'; // TopicDetailPage

// ───────────────────────── Create Topic FAB ─────────────────────────

class CreateTopicFab extends StatelessWidget {
  const CreateTopicFab({super.key});

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
              onTap: () => _createTopicDialog(context),
              child: Tooltip(
                message: 'Create topic',
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Image.asset(
                    'assets/logo_bird_create.png',
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
    builder: (_) => AlertDialog(
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
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
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
    _snack(context, '허브를 먼저 선택하세요.');
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

  // 진행 중이면 안전하게 종료 처리
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

  // 로딩 오버레이
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
    useRootNavigator: true,
  );

  try {
    await _deleteCollection(fs, '$hubPath/quizTopics/$topicId/quizzes', 300);
    await _deleteCollection(fs, '$hubPath/quizTopics/$topicId/results', 300);
    await fs.doc('$hubPath/quizTopics/$topicId').delete();

    Navigator.of(context, rootNavigator: true).pop();
    _snack(context, 'Topic deleted.');
  } catch (e) {
    Navigator.of(context, rootNavigator: true).pop();
    _snack(context, 'Delete failed: $e');
  }
}

Future<void> _deleteCollection(
  FirebaseFirestore fs,
  String path,
  int batchSize,
) async {
  while (true) {
    final snap = await fs.collection(path).limit(batchSize).get();
    if (snap.docs.isEmpty) break;
    final batch = fs.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    if (snap.docs.length < batchSize) break;
  }
}

// ───────────────────────── Topic List (grid) ─────────────────────────

class TopicList extends StatelessWidget {
  const TopicList({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    final hub = context.watch<HubProvider>();
    final hubPath = hub.hubDocPath; // hubs/{hubId}

    if (hubPath == null) {
      return const _EmptyState(
        title: '허브가 선택되지 않았어요',
        subtitle: '허브를 먼저 선택/로그인 해주세요.',
      );
    }

    final stream =
        fs.collection('$hubPath/quizTopics').orderBy('createdAt', descending: true).snapshots();

    String _fmtDate(Timestamp? ts) {
      final dt = ts?.toDate();
      if (dt == null) return '-';
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    Future<int> _quizCount(String hubPath, String topicId) async {
      final qs = await fs.collection('$hubPath/quizTopics/$topicId/quizzes').get();
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
                maxCrossAxisExtent: 440,
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
                        MaterialPageRoute(builder: (_) => TopicDetailPage(topicId: d.id)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 제목 + 메뉴
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    color: Color(0xFF0B1324),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Topic actions',
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    await _renameTopicDialog(
                                      context,
                                      fs,
                                      topicId: d.id,
                                      initialTitle: title,
                                    );
                                  } else if (v == 'delete') {
                                    await _deleteTopicWithSubcollections(
                                      context,
                                      fs,
                                      topicId: d.id,
                                      status: (x['status'] as String?),
                                    );
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      leading: Icon(Icons.edit),
                                      title: Text('Edit topic'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete, color: Colors.red),
                                      title: Text('Delete topic'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Divider(color: Colors.black, thickness: 1),

                          const SizedBox(height: 12),
                          // 퀴즈 개수
                          FutureBuilder<int>(
                            future: _quizCount(hubPath, d.id),
                            builder: (context, snapCount) {
                              final cnt = snapCount.data ?? 0;
                              return Row(
                                children: [
                                  const Icon(Icons.view_module_outlined, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '퀴즈 $cnt개',
                                    style: const TextStyle(fontSize: 16),
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
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),

                          const Spacer(),

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
                                  MaterialPageRoute(builder: (_) => TopicDetailPage(topicId: d.id)),
                                );
                              },
                              child: const Text(
                                'more ›',
                                style: TextStyle(
                                  fontSize: 16,
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
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
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
