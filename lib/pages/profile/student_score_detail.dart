

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../sidebar_menu.dart';
import 'presenter_student_log_page.dart' show kAttitudeTypes, kActivityTypes;

/// 점수 로그 1건의 뷰 모델
class _Log {
  _Log({
    required this.id,
    required this.typeId,
    required this.typeName,
    required this.value,
    required this.ts,
  });

  final String id;
  final String typeId;
  final String typeName;
  final int value;
  final DateTime ts;

  String get dateKey =>
      '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
  String get timeStr =>
      '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
}

/// 타입 → 이모지 매핑 (디테일에서도 사용)
final Map<String, String> _emojiByTypeId = {
  for (final t in [...kAttitudeTypes, ...kActivityTypes]) t.id: t.emoji,
};

class StudentScoreDetailsPage extends StatelessWidget {
  const StudentScoreDetailsPage({super.key});

  String get _studentIdArgKey => 'id';

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments ?? {}) as Map;
    final studentId = args[_studentIdArgKey] as String;

    final fs = FirebaseFirestore.instance;
    final studentRef = fs.doc('students/$studentId');
    final logsQuery = fs
        .collection('students/$studentId/pointLogs')
        .orderBy('createdAt', descending: true);

    return AppScaffold(
      selectedIndex: 1, // 사이드바 하이라이트
      body: Scaffold(
        backgroundColor: const Color(0xFFF7FAFF),
        body: SafeArea(
          child: Center(
            // 👈 화면 중앙으로 제한
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900), // 👈 최대폭 제한
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    // ── 헤더
                    Row(
                      children: [
                        const Text(
                          'Score Details',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: studentRef.snapshots(),
                          builder: (_, snap) {
                            final pts =
                                (snap.data?.data()?['points'] as num?)
                                    ?.toInt() ??
                                0;
                            return Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF44A0FF),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$pts',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        const _BackButton(),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── 로그 리스트
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: logsQuery.snapshots(),
                        builder: (_, snap) {
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          // Firestore → _Log
                          final logs =
                              snap.data!.docs.map((d) {
                                final m = d.data();
                                final ts =
                                    (m['createdAt'] as Timestamp?)?.toDate() ??
                                    DateTime.fromMillisecondsSinceEpoch(0);
                                return _Log(
                                  id: d.id,
                                  typeId: (m['typeId'] as String?) ?? '',
                                  typeName: (m['typeName'] as String?) ?? '',
                                  value: (m['value'] as num?)?.toInt() ?? 0,
                                  ts: ts,
                                );
                              }).toList();

                          // 날짜별 그룹
                          final byDate = <String, List<_Log>>{};
                          for (final l in logs) {
                            byDate.putIfAbsent(l.dateKey, () => []).add(l);
                          }
                          final dateKeys =
                              byDate.keys.toList()
                                ..sort((a, b) => b.compareTo(a)); // 최신 날짜 먼저

                          return ListView.separated(
                            itemCount: dateKeys.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 16),
                            itemBuilder: (_, i) {
                              final dk = dateKeys[i];
                              final items = byDate[dk]!;
                              final total = items.fold<int>(
                                0,
                                (sum, e) => sum + e.value,
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 섹션 헤더 (날짜 + Total n)
                                  Row(
                                    children: [
                                      Text(
                                        _prettyDate(dk),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Total $total',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // 리스트 아이템들
                                  ...items.map(
                                    (l) => _ScoreLogTile(
                                      studentId: studentId,
                                      log: l,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _prettyDate(String ymd) {
    final parts = ymd.split('-'); // yyyy-MM-dd
    if (parts.length != 3) return ymd;
    final m = parts[1].padLeft(2, '0');
    final d = parts[2].padLeft(2, '0');
    return '$m.$d';
  }
}

class _ScoreLogTile extends StatelessWidget {
  const _ScoreLogTile({required this.studentId, required this.log});

  final String studentId;
  final _Log log;

  @override
  Widget build(BuildContext context) {
    final emoji = _emojiByTypeId[log.typeId] ?? '•';
    final valueColor = const Color(0xFF1D9BF0); // 파란 포인트(+)

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 아이콘 박스
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),

          // 타입명
          Expanded(
            child: Text(
              log.typeName.isEmpty ? log.typeId : log.typeName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // +n
          Text(
            log.value > 0 ? '+${log.value}' : '${log.value}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: log.value >= 0 ? valueColor : const Color(0xFFE11D48),
            ),
          ),
          const SizedBox(width: 16),

          // 시간
          Text(
            log.timeStr,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 12),

          // 삭제(X)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _deleteLog(context),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 18, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLog(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete this log?'),
            content: const Text(
              'This will revert the student points accordingly.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok != true) return;

    final fs = FirebaseFirestore.instance;
    final stuRef = fs.doc('students/$studentId');
    final logRef = fs.doc('students/$studentId/pointLogs/${log.id}');

    await fs.runTransaction((tx) async {
      final cur = await tx.get(stuRef);
      final curPts = (cur.data()?['points'] as num?)?.toInt() ?? 0;
      final nextPts = curPts - log.value; // 로그를 되돌림

      tx.set(stuRef, {
        'points': nextPts,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.delete(logRef);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Deleted.')));
  }
}

/// 시안 스타일의 상단 Back 버튼
class _BackButton extends StatelessWidget {
  const _BackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.maybePop(context),
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 14,
        color: Colors.white,
      ),
      label: const Text(
        'Back',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF44A0FF),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: const Size(92, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }
}
