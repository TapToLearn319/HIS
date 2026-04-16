// lib/pages/profile/presenter_class_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../sidebar_menu.dart';

const String kHubId = 'hub-001'; // 허브 스코프 경로에 사용

// ───────────────────── 모델 ─────────────────────
class ScoreType {
  final String id;
  final String label;
  final String emoji;
  final int value;
  final String? asset; // ✅ 이미지 경로(있으면 이미지, 없으면 emoji 사용)

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
  ScoreType(
    id: 'focused',
    label: 'Focused',
    emoji: '❗️',
    value: 1,
    asset: 'assets/score/logo_bird_focused.png',
  ),
  ScoreType(
    id: 'questioning',
    label: 'Questioning',
    emoji: '💬',
    value: 1,
    asset: 'assets/score/logo_bird_questioning.png',
  ),
  ScoreType(
    id: 'presentation',
    label: 'Presentation',
    emoji: '✋',
    value: 1,
    asset: 'assets/score/logo_bird_presentation.png',
  ),
  ScoreType(
    id: 'cooperate',
    label: 'Cooperate',
    emoji: '👥',
    value: 1,
    asset: 'assets/score/logo_bird_cooperate.png',
  ),
  ScoreType(
    id: 'perseverance',
    label: 'Perseverance',
    emoji: '🚶',
    value: 1,
    asset: 'assets/score/logo_bird_perseverance.png',
  ),
  ScoreType(
    id: 'positive',
    label: 'Positive energy',
    emoji: '🙂',
    value: 1,
    asset: 'assets/score/logo_bird_positive-energy.png',
  ),
];

const List<ScoreType> kActivityTypes = [
  ScoreType(
    id: 'quiz',
    label: 'Quiz',
    emoji: '👥',
    value: 1,
    asset: 'assets/score/logo_bird_quiz.png',
  ),
  ScoreType(
    id: 'voting',
    label: 'Voting',
    emoji: '🚶',
    value: 1,
    asset: 'assets/score/logo_bird_voting.png',
  ),
  ScoreType(
    id: 'team',
    label: 'Team Activities',
    emoji: '🙂',
    value: 1,
    asset: 'assets/score/logo_bird_team-activites.png',
  ),
];

