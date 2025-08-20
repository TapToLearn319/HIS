
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// 학생 상세에서 쓰던 타입을 그대로 복붙/재사용해도 되고,
// 여기 파일 안에 간단 버전으로 둬도 됩니다.
class ScoreType {
  final String id;
  final String label;
  final String emoji;
  final int value;
  const ScoreType({required this.id, required this.label, required this.emoji, required this.value});
}

// 필요시 수정/추가
const List<ScoreType> kScoreTypes = [
  ScoreType(id: 'grit',        label: '끈기',       emoji: '🏁', value: 1),
  ScoreType(id: 'help',        label: '다른 사람을 도움', emoji: '❤️', value: 1),
  ScoreType(id: 'focus',       label: '수업에 집중', emoji: '👍', value: 1),
  ScoreType(id: 'effort',      label: '노력',       emoji: '🥇', value: 1),
  ScoreType(id: 'participate', label: '참여',       emoji: '💡', value: 1),
  ScoreType(id: 'teamwork',    label: '팀워크',     emoji: '🤹', value: 1),
];

class PresenterClassPage extends StatefulWidget {
  const PresenterClassPage({super.key});
  @override
  State<PresenterClassPage> createState() => _PresenterClassPageState();
}

class _PresenterClassPageState extends State<PresenterClassPage> {
  final _fs = FirebaseFirestore.instance;

  Future<void> _applyToAll({required String typeId, required String typeName, required int delta}) async {
    // 모든 학생에게 동일 delta 적용
    final snap = await _fs.collection('students').get();

    // Firestore batch는 500 write 제한 → 안전하게 200개 단위로 끊기
    const chunk = 200;
    for (int i = 0; i < snap.docs.length; i += chunk) {
      final batch = _fs.batch();
      final part = snap.docs.sublist(i, (i + chunk > snap.docs.length) ? snap.docs.length : i + chunk);

      for (final d in part) {
        final stuRef = _fs.doc('students/${d.id}');
        final logRef = _fs.collection('students/${d.id}/pointLogs').doc();

        // 합계만 중요 → 값은 누적만 하면 됨 (after는 생략)
        batch.set(stuRef, {
          'points': FieldValue.increment(delta),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        batch.set(logRef, {
          'typeId': typeId,
          'typeName': typeName,
          'value': delta,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('반 전체 ${delta > 0 ? '+$delta' : '$delta'} 적용 완료')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        title: const Text('Class • Score Management'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('모든 학생에게 부여할 포인트 유형을 선택하세요',
                style: TextStyle(fontSize: 16, color: Color(0xFF475569))),
            const SizedBox(height: 12),

            Expanded(
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3 / 2.2,
                    children: [
                      for (final t in kScoreTypes)
                        _ScoreTypeTileFancy(
                          emoji: t.emoji,
                          label: t.label,
                          onPlus:  () => _applyToAll(typeId: t.id, typeName: t.label, delta:  t.value.abs()),
                          onMinus: () => _applyToAll(typeId: t.id, typeName: t.label, delta: -t.value.abs()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreTypeTileFancy extends StatelessWidget {
  const _ScoreTypeTileFancy({required this.emoji, required this.label, required this.onPlus, required this.onMinus});
  final String emoji;
  final String label;
  final VoidCallback onPlus;
  final VoidCallback onMinus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xE0E3EAF5)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onPlus,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE8F6EC), borderRadius: BorderRadius.circular(999)),
                child: const Text('+1', style: TextStyle(color: Color(0xFF128C4A), fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 18, color: Color(0xFF2B3352), fontWeight: FontWeight.w700)),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: IconButton(tooltip: '-1', onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline)),
          ),
        ],
      ),
    );
  }
}