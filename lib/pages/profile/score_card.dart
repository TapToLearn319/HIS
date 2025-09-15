

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScoreCard extends StatefulWidget {
  const ScoreCard({
    super.key,
    required this.studentId,
  });

  final String studentId;

  @override
  State<ScoreCard> createState() => _ScoreManagementCardState();
}

class _ScoreManagementCardState extends State<ScoreCard> {
  // 기본 포인트 유형들 (emoji, title, delta)
  final List<_Skill> _skills = [
    _Skill('🏔️', '끈기', 1),
    _Skill('❤️', '다른 사람을 도움', 1),
    _Skill('👍', '수업에 집중함', 1),
    _Skill('🏅', '열심히 노력', 1),
    _Skill('💡', '참여도 좋음', 1),
    _Skill('🤝', '팀워크', 1),
  ];

  Future<void> _givePoint(_Skill s) async {
    final fs = FirebaseFirestore.instance;
    final sid = widget.studentId;

    // points 필드를 원자적 증가 + 로그 남기기
    final ref = fs.collection('students').doc(sid);
    final batch = fs.batch();

    batch.set(ref, {'points': FieldValue.increment(s.delta)}, SetOptions(merge: true));

    final logRef = ref.collection('pointLogs').doc();
    batch.set(logRef, {
      'emoji': s.emoji,
      'title': s.title,
      'delta': s.delta,
      'ts': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${s.title}" +${s.delta}')),
    );
  }

  Future<void> _addCustomSkill() async {
    final emojiCtrl = TextEditingController(text: '➕');
    final titleCtrl = TextEditingController();
    final deltaCtrl = TextEditingController(text: '1');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('스킬 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emojiCtrl,
                decoration: const InputDecoration(labelText: 'Emoji (선택)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: deltaCtrl,
                decoration: const InputDecoration(labelText: '증감치(예: 1 또는 -1)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
          ],
        );
      },
    );

    if (ok == true) {
      final title = titleCtrl.text.trim();
      if (title.isEmpty) return;
      final delta = int.tryParse(deltaCtrl.text.trim()) ?? 1;
      setState(() {
        _skills.add(_Skill(emojiCtrl.text.trim().isEmpty ? '✨' : emojiCtrl.text.trim(), title, delta));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 카드 스타일
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // 반응형 칼럼 수
          int cross = 2;
          if (c.maxWidth >= 1080) cross = 4;
          else if (c.maxWidth >= 820) cross = 3;

          final tiles = [
            ..._skills.map((s) => _SkillTile(skill: s, onTap: () => _givePoint(s))),
            _AddTile(onTap: _addCustomSkill),
          ];

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tiles.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (_, i) => tiles[i],
          );
        },
      ),
    );
  }
}

class _Skill {
  final String emoji;
  final String title;
  final int delta;
  const _Skill(this.emoji, this.title, this.delta);
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.skill, required this.onTap});
  final _Skill skill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF2F5FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: const Color(0xFFDDE4EE)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: Text(
                  '+${skill.delta}',
                  style: const TextStyle(
                    color: Color(0xFF1BA672),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(skill.emoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    skill.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF2E3557),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF2F5FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFD2D7EE)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 56, color: Color(0xFF6C4CF7)),
                SizedBox(height: 12),
                Text('스킬 추가',
                    style: TextStyle(
                      color: Color(0xFF6C4CF7),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}