// 학생 페이지와 동일한 사이즈
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
    final fs = _fs;

    // 1) 브라우저/앱에서 눈에 보이는 피드백
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('반 전체에 ${delta > 0 ? '+$delta' : '$delta'} 적용 중…'),
      ),
    );

    // 2) 페이지네이션 쿼리 준비
    const pageSize = 500; // 읽기 페이지 크기
    const batchMax = 400; // 쓰기 배치 안전 한도

    Query<Map<String, dynamic>> baseQ = fs
        .collection('hubs/$kHubId/students')
        .where('classId', isEqualTo: classId)
        .orderBy(FieldPath.documentId);

    DocumentSnapshot? lastDoc;
    int updated = 0;

    while (true) {
      var q = baseQ.limit(pageSize);
      if (lastDoc != null) q = q.startAfterDocument(lastDoc);

      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      // 3) 이 페이지 처리: 여러 배치로 쪼개 커밋
      WriteBatch? batch;
      int inBatch = 0;

      Future<void> commitBatch() async {
        if (batch != null && inBatch > 0) {
          await batch!.commit();
          batch = null;
          inBatch = 0;
        }
      }

      for (final d in snap.docs) {
        // 필요 시 새 배치
        batch ??= fs.batch();

        final stuRef = fs.doc('hubs/$kHubId/students/${d.id}');
        final stuLogRef =
            fs.collection('hubs/$kHubId/students/${d.id}/pointLogs').doc();
        final classLogRef =
            fs.collection('hubs/$kHubId/classes/$classId/pointLogs').doc();

        batch!.update(stuRef, {
          'points': FieldValue.increment(delta),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        batch!.set(stuLogRef, {
          'typeId': typeId,
          'typeName': typeName,
          'value': delta,
          'createdAt': FieldValue.serverTimestamp(),
        });

        batch!.set(classLogRef, {
          'studentId': d.id,
          'studentName': (d.data()['name'] ?? '') as String,
          'typeId': typeId,
          'typeName': typeName,
          'value': delta,
          'createdAt': FieldValue.serverTimestamp(),
        });

        inBatch++;
        updated++;

        if (inBatch >= batchMax) {
          await commitBatch();
        }
      }

      await commitBatch();

      lastDoc = snap.docs.last;
    }

    if (!mounted) return;
    if (updated == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('해당 반의 학생을 찾지 못했어요. 학생 문서의 classId 값을 확인하세요.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '반 전체 $updated명에게 ${delta > 0 ? '+$delta' : '$delta'} 적용 완료',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final classId = _classId(context);
    final className = _className(context);

    final classStuStream =
        _fs
            .collection('hubs/$kHubId/students')
            .where('classId', isEqualTo: classId)
            .snapshots();

    return AppScaffold(
      selectedIndex: 1,
      body: Scaffold(
        backgroundColor: const Color(0xFFF7FAFF),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              const widthBp = 1000.0;
              const heightBp = 780.0;

              final isNarrow =
                  box.maxWidth < widthBp || box.maxHeight < heightBp;

              Widget leftPanel = Column(
                mainAxisSize: MainAxisSize.min,
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
                              alignment: Alignment.center,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: classStuStream,
                              builder: (_, snap) {
                                int sum = 0;
                                if (snap.hasData) {
                                  for (final d in snap.data!.docs) {
                                    sum +=
                                        ((d.data()['points'] as num?) ?? 0)
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
                    width: 260,
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
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/profile/class/details',
                        arguments: {'classId': classId, 'className': className},
                      );
                    },
                    child: const Text(
                      'View score details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF868C98),
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.solid,
                        decorationColor: Color(0xFF868C98),
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              );
              final rightPanel = SizedBox(
                width: 680,
                child: _ScoreManagementCard(
                  onPick:
                      (id, name, v) => _applyToAll(
                        classId: classId,
                        typeId: id,
                        typeName: name,
                        delta: v,
                      ),
                ),
              );

              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: Center(
                      child:
                          isNarrow
                              ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  leftPanel,
                                  const SizedBox(height: 32),
                                  rightPanel,
                                ],
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(width: 360, child: leftPanel),
                                  const SizedBox(width: 40),
                                  rightPanel,
                                ],
                              ),
                    ),
                  ),
                ),
              );
            },
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

  static const double _tileW = 204;
  static const double _tileH = 106;
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

        return Column(
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
    final items = types;

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
        final isQuiz = t.id == 'quiz';

        return _ScoreTileMini(
          emoji: t.emoji,
          label: t.label,
          asset: t.asset,
          onPlus: () => onPick(t.id, t.label, t.value.abs()),
          onMinus: () => onPick(t.id, t.label, -t.value.abs()),
          detailLabel: isQuiz ? 'Details' : null,
          onDetailTap:
              isQuiz
                  ? () {
                    Navigator.pushNamed(context, '/quiz/details');
                  }
                  : null,
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
    this.detailLabel,
    this.onDetailTap,
    super.key,
  });

  final String emoji;
  final String label;
  final String? asset;
  final String badgeText;
  final VoidCallback onPlus;
  final VoidCallback onMinus;
  final String? detailLabel;
  final VoidCallback? onDetailTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const baseW = 204.0;
        const baseH = 106.0;

        final sW = (c.maxWidth / baseW).clamp(0.7, 1.4);
        final sH = (c.maxHeight / baseH).clamp(0.7, 1.4);
        final s = sW < sH ? sW : sH;

        final imgSize = (100.0 * s).clamp(56.0, 120.0);
        final emojiSize = (40.0 * s).clamp(22.0, 48.0);

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10 * s),
                border: Border.all(color: const Color(0xFFD2D2D2)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 18 * s,
                    top: 8 * s,
                    right: 50 * s,
                    child: Text(
                      label,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16 * s,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1F2A44),
                        height: 41 / 16,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 86 * s,
                    top: 35 * s,
                    child: SizedBox(
                      width: imgSize,
                      height: imgSize,
                      child:
                          asset != null
                              ? Image.asset(asset!, fit: BoxFit.contain)
                              : Center(
                                child: Text(
                                  emoji,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: emojiSize),
                                ),
                              ),
                    ),
                  ),
                  Positioned(
                    left: 18 * s,
                    top: 67 * s,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onPlus,
                      child: Container(
                        padding: EdgeInsets.zero,
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w600,
                            fontSize: 24 * s,
                            color: const Color(0xFF44A0FF),
                            height: 1.0,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (detailLabel != null && onDetailTap != null)
                    Positioned(
                      right: 16 * s,
                      top: 19 * s,
                      child: GestureDetector(
                        onTap: onDetailTap,
                        child: Text(
                          detailLabel!,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12 * s,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFA2A2A2),
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFFA2A2A2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
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
