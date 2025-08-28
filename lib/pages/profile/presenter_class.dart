

// lib/pages/profile/presenter_class_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../sidebar_menu.dart';

// 학생 페이지와 동일한 타입 모델/섹션 -----------------------
class ScoreType {
  final String id;
  final String label;
  final String emoji;
  final int value;
  const ScoreType({
    required this.id,
    required this.label,
    required this.emoji,
    required this.value,
  });
}

const List<ScoreType> kAttitudeTypes = [
  ScoreType(id: 'focused', label: 'Focused', emoji: '❗️', value: 1),
  ScoreType(id: 'questioning', label: 'Questioning', emoji: '💬', value: 1),
  ScoreType(id: 'presentation', label: 'Presentation', emoji: '✋', value: 1),
  ScoreType(id: 'cooperate', label: 'Cooperate', emoji: '👥', value: 1),
  ScoreType(id: 'perseverance', label: 'Perseverance', emoji: '🚶', value: 1),
  ScoreType(id: 'positive', label: 'Positive energy', emoji: '🙂', value: 1),
];

const List<ScoreType> kActivityTypes = [
  ScoreType(id: 'focused2', label: 'Focused', emoji: '❗️', value: 1),
  ScoreType(id: 'questioning2', label: 'Questioning', emoji: '💬', value: 1),
  ScoreType(id: 'presentation2', label: 'Presentation', emoji: '✋', value: 1),
  ScoreType(id: 'cooperate2', label: 'Cooperate', emoji: '👥', value: 1),
  ScoreType(id: 'perseverance2', label: 'Perseverance', emoji: '🚶', value: 1),
  ScoreType(id: 'positive2', label: 'Positive energy', emoji: '🙂', value: 1),
];

// 학생 페이지와 동일한 아바타 크기
const double _avatarW = 290;
const double _avatarH = 268;

class PresenterClassPage extends StatefulWidget {
  const PresenterClassPage({super.key});
  @override
  State<PresenterClassPage> createState() => _PresenterClassPageState();
}

class _PresenterClassPageState extends State<PresenterClassPage> {
  final _fs = FirebaseFirestore.instance;

  String _classId(BuildContext context) =>
      ((ModalRoute.of(context)?.settings.arguments ?? {}) as Map?)?['classId']
          as String? ??
      'class-001';
  String _className(BuildContext context) =>
      ((ModalRoute.of(context)?.settings.arguments ?? {}) as Map?)?['className']
          as String? ??
      'My Class';

