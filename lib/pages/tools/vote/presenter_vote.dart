// lib/pages/vote/presenter_vote_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../provider/session_provider.dart';

class PresenterVotePage extends StatefulWidget {
  const PresenterVotePage({super.key});

  @override
  State<PresenterVotePage> createState() => _PresenterVotePageState();
}

class _PresenterVotePageState extends State<PresenterVotePage> {
  bool _busy = false;
  String? _busyMsg;

  void _setBusy(bool v, [String? msg]) {
    if (!mounted) return;
    setState(() {
      _busy = v;
      _busyMsg = v ? (msg ?? 'Working...') : null;
    });
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) {
      debugPrint('[VOTE] $msg');
      return;
    }
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createQuestionDialog(String sid) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create a question'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Question',
            border: OutlineInputBorder(),
            hintText: '예: 이번 과제 제출 마감 연장에 찬성하나요?',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true) {
      final q = c.text.trim();
      if (q.isEmpty) return;
      final fs = FirebaseFirestore.instance;
      await fs.collection('sessions/$sid/votes').add({
        'question': q,
        'status': 'draft', // draft → active → stopped
        'createdAt': FieldValue.serverTimestamp(),
      });
      _snack('Question created.');
    }
  }

  /// Stop all ACTIVE votes in this session.
  Future<void> _stopAllActive(String sid) async {
    final fs = FirebaseFirestore.instance;
    final running = await fs
        .collection('sessions/$sid/votes')
        .where('status', isEqualTo: 'active')
        .get();
    if (running.docs.isEmpty) return;

    final now = FieldValue.serverTimestamp();
    final batch = fs.batch();
    for (final d in running.docs) {
      batch.set(
        d.reference,
        {
          'status': 'stopped',
          'endedAt': now,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> _startVote(String sid, String voteId) async {
    _setBusy(true, 'Starting vote…');
    try {
      await _stopAllActive(sid);
      await FirebaseFirestore.instance.doc('sessions/$sid/votes/$voteId').set(
        {
          'status': 'active', // ✅ 통일
          'startedAt': FieldValue.serverTimestamp(),
          'endedAt': null,
          'finalYes': FieldValue.delete(),
          'finalNo': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
      _snack('Vote started.');
    } finally {
      _setBusy(false);
    }
  }

  /// Compute final counts from events (between [startedAt, endedAt]) and save.
  Future<void> _stopVoteAndFinalize({
    required String sid,
    required String voteId,
    required Timestamp startedAt,
  }) async {
    _setBusy(true, 'Stopping & finalizing…');
    try {
      final fs = FirebaseFirestore.instance;

      // ts >= startedAt 만 서버 필터, 종료 순간은 로컬에서 포함
      final q = await fs
          .collection('sessions/$sid/events')
          .where('ts', isGreaterThanOrEqualTo: startedAt)
          .orderBy('ts', descending: false)
          .get();

      final endedAtTS = Timestamp.now();
      final res = _tallyFromEvents(q.docs, startedAt: startedAt, endedAt: endedAtTS);

      await fs.doc('sessions/$sid/votes/$voteId').set(
        {
          'status': 'stopped',
          'endedAt': FieldValue.serverTimestamp(),
          'finalYes': res.yes,
          'finalNo': res.no,
        },
        SetOptions(merge: true),
      );
      _snack('Vote stopped.');
    } catch (e) {
      _snack('Stop failed: $e');
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sid = context.watch<SessionProvider>().sessionId;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Vote (Presenter)'),
        actions: [
          if (sid != null)
            IconButton(
              tooltip: 'Create question',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _createQuestionDialog(sid),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (sid == null)
            const Center(child: Text('No session. Please set a session first.'))
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('sessions/$sid/votes')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(child: Text('No questions. Tap + to add.'));
                }
                final votes = snap.data!.docs.map((d) => _VoteDoc.from(d)).toList();
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, i) => _voteCard(sid, votes[i]),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: votes.length,
                );
              },
            ),

          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(
                      _busyMsg ?? 'Working…',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _voteCard(String sid, _VoteDoc v) {
    final statusColor = v.status == 'active'
        ? Colors.green
        : (v.status == 'stopped' ? Colors.grey : Colors.orange);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 + 상태칩 + 삭제
            Row(
              children: [
                Expanded(
                  child: Text(
                    v.question,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    v.status.toUpperCase(),
                    style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete question'),
                        content: const Text('정말 삭제할까요?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await FirebaseFirestore.instance.doc('sessions/$sid/votes/${v.id}').delete();
                      _snack('Deleted.');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 집계부 (상태별)
            if (v.status == 'draft')
              const Text('Start를 누르면 집계를 시작합니다.', style: TextStyle(color: Colors.grey))
            else
              _TallyLive(
                sid: sid,
                startedAt: v.startedAt,
                endedAt: v.endedAt,
              ),

            const SizedBox(height: 8),

            // 액션 버튼
            Row(
              children: [
                if (v.status != 'active')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    onPressed: () => _startVote(sid, v.id),
                  ),
                if (v.status == 'active')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    label: const Text('Stop'),
                    onPressed: () {
                      if (v.startedAt == null) {
                        _snack('startedAt가 없습니다.');
                        return;
                      }
                      _stopVoteAndFinalize(
                        sid: sid,
                        voteId: v.id,
                        startedAt: v.startedAt!,
                      );
                    },
                  ),
                const Spacer(),
                if (v.status == 'stopped' && v.finalYes != null && v.finalNo != null)
                  Text('Final: 찬성 ${v.finalYes} • 반대 ${v.finalNo}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 투표 실시간/최종 집계 위젯.
/// - 진행중: startedAt 이후 이벤트 스트림을 실시간으로 읽어 학생별 마지막 slotIndex(1/2)를 반영.
/// - 종료됨: startedAt~endedAt 사이만 로컬 필터링하여 동일 로직.
class _TallyLive extends StatelessWidget {
  const _TallyLive({
    required this.sid,
    required this.startedAt,
    required this.endedAt,
  });

  final String sid;
  final Timestamp? startedAt;
  final Timestamp? endedAt;

  @override
  Widget build(BuildContext context) {
    if (startedAt == null) {
      return const SizedBox.shrink();
    }

    final fs = FirebaseFirestore.instance;

    // 쿼리: ts >= startedAt 만 서버 필터, 종료 시각은 로컬에서 필터(인덱스 회피)
    final stream = fs
        .collection('sessions/$sid/events')
        .where('ts', isGreaterThanOrEqualTo: startedAt)
        .orderBy('ts', descending: false)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        if (!snap.hasData) {
          return const Text('집계 데이터를 불러오는 중…');
        }

        final docs = snap.data!.docs;
        final res = _tallyFromEvents(
          docs,
          startedAt: startedAt!,
          endedAt: endedAt, // null이면 진행 중
        );

        final total = (res.yes + res.no);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tallyRow('찬성 (slot 1)', res.yes, total, color: Colors.green),
            const SizedBox(height: 4),
            _tallyRow('반대 (slot 2)', res.no, total, color: Colors.red),
          ],
        );
      },
    );
  }

  Widget _tallyRow(String label, int value, int total, {required Color color}) {
    final ratio = total == 0 ? 0.0 : (value / total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label  •  $value', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 10,
            color: color,
            backgroundColor: color.withOpacity(0.15),
          ),
        ),
      ],
    );
  }
}

/// 집계 결과 자료형
class _Counts {
  final int yes;
  final int no;
  const _Counts(this.yes, this.no);
}

/// 이벤트 문서 목록을 학생별 마지막 선택으로 집계한다.
/// - slotIndex '1' → 찬성, '2' → 반대
/// - 같은 학생의 여러 이벤트는 마지막 ts/hubTs만 반영
_Counts _tallyFromEvents(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
  required Timestamp startedAt,
  Timestamp? endedAt,
}) {
  final startMs = startedAt.millisecondsSinceEpoch;
  final endMs = endedAt?.millisecondsSinceEpoch;

  // 학생별 마지막 (tsMs → slotIndex)
  final Map<String, _StudentVote> lastByStudent = {};

  for (final d in docs) {
    final data = d.data();

    // 시간 계산: hubTs vs ts 중 더 최신
    final int hub = (data['hubTs'] is num) ? (data['hubTs'] as num).toInt() : 0;
    final int ser = (data['ts'] is Timestamp)
        ? (data['ts'] as Timestamp).millisecondsSinceEpoch
        : 0;
    final int t = hub > ser ? hub : ser;
    if (t < startMs) continue;
    if (endMs != null && t > endMs) continue;

    final String? sid = data['studentId'] as String?;
    final String? siRaw = data['slotIndex']?.toString();
    if (sid == null) continue;
    if (siRaw != '1' && siRaw != '2') continue;

    final prev = lastByStudent[sid];
    if (prev == null || t >= prev.tsMs) {
      final String si = siRaw!; // '1' or '2'
      lastByStudent[sid] = _StudentVote(tsMs: t, slotIndex: si);
    }
  }

  int yes = 0, no = 0;
  for (final v in lastByStudent.values) {
    if (v.slotIndex == '1') yes++;
    if (v.slotIndex == '2') no++;
  }
  return _Counts(yes, no);
}

class _StudentVote {
  final int tsMs;
  final String slotIndex; // '1' | '2'
  _StudentVote({required this.tsMs, required this.slotIndex});
}

/// Vote 문서 모델
class _VoteDoc {
  final String id;
  final String question;
  final String status; // draft | active | stopped
  final Timestamp? createdAt;
  final Timestamp? startedAt;
  final Timestamp? endedAt;
  final int? finalYes;
  final int? finalNo;

  _VoteDoc({
    required this.id,
    required this.question,
    required this.status,
    this.createdAt,
    this.startedAt,
    this.endedAt,
    this.finalYes,
    this.finalNo,
  });

  factory _VoteDoc.from(DocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data() ?? const {};
    return _VoteDoc(
      id: d.id,
      question: (x['question'] as String?) ?? '(no question)',
      status: (x['status'] as String?) ?? 'draft',
      createdAt: x['createdAt'] as Timestamp?,
      startedAt: x['startedAt'] as Timestamp?,
      endedAt: x['endedAt'] as Timestamp?,
      finalYes: (x['finalYes'] as num?)?.toInt(),
      finalNo: (x['finalNo'] as num?)?.toInt(),
    );
  }
}
