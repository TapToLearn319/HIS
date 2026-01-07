// lib/pages/profile/presenter_class_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../sidebar_menu.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';

// ───────────────────── 모델 ─────────────────────
class ScoreType {
  final String id;
  final String label;
  final String emoji;
  final int value;
  final String? asset;

  const ScoreType({
    required this.id,
    required this.label,
    required this.emoji,
    required this.value,
    this.asset,
  });
}

// 학생 페이지와 동일한 아이콘/에셋 매핑
const List<ScoreType> kAttitudeTypes = [
  ScoreType(id: 'focused', label: 'Focused', emoji: '❗️', value: 1, asset: 'assets/score/logo_bird_focused.png'),
  ScoreType(id: 'questioning', label: 'Questioning', emoji: '💬', value: 1, asset: 'assets/score/logo_bird_questioning.png'),
  ScoreType(id: 'presentation', label: 'Presentation', emoji: '✋', value: 1, asset: 'assets/score/logo_bird_presentation.png'),
  ScoreType(id: 'cooperate', label: 'Cooperate', emoji: '👥', value: 1, asset: 'assets/score/logo_bird_cooperate.png'),
  ScoreType(id: 'perseverance', label: 'Perseverance', emoji: '🚶', value: 1, asset: 'assets/score/logo_bird_perseverance.png'),
  ScoreType(id: 'positive', label: 'Positive energy', emoji: '🙂', value: 1, asset: 'assets/score/logo_bird_positive-energy.png'),
];

const List<ScoreType> kActivityTypes = [
  ScoreType(id: 'quiz', label: 'Quiz', emoji: '👥', value: 3, asset: 'assets/score/logo_bird_quiz.png'),
  ScoreType(id: 'voting', label: 'Voting', emoji: '🚶', value: 4, asset: 'assets/score/logo_bird_voting.png'),
  ScoreType(id: 'team', label: 'Team Activities', emoji: '🙂', value: 5, asset: 'assets/score/logo_bird_team-activites.png'),
];

const double _avatarW = 290;
const double _avatarH = 268;
const double _tileImgSize = 100;
const double _tileGap = 12;
const double _tileLabelSize = 24;

class PresenterClassPage extends StatefulWidget {
  const PresenterClassPage({super.key});
  @override
  State<PresenterClassPage> createState() => _PresenterClassPageState();
}

class _PresenterClassPageState extends State<PresenterClassPage> {
  final _fs = FirebaseFirestore.instance;

  String _classId(BuildContext context) =>
      ((ModalRoute.of(context)?.settings.arguments ?? {}) as Map?)?['classId'] as String? ?? 'class-001';

  String _className(BuildContext context) =>
      ((ModalRoute.of(context)?.settings.arguments ?? {}) as Map?)?['className'] as String? ?? 'My Class';

  bool _applyingAll = false;

Future<void> _applyToAll({
  required String hubId,
  required String typeId,
  required String typeName,
  required int delta,
}) async {
  if (_applyingAll) return; // 🔒 중복 실행 방지
  _applyingAll = true;

  final fs = _fs;

  try {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('전체 학생에게 ${delta > 0 ? '+$delta' : '$delta'} 적용 중…'),
      ),
    );

    const batchMax = 200;

    // ✅ students 전체를 한 번만 조회
    final snap = await fs.collection('hubs/$hubId/students').get();
    if (snap.docs.isEmpty) return;

    WriteBatch batch = fs.batch();
    int inBatch = 0;
    int updated = 0;

    for (final d in snap.docs) {
      final stuRef = fs.doc('hubs/$hubId/students/${d.id}');
      final stuLogRef =
          fs.collection('hubs/$hubId/students/${d.id}/pointLogs').doc();

      batch.set(
        stuRef,
        {
          'points': FieldValue.increment(delta),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(stuLogRef, {
        'typeId': typeId,
        'typeName': typeName,
        'value': delta,
        'createdAt': FieldValue.serverTimestamp(),
      });

      inBatch++;
      updated++;

      // 🔹 배치 커밋
      if (inBatch >= batchMax) {
        await batch.commit();
        batch = fs.batch();
        inBatch = 0;
      }
    }

    // 🔹 남은 배치 커밋
    if (inBatch > 0) {
      await batch.commit();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('전체 학생 $updated명에게 ${delta > 0 ? '+$delta' : '$delta'} 적용 완료'),
      ),
    );
  } finally {
    _applyingAll = false; // 🔓 락 해제
  }
}

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubProvider>();
    final hubId = hub.hubId;

    if (hubId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final classId = _classId(context);
    final className = _className(context);

    final classStuStream = _fs
        .collection('hubs/$hubId/students')
        .snapshots();

    return AppScaffold(
      selectedIndex: 1,
      body: Scaffold(
        backgroundColor: const Color(0xFFF7FAFF),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: LayoutBuilder(
              builder: (context, box) {
                const bp = 1000.0;
                final isNarrow = box.maxWidth < bp;

                final leftPanel = SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          const SizedBox(
                            width: _avatarW,
                            height: _avatarH,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFF6FAFF),
                                image: DecorationImage(
                                  image: AssetImage('assets/logo_bird.png'),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: classStuStream,
                              builder: (_, snap) {
                                int sum = 0;
                                if (snap.hasData) {
                                  for (final d in snap.data!.docs) {
                                    sum += ((d.data()['points'] as num?) ?? 0).toInt();
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
                        width: 260,
                        child: Text(
                          className,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 39, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );

                final rightPanel = _ScoreManagementCard(
                  onPick: (id, name, v) => _applyToAll(
                    hubId: hubId,
                    //classId: classId,
                    typeId: id,
                    typeName: name,
                    delta: v,
                  ),
                );

                if (isNarrow) {
                  return ListView(children: [leftPanel, rightPanel]);
                }

                return Row(
                  children: [
                    Expanded(child: leftPanel),
                    const SizedBox(width: 24),
                    Expanded(child: rightPanel),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}


// ───────────────────── 위젯들 ─────────────────────

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  _SectionTitle('Attitude Score'),
                  Spacer(),
                  _BackButton(),
                ],
              ),
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
        color: Color(0xFF001A36),
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 1.0,
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
          asset: t.asset,
          badgeText: t.id == 'voting' ? '+N' : '+${t.value.abs()}',
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
    this.asset,
    this.badgeText = '+1',
    super.key,
  });

  final String emoji;
  final String label;
  final String? asset;
  final String badgeText;
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: _tileImgSize,
                    height: _tileImgSize,
                    child:
                        asset != null
                            ? Image.asset(asset!, fit: BoxFit.contain)
                            : Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 40),
                              ),
                            ),
                  ),
                  const SizedBox(height: _tileGap),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: _tileLabelSize,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2A44),
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // +N / +1
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
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Color(0xFF128C4A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        // -1
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
