import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 허브(교실) ID — Presenter/Functions와 동일하게 유지하세요.
const String kHubId = 'hub-001';

class DisplayVotePage extends StatelessWidget {
  const DisplayVotePage({
    super.key,
    this.waitingImageAsset = 'assets/logo_bird_standby.png',
    this.waitingBackground = const Color.fromARGB(255, 246, 250, 255)
  });

  /// 대기화면에 보여줄 이미지 경로 (pubspec.yaml 에 등록 필요)
  final String waitingImageAsset;

  /// 대기화면 배경색
  final Color waitingBackground;

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    // 1) hubs/{hubId}.currentSessionId
    final hubStream = fs.doc('hubs/$kHubId').snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: hubStream,
        builder: (context, hubSnap) {
          if (hubSnap.connectionState == ConnectionState.waiting) {
            return _WaitingView(
              asset: waitingImageAsset,
              bg: waitingBackground,
            );
          }
          if (!hubSnap.hasData || !hubSnap.data!.exists) {
            return _WaitingView(
              asset: waitingImageAsset,
              bg: waitingBackground,
              message: 'Waiting for hub…',
            );
          }
          final data = hubSnap.data!.data() ?? {};
          final String? sid = data['currentSessionId'] as String?;
          if (sid == null || sid.isEmpty) {
            return _WaitingView(
              asset: waitingImageAsset,
              bg: waitingBackground,
              message: 'Waiting for session…',
            );
          }

          // 2) votes: status 가 active 또는 running 인 것 1개 구독
          final voteStream = fs
              .collection('sessions/$sid/votes')
              .where('status', whereIn: ['active', 'running'])
              .limit(1)
              .snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: voteStream,
            builder: (context, voteSnap) {
              if (voteSnap.connectionState == ConnectionState.waiting) {
                return _WaitingView(
                  asset: waitingImageAsset,
                  bg: waitingBackground,
                );
              }
              if (!voteSnap.hasData || voteSnap.data!.docs.isEmpty) {
                // 진행중 투표 없음 → 대기 화면
                return _WaitingView(
                  asset: waitingImageAsset,
                  bg: waitingBackground,
                );
              }

              final vDoc = voteSnap.data!.docs.first;
              final vData = vDoc.data();
              final String question =
                  (vData['question'] as String?) ?? 'Question';
              final Timestamp? startedAt = vData['startedAt'] as Timestamp?;

              if (startedAt == null) {
                return _WaitingView(
                  asset: waitingImageAsset,
                  bg: waitingBackground,
                  message: 'Preparing vote…',
                );
              }

              // 3) startedAt 이후 events 실시간 집계
              final eventsStream = fs
                  .collection('sessions/$sid/events')
                  .where('ts', isGreaterThanOrEqualTo: startedAt)
                  .orderBy('ts', descending: false)
                  .snapshots();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: eventsStream,
                builder: (context, evSnap) {
                  if (evSnap.connectionState == ConnectionState.waiting) {
                    return _WaitingView(
                      asset: waitingImageAsset,
                      bg: waitingBackground,
                      message: 'Counting…',
                    );
                  }
                  final docs = evSnap.data?.docs ?? const [];

                  final counts = _tallyFromEvents(
                    docs,
                    startedAt: startedAt,
                    endedAt: null,
                  );

                  return _VoteChartView(
                    question: question,
                    yes: counts.yes,
                    no: counts.no,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// 대기 화면(사용자 지정 이미지 + 배경색)
class _WaitingView extends StatelessWidget {
  const _WaitingView({
    required this.asset,
    required this.bg,
    this.message,
  });

  final String asset;
  final Color bg;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (message != null)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 투표 차트(찬성: 파랑, 반대: 빨강)
class _VoteChartView extends StatelessWidget {
  const _VoteChartView({
    required this.question,
    required this.yes,
    required this.no,
  });

  final String question;
  final int yes;
  final int no;

  @override
  Widget build(BuildContext context) {
    final total = yes + no;
    final yesRatio = total == 0 ? 0.0 : yes / total;
    final noRatio = total == 0 ? 0.0 : no / total;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 28),
            _bar(label: '찬성', value: yes, ratio: yesRatio, color: Colors.blue),
            const SizedBox(height: 14),
            _bar(label: '반대', value: no, ratio: noRatio, color: Colors.red),
            const Spacer(),
            Text(
              '총 ${total}명 참여',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar({
    required String label,
    required int value,
    required double ratio,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label  •  ${value}명',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 18,
            color: color,
            backgroundColor: color.withOpacity(0.15),
          ),
        ),
      ],
    );
  }
}

/// 집계 결과
class _Counts {
  final int yes;
  final int no;
  const _Counts(this.yes, this.no);
}

/// 이벤트 → 학생별 마지막 선택(1=찬성, 2=반대)으로 집계
_Counts _tallyFromEvents(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
  required Timestamp startedAt,
  Timestamp? endedAt,
}) {
    final startMs = startedAt.millisecondsSinceEpoch;
    final endMs = endedAt?.millisecondsSinceEpoch;

    final Map<String, _StudentVote> lastByStudent = {};

    for (final d in docs) {
      final x = d.data();

      // hubTs vs ts 중 더 최신 타임스탬프 사용
      final int hub = (x['hubTs'] is num) ? (x['hubTs'] as num).toInt() : 0;
      final int ser = (x['ts'] is Timestamp)
          ? (x['ts'] as Timestamp).millisecondsSinceEpoch
          : 0;
      final int t = hub > ser ? hub : ser;

      if (t < startMs) continue;
      if (endMs != null && t > endMs) continue;

      final String? sid = x['studentId'] as String?;
      final String? siRaw = x['slotIndex']?.toString();
      if (sid == null) continue;
      if (siRaw != '1' && siRaw != '2') continue;

      final prev = lastByStudent[sid];
      if (prev == null || t >= prev.tsMs) {
        lastByStudent[sid] = _StudentVote(tsMs: t, slotIndex: siRaw!);
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
