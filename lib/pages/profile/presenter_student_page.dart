// lib/pages/profile/presenter_student_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../sidebar_menu.dart';

const String kHubId = 'hub-001';

const double _avatarW = 290;
const double _avatarH = 268;

const double _imgSize = 100;
const double _gap = 12;
const double _emojiSz = 40;
const double _labelSz = 24;

class ScoreType {
  final String id; // 내부용 키
  final String label; // 표시 이름
  final String emoji; // 이모지
  final int value; // +1, -1 같은 기본값 (양/음수는 onTapMinus에서 바꿔줌)
  final String? asset;

  const ScoreType({
    required this.id,
    required this.label,
    required this.emoji,
    required this.value,
    this.asset,
  });
}

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

class PresenterStudentPage extends StatefulWidget {
  const PresenterStudentPage({super.key});

  @override
  State<PresenterStudentPage> createState() => _PresenterStudentPageState();
}

class _PresenterStudentPageState extends State<PresenterStudentPage> {
  String get studentId =>
      (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String;

  // ─── UI helpers
  void _toast(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m != null) {
      m.hideCurrentSnackBar();
      m.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ─── 점수 반영
  Future<void> _applyScore({
    required String typeId,
    required String typeName,
    required int value, // 양수/음수 모두 허용
  }) async {
    final fs = FirebaseFirestore.instance;
    final stuRef = fs.doc('hubs/$kHubId/students/$studentId');
    final logRef =
        fs.collection('hubs/$kHubId/students/$studentId/pointLogs').doc();

    await fs.runTransaction((tx) async {
      final cur = await tx.get(stuRef);
      final curPts = (cur.data()?['points'] as num?)?.toInt() ?? 0;
      final nextPts = curPts + value;

      tx.set(stuRef, {
        'points': nextPts,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(logRef, {
        'typeId': typeId,
        'typeName': typeName,
        'value': value,
        'after': nextPts,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    _toast(value >= 0 ? '+$value applied' : '$value applied');
  }

  // ─── 버튼 매핑(개선 버전)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _capSub;
  Timer? _capTimer;
  bool _capturing = false;

  Future<void> _captureToSlot(String slotIndex) async {
    if (_capturing) return;
    _capturing = true;

    final fs = FirebaseFirestore.instance;
    final liveCol = fs.collection('hubs/$kHubId/liveByDevice');

    // 🔥 매핑 시작 시점
    final startAtMs = DateTime.now().millisecondsSinceEpoch;

    bool handled = false;
    bool dialogOpen = true;
    bool skippedInitial = false; // 첫 스냅샷 무시

    _capSub = liveCol.snapshots().listen(
      (snap) async {
        if (!skippedInitial) {
          skippedInitial = true;
          debugPrint(
            '[pair] initial snapshot: ${snap.docs.length} docs (ignored)',
          );
          return;
        }
        if (handled) return;
        if (snap.docChanges.isEmpty) return;

        for (final ch in snap.docChanges) {
          if (ch.type == DocumentChangeType.removed) continue;
          if (ch.doc.metadata.hasPendingWrites) continue;

          // 🔥 liveByDevice 데이터에서 hubTs 읽기
          final data = ch.doc.data();
          final hubTs = data?['lastHubTs'] as int? ?? 0;

          // 🔥 매핑 시작 전에 눌렸던 이벤트면 스킵
          if (hubTs < startAtMs) {
            debugPrint(
              '[pair] skip old event: hubTs=$hubTs < startAtMs=$startAtMs',
            );
            continue;
          }

          // 여기까지 왔으면 "지금 매핑을 시작한 이후에" 눌린 버튼
          final devId = ch.doc.id;
          handled = true;

          try {
            await fs.doc('hubs/$kHubId/devices/$devId').set({
              'studentId': studentId,
              'slotIndex': slotIndex,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            if (mounted) _toast('Linked $devId (slot $slotIndex)');
          } catch (e) {
            if (mounted) _toast('Register failed: $e');
          } finally {
            _capSub?.cancel();
            _capSub = null;
            _capTimer?.cancel();
            _capTimer = null;
            _capturing = false;

            if (mounted && dialogOpen) {
              try {
                Navigator.of(context, rootNavigator: true).pop(true);
              } catch (_) {}
            }
          }
          break;
        }
      },
      onError: (e, st) {
        if (mounted) _toast('Pairing stream error: $e');
      },
    );

    // 밑에 기존 dialog / timer 코드는 그대로 유지

    final waitFuture = showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: Text('Waiting for button… (slot $slotIndex)'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8),
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Press the Flic now.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );

    _capTimer = Timer(const Duration(seconds: 25), () {
      if (handled) return;
      if (mounted && dialogOpen) {
        try {
          Navigator.of(context, rootNavigator: true).pop(false);
        } catch (_) {}
      }
    });

    final res = await waitFuture;
    dialogOpen = false;

    if (!handled) {
      _capSub?.cancel();
      _capSub = null;
      _capTimer?.cancel();
      _capTimer = null;
      _capturing = false;

      if (res == false && mounted) {
        _toast('Canceled.');
      } else if (mounted) {
        _toast('Timed out.');
      }
    }
  }

  // ─── 학생 삭제
  Future<void> _deleteStudent() async {
    final fs = FirebaseFirestore.instance;

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete this student?'),
            content: const Text(
              'All points and logs will be removed, and paired devices will be unlinked. '
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok != true) return;

    // 로딩
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      useRootNavigator: true,
    );

    try {
      // 1) devices 언링크
      final devSnap =
          await fs
              .collection('hubs/$kHubId/devices')
              .where('studentId', isEqualTo: studentId)
              .get();
      final batch1 = fs.batch();
      for (final d in devSnap.docs) {
        batch1.set(d.reference, {
          'studentId': null,
          'slotIndex': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch1.commit();

      // 2) pointLogs 삭제
      await _deleteCollection(
        fs,
        'hubs/$kHubId/students/$studentId/pointLogs',
        300,
      );

      // 3) student 문서 삭제
      await fs.doc('hubs/$kHubId/students/$studentId').delete();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 로딩 닫기
      _toast('Student deleted.');
      Navigator.maybePop(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 로딩 닫기
      _toast('Delete failed: $e');
    }
  }

  @override
  void dispose() {
    _capSub?.cancel();
    _capTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final stuStream = fs.doc('hubs/$kHubId/students/$studentId').snapshots();

    return AppScaffold(
      // ← 사이드바 포함 레이아웃
      selectedIndex: 1, // 사이드바에서 활성 탭 인덱스
      body: Scaffold(
        backgroundColor: const Color(0xFFF7FAFF),
        body: SafeArea(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: stuStream,
            builder: (_, snap) {
              final name =
                  (snap.data?.data()?['name'] as String?) ?? '(no name)';
              final pts = (snap.data?.data()?['points'] as num?)?.toInt() ?? 0;

              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: LayoutBuilder(
                  builder: (context, box) {
                    const widthBp = 1000.0;
                    const heightBp = 760.0;
                    final isNarrow = box.maxWidth < widthBp || box.maxHeight < heightBp;

                    // 공통: 왼쪽 패널(아바타/매핑/삭제)
                    Widget leftPanel = Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: _avatarW,
                                maxHeight: _avatarH,
                              ),
                              child: const SizedBox(
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
                            ),
                            Positioned(
                              right: 12,
                              top: 12,
                              child: _PointBadge(value: pts),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            name,
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
                              '/profile/student/details',
                              arguments: {'id': studentId},
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
                        _DeviceMappingRow(
                          studentId: studentId,
                          onLink1: () => _captureToSlot('1'),
                          onLink2: () => _captureToSlot('2'),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: IconButton(
                            tooltip: 'Delete student',
                            onPressed: _deleteStudent,
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    );

                    // 공통: 오른쪽(점수 카드) — 그대로 사용
                    final rightPanel = SizedBox(
                      width: 680,
                      child: _ScoreManagementCard(
                        onPick:
                            (id, label, v) => _applyScore(
                              typeId: id,
                              typeName: label,
                              value: v,
                            ),
                      ),
                    );

                    // 좁은 화면: 위아래 배치 + 스크롤
                    if (isNarrow) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                leftPanel,
                                const SizedBox(height: 32),
                                rightPanel,
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // 넓은 화면: 좌우 배치 + 세로 중앙
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Center(
                          child: Row(
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
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 공용: 서브컬렉션 배치 삭제
  Future<void> _deleteCollection(
    FirebaseFirestore fs,
    String path,
    int batchSize,
  ) async {
    Query q = fs.collection(path).limit(batchSize);
    while (true) {
      final snap = await q.get();
      if (snap.docs.isEmpty) break;
      final batch = fs.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) break;
    }
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
        color: Color(0xFF44A0FF), // #44A0FF
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

/// 학생에게 연결된 장치 슬롯 표시 + 매핑 버튼
class _DeviceMappingRow extends StatelessWidget {
  const _DeviceMappingRow({
    required this.studentId,
    required this.onLink1,
    required this.onLink2,
  });

  final String studentId;
  final VoidCallback onLink1;
  final VoidCallback onLink2;

  String _last5(String? id) {
    final s = (id ?? '').replaceAll(RegExp(r'\D'), '');
    if (s.isEmpty) return '';
    return s.length > 5 ? s.substring(s.length - 5) : s;
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          fs
              .collection('hubs/$kHubId/devices')
              .where('studentId', isEqualTo: studentId)
              .snapshots(),
      builder: (_, snap) {
        String? s1, s2;
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final si = d.data()['slotIndex']?.toString();
            if (si == '1') s1 = d.id;
            if (si == '2') s2 = d.id;
          }
        }

        Widget _chip(String? id, VoidCallback onLink) {
          final has = id != null && id.isNotEmpty;

          return SizedBox(
            width: 121,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onLink,
              icon: Icon(
                Icons.link,
                size: 18,
                color: has ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              ),
              label: Text(
                has ? _last5(id) : 'Add',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF868C98),
                  fontSize: 25,
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD2D2D2), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(121, 46),
                maximumSize: const Size(121, 46),
              ),
            ),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [_chip(s1, onLink1), _chip(s2, onLink2)],
        );
      },
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
              SizedBox(height: 12),
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

class _BackButton extends StatelessWidget {
  const _BackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.maybePop(context).then((popped) {
          if (popped == false) {
            Navigator.pushReplacementNamed(context, '/profile');
          }
        });
      },
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
        // 기준 타일 크기(디자인 기준)
        const baseW = 204.0;
        const baseH = 106.0;

        // 실제 타일 크기에 따른 스케일
        final sW = (c.maxWidth / baseW).clamp(0.7, 1.4);
        final sH = (c.maxHeight / baseH).clamp(0.7, 1.4);
        final s = sW < sH ? sW : sH; // 가장 보수적으로

        // 요소 사이즈(스케일 적용)
        final imgSize = (100.0 * s).clamp(56.0, 120.0);
        final emojiSize = (40.0 * s).clamp(22.0, 48.0);
        final labelSize = (24.0 * s).clamp(12.0, 22.0);
        final gap = (12.0 * s).clamp(6.0, 14.0);

        final badgePadH = (8.0 * s).clamp(5.0, 10.0);
        final badgePadV = (4.0 * s).clamp(2.0, 6.0);
        final badgeFont = (13.0 * s).clamp(10.0, 14.0);

        final minusIcon = (24.0 * s).clamp(18.0, 24.0);
        final minusBox = (28.0 * s).clamp(22.0, 32.0);

        return Stack(
          children: [
            // 카드 본문
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10 * s),
                border: Border.all(color: const Color(0xFFD2D2D2)),
              ),
              child: Stack(
                children: [
                  // 점수 항목
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

                  // 점수 이미지
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

                  // 점수 +1
                  Positioned(
                    left: 18 * s,
                    top: 67 * s,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onPlus,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: badgePadH,
                          vertical: badgePadV,
                        ),
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

                  // Quiz 섹션 Detail 버튼
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
