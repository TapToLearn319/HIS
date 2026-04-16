import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:project/pages/statistic/statistic_detail_page.dart';
import 'package:provider/provider.dart';

import '../../provider/hub_provider.dart';
import '../../sidebar_menu.dart';

const Color kStatisticWaitingBgColor = Color.fromARGB(255, 246, 250, 255);
const String kStatisticWaitingImageAsset = 'assets/logo_bird_main.png';

class StatisticListPage extends StatelessWidget {
  const StatisticListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hubPath = context.watch<HubProvider>().hubDocPath;

    if (hubPath == null) {
      return AppScaffold(
        selectedIndex: 2,
        body: const Scaffold(
          backgroundColor: kStatisticWaitingBgColor,
          body: Center(
            child: Text(
              '허브를 먼저 선택하세요.',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    final topicsStream = FirebaseFirestore.instance
        .collection('$hubPath/quizTopics')
        .orderBy('createdAt', descending: false)
        .snapshots();

    return AppScaffold(
      selectedIndex: 2,
      body: Scaffold(
        backgroundColor: const Color(0xFFEFF2F6),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFEFF2F6),
          title: const Text(
            'Statistic',
            style: TextStyle(color: Colors.black),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: topicsStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _StatisticWaitingScreen();
            }

            if (snap.hasError) {
              return Center(
                child: Text(
                  '불러오기 실패: ${snap.error}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            final docs = snap.data?.docs ?? const [];

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  '아직 생성된 퀴즈 토픽이 없습니다.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            return FutureBuilder<List<_StatisticCardData>>(
              future: _loadStatisticCards(hubPath, docs),
              builder: (context, cardSnap) {
                if (cardSnap.connectionState == ConnectionState.waiting) {
                  return const _StatisticWaitingScreen();
                }

                if (cardSnap.hasError) {
                  return Center(
                    child: Text(
                      '카드 계산 실패: ${cardSnap.error}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }

                final cards = cardSnap.data ?? const [];

                if (cards.isEmpty) {
                  return const Center(
                    child: Text(
                      '표시할 통계 카드가 없습니다.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  itemCount: cards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 1.78,
                  ),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return _StatisticCard(data: card);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  static Future<List<_StatisticCardData>> _loadStatisticCards(
    String hubPath,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final fs = FirebaseFirestore.instance;
    final hubId = _extractHubId(hubPath);

    final futures = <Future<_StatisticCardData>>[];

    for (int index = 0; index < docs.length; index++) {
      final doc = docs[index];
      final data = doc.data();

      futures.add(() async {
        final topicId = doc.id;

        final title = ((data['title'] ?? '') as String).trim().isEmpty
            ? 'Untitled'
            : (data['title'] as String).trim();

        final quizLabel = 'Quiz ${index + 1}';

        final Timestamp? dateTs =
            (data['endedAt'] as Timestamp?) ??
            (data['startedAt'] as Timestamp?) ??
            (data['createdAt'] as Timestamp?);

        final dateText = _formatDate(dateTs);

        final quizzesSnap =
            await fs.collection('$hubPath/quizTopics/$topicId/quizzes').get();
        final questionCount = quizzesSnap.docs.length;

        final sessionId = (data['sessionId'] as String?)?.trim();
        final runId = (data['activeRunId'] as String?)?.trim();

        int participantCount = 0;

        if (sessionId != null &&
            sessionId.isNotEmpty &&
            runId != null &&
            runId.isNotEmpty) {
          final responsesSnap = await fs
              .collection(
                'hubs/$hubId/sessions/$sessionId/quizRuns/$runId/responses',
              )
              .get();

          final studentIds = responsesSnap.docs
              .map((d) => (d.data()['studentId'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet();

          participantCount = studentIds.length;
        }

        return _StatisticCardData(
          topicId: topicId,
          title: title,
          quizLabel: quizLabel,
          questionCount: questionCount,
          participantCount: participantCount,
          dateText: dateText,
        );
      }());
    }

    return Future.wait(futures);
  }

  static String _extractHubId(String hubPath) {
    final parts = hubPath.split('/');
    return parts.isNotEmpty ? parts.last : hubPath;
  }

  static String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _StatisticCardData {
  final String topicId;
  final String title;
  final String quizLabel;
  final int questionCount;
  final int participantCount;
  final String dateText;

  const _StatisticCardData({
    required this.topicId,
    required this.title,
    required this.quizLabel,
    required this.questionCount,
    required this.participantCount,
    required this.dateText,
  });
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.data,
  });

  final _StatisticCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD4D4D8),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF001A36),
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                data.quizLabel,
                style: const TextStyle(
                  color: Color(0xFF001A36),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.grid_view_rounded,
                  text: '${data.questionCount} questions',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.people_outline_rounded,
                  text: '${data.participantCount} students',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  text: data.dateText,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(
              width: 84,
              height: 34,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatisticDetailPage(
                        topicId: data.topicId,
                        title: data.title,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7F7F8),
                  foregroundColor: const Color(0xFF222222),
                  side: const BorderSide(
                    color: Color(0xFFBDBDBD),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'more',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              )
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: const Color(0xFF222222),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 18,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _StatisticWaitingScreen extends StatelessWidget {
  const _StatisticWaitingScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kStatisticWaitingBgColor,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              kStatisticWaitingImageAsset,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.hourglass_top,
                color: Colors.black45,
                size: 100,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '잠시만 기다려주세요…',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}