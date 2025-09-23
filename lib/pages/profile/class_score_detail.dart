// lib/pages/profile/class_score_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../sidebar_menu.dart';

const String kHubId = 'hub-001'; // ✅ hub 경로용

class ClassScoreDetailsPage extends StatelessWidget {
  const ClassScoreDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments ?? {}) as Map;
    final classId = args['classId'] as String;
    final className = (args['className'] as String?) ?? 'My Class';

    final fs = FirebaseFirestore.instance;
    final logsQuery = fs
        .collection('hubs/$kHubId/classes/$classId/pointLogs') // ✅ hub 경로로 변경
        .orderBy('createdAt', descending: true);

    return AppScaffold(
      selectedIndex: 1,
      body: Scaffold(
        backgroundColor: const Color(0xFFF7FAFF),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    // 헤더
                    Row(
                      children: [
                        Text(
                          'Score Details • $className',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        _BackButton(),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 로그 리스트
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: logsQuery.snapshots(),
                        builder: (_, snap) {
                          if (!snap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          // map → 뷰모델
                          final logs = snap.data!.docs.map((d) {
                            final m = d.data();
                            final ts = (m['createdAt'] as Timestamp?)?.toDate()
                                ?? DateTime.fromMillisecondsSinceEpoch(0);
                            return _ClassLog(
                              id: d.id,
                              studentId: (m['studentId'] as String?) ?? '',
                              studentName: (m['studentName'] as String?) ?? '',
                              typeId: (m['typeId'] as String?) ?? '',
                              typeName: (m['typeName'] as String?) ?? '',
                              value: (m['value'] as num?)?.toInt() ?? 0,
                              ts: ts,
                            );
                          }).toList();

                          // 날짜별 그룹
                          final byDate = <String, List<_ClassLog>>{};
                          for (final l in logs) {
                            final key = '${l.ts.year}-${l.ts.month.toString().padLeft(2,'0')}-${l.ts.day.toString().padLeft(2,'0')}';
                            (byDate[key] ??= []).add(l);
                          }
                          final keys = byDate.keys.toList()..sort((a,b)=>b.compareTo(a));

                          return ListView.separated(
                            itemCount: keys.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (_, i) {
                              final k = keys[i];
                              final items = byDate[k]!;
                              final total = items.fold<int>(0, (s, e) => s + e.value);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(_prettyDate(k),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          )),
                                      const SizedBox(width: 12),
                                      Text('Total $total',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF94A3B8),
                                          )),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ...items.map((l) => _ClassLogTile(classId: classId, log: l)),
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
    final p = ymd.split('-');
    if (p.length != 3) return ymd;
    return '${p[1].padLeft(2,'0')}.${p[2].padLeft(2,'0')}';
  }
}

class _ClassLog {
  _ClassLog({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.typeId,
    required this.typeName,
    required this.value,
    required this.ts,
  });
  final String id;
  final String studentId;
  final String studentName;
  final String typeId;
  final String typeName;
  final int value;
  final DateTime ts;

  String get timeStr => '${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}';
}

class _ClassLogTile extends StatelessWidget {
  const _ClassLogTile({required this.classId, required this.log});
  final String classId;
  final _ClassLog log;

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final valueColor = const Color(0xFF1D9BF0);

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
          // 학생 이름(왼쪽)
          Expanded(
            flex: 2,
            child: Text(
              log.studentName.isEmpty ? log.studentId : log.studentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(width: 12),

          // 유형명
          Expanded(
            flex: 2,
            child: Text(
              log.typeName.isEmpty ? log.typeId : log.typeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),

          // 값
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 16),
            child: Text(
              log.value > 0 ? '+${log.value}' : '${log.value}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: log.value >= 0 ? valueColor : const Color(0xFFE11D48),
              ),
            ),
          ),

          // 시간
          Text(
            log.timeStr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 12),

          // 삭제 → 학생 포인트 되돌림 + 클래스 로그 삭제
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete this log?'),
                  content: const Text('This will revert the student points accordingly.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok != true) return;

              final fs = FirebaseFirestore.instance;
              final stuRef = fs.doc('hubs/$kHubId/students/${log.studentId}'); // ✅ hub 경로로 변경
              final classLogRef = fs.doc('hubs/$kHubId/classes/$classId/pointLogs/${log.id}'); // ✅ hub 경로로 변경

              await fs.runTransaction((tx) async {
                final cur = await tx.get(stuRef);
                final curPts = (cur.data()?['points'] as num?)?.toInt() ?? 0;
                tx.set(stuRef, {
                  'points': curPts - log.value,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                tx.delete(classLogRef);
              });

              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted.')));
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 18, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.maybePop(context),
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.white),
      label: const Text('Back', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
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