  Future<void> _applyToAll({
    required String classId,
    required String typeId,
    required String typeName,
    required int delta,
  }) async {
    final snap =
        await _fs
            .collection('students')
            .where('classId', isEqualTo: classId)
            .get();

    const chunk = 200;
    for (int i = 0; i < snap.docs.length; i += chunk) {
      final part = snap.docs.sublist(
        i,
        (i + chunk > snap.docs.length) ? snap.docs.length : i + chunk,
      );
      final batch = _fs.batch();

      for (final d in part) {
        final stuRef = _fs.doc('students/${d.id}');
        final logRef = _fs.collection('students/${d.id}/pointLogs').doc();

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

        // (선택) 클래스 로그 미러링
        batch.set(_fs.collection('classes/$classId/pointLogs').doc(), {
          'studentId': d.id,
          'studentName': (d.data()['name'] ?? '') as String,
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
    final classId = _classId(context);
    final className = _className(context);

    // 클래스 총 포인트(학생 points 합)를 배지에 표시
    final classStuStream =
        _fs
            .collection('students')
            .where('classId', isEqualTo: classId)
            .snapshots();

    return AppScaffold(
      selectedIndex: 1,
      body: Scaffold(
        backgroundColor: const Color(0xFFF7FAFF),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    // ── 상단: 타이틀 + Back 버튼 (우측 정렬)
                    Row(children: [const Spacer(), const _BackButton()]),
                    const SizedBox(height: 24),

                    // ── 메인: 좌(이미지/타이틀/디테일 링크) / 우(점수 카드)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 좌측: 이미지 + 클래스명 + 디테일 링크
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 이미지 + 포인트 배지 (학생 페이지와 동일 스타일)
                                Stack(
                                  children: [
                                    SizedBox(
                                      width: _avatarW,
                                      height: _avatarH,
                                      child: const DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Color(0xFFF6FAFF),
                                          image: DecorationImage(
                                            image: AssetImage(
                                              'assets/logo_bird.png',
                                            ),
                                            fit: BoxFit.contain,
                                            alignment: Alignment.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 클래스 총 포인트 합계 배지
                                    Positioned(
                                      right: 12,
                                      top: 12,
                                      child: StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>
                                      >(
                                        stream: classStuStream,
                                        builder: (_, snap) {
                                          int sum = 0;
                                          if (snap.hasData) {
                                            for (final d in snap.data!.docs) {
                                              sum +=
                                                  ((d.data()['points']
                                                              as num?) ??
                                                          0)
                                                      .toInt();
                                            }
                                          }
                                          return _PointBadge(value: sum);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: 218,
                                  child: Text(
                                    className,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF001A36),
                                      fontSize: 39,
                                      fontWeight: FontWeight.w500,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // 학생 페이지와 동일한 디테일 페이지 링크 (클래스 전용 라우트)
                                TextButton(
                                  onPressed: () {
                                    // TODO: 클래스 디테일 라우트 연결
                                    // Navigator.pushNamed(context, '/profile/class/details', arguments: {'classId': classId, 'className': className});
                                  },
                                  child: const Text(
                                    'View score details',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF868C98),
                                      fontSize: 23,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                      decorationStyle:
                                          TextDecorationStyle.solid,
                                      decorationColor: Color(0xFF868C98),
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 66),
                                // ⚠️ 학생버튼 연동은 클래스 페이지에 없음 (요청하신 대로)
                              ],
                            ),
                          ),

                          const SizedBox(width: 24),

                          // 우측: 점수 관리(Attitude / Activity)
                          Expanded(
                            flex: 5,
                            child: _ScoreManagementCard(
                              onPick:
                                  (id, name, v) => _applyToAll(
                                    classId: classId,
                                    typeId: id,
                                    typeName: name,
                                    delta: v,
                                  ),
                            ),
                          ),
                        ],
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
}

/* ─────────────────── Small widgets ─────────────────── */

class _PointBadge extends StatelessWidget {
  const _PointBadge({required this.value});
  final int value;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF44A0FF),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ScoreManagementCard extends StatelessWidget {
  const _ScoreManagementCard({required this.onPick});
  final void Function(String typeId, String typeName, int value) onPick;

  static const double _tileW = 142;
  static const double _tileH = 140;
  static const double _gap = 20;

  int _columnsFor(double w) {
    final cols = ((w + _gap) / (_tileW + _gap)).floor();
    return cols.clamp(2, 4);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = _columnsFor(box.maxWidth);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타이틀 라인 + Back 버튼 정렬을 학생페이지와 동일하게 유지하려면
              // 상단(페이지 헤더)에서 Back을 넣고 여기선 섹션 타이틀만 노출
              const _SectionTitle('Attitude Score'),
              const SizedBox(height: 12),
              _ScoreSectionGrid(
                columns: cols,
                types: kAttitudeTypes,
                onPick: onPick,
                tileW: _tileW,
                tileH: _tileH,
                gap: _gap,
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Activity Score'),
              const SizedBox(height: 12),
              _ScoreSectionGrid(
                columns: cols,
                types: kActivityTypes,
                onPick: onPick,
                tileW: _tileW,
                tileH: _tileH,
                gap: _gap,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0B1B33),
      ),
    );
  }
}

class _ScoreSectionGrid extends StatelessWidget {
  const _ScoreSectionGrid({
    required this.columns,
    required this.types,
    required this.onPick,
    required this.tileW,
    required this.tileH,
    required this.gap,
  });

  final int columns;
  final List<ScoreType> types;
  final void Function(String id, String name, int value) onPick;
  final double tileW, tileH, gap;

  @override
  Widget build(BuildContext context) {
    final items = [
      ...types,
      const ScoreType(id: '_add', label: 'Add Skill', emoji: '+', value: 0),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
        childAspectRatio: tileW / tileH,
      ),
      itemBuilder: (_, i) {
        final t = items[i];
        if (t.id == '_add') {
          return _AddSkillTile(width: tileW, height: tileH);
        }
        return _ScoreTileMini(
          emoji: t.emoji,
          label: t.label,
          onPlus: () => onPick(t.id, t.label, t.value.abs()),
          onMinus: () => onPick(t.id, t.label, -t.value.abs()),
        );
      },
    );
  }
}

class _ScoreTileMini extends StatelessWidget {
  const _ScoreTileMini({
    required this.emoji,
    required this.label,
    required this.onPlus,
    required this.onMinus,
    super.key,
  });

  final String emoji;
  final String label;
  final VoidCallback onPlus;
  final VoidCallback onMinus;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 카드
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD2D2D2)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 중앙 아이콘 (28×28)
                const SizedBox(width: 28, height: 28, child: SizedBox.shrink()),
                Positioned.fill(
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2A44),
                  ),
                ),
              ],
            ),
          ),
        ),

        // +1 (우상단)
        Positioned(
          right: 10,
          top: 10,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPlus,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F8ED),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '+1',
                style: TextStyle(
                  color: Color(0xFF128C4A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        // -1 (우하단)
        Positioned(
          right: 10,
          bottom: 10,
          child: IconButton(
            tooltip: '-1',
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            iconSize: 24,
            color: const Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

class _AddSkillTile extends StatelessWidget {
  const _AddSkillTile({required this.width, required this.height, super.key});
  final double width, height;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: width, height: height),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('스킬 추가는 곧 제공됩니다 😊')));
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD2D2D2), width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 32, color: Color(0xFF9CA3AF)),
                SizedBox(height: 8),
                Text(
                  'Add Skill',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
