// lib/pages/profile/presenter_student_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../sidebar_menu.dart';

const String kHubId = 'hub-001';

const double _avatarW = 290;
const double _avatarH = 268;

const double _imgSize  = 180;
const double _gap      = 12;
const double _emojiSz  = 40;
const double _labelSz  = 24;

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
    final logRef = fs.collection('hubs/$kHubId/students/$studentId/pointLogs').doc();

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

  bool handled = false;
  bool dialogOpen = true;
  bool skippedInitial = false; // ✅ 첫 스냅샷 무시

  _capSub = liveCol.snapshots().listen((snap) async {
    if (!skippedInitial) {
      skippedInitial = true;
      debugPrint('[pair] initial snapshot: ${snap.docs.length} docs (ignored)');
      return;
    }
    if (handled) return;
    if (snap.docChanges.isEmpty) return;

    for (final ch in snap.docChanges) {
      if (ch.type == DocumentChangeType.removed) continue;
      if (ch.doc.metadata.hasPendingWrites) continue;

      final devId = ch.doc.id;
      handled = true;

      try {
        await fs.doc('devices/$devId').set({
          'studentId': studentId,
          'slotIndex': slotIndex,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) _toast('Linked $devId (slot $slotIndex)');
      } catch (e) {
        if (mounted) _toast('Register failed: $e');
      } finally {
        _capSub?.cancel(); _capSub = null;
        _capTimer?.cancel(); _capTimer = null;
        _capturing = false;

        if (mounted && dialogOpen) {
          try { Navigator.of(context, rootNavigator: true).pop(true); } catch (_) {}
        }
      }
      break;
    }
  }, onError: (e, st) {
    if (mounted) _toast('Pairing stream error: $e');
  });

  final waitFuture = showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
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
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      ],
    ),
  );

  _capTimer = Timer(const Duration(seconds: 25), () {
    if (handled) return;
    if (mounted && dialogOpen) {
      try { Navigator.of(context, rootNavigator: true).pop(false); } catch (_) {}
    }
  });

  final res = await waitFuture;
  dialogOpen = false;

  if (!handled) {
    _capSub?.cancel(); _capSub = null;
    _capTimer?.cancel(); _capTimer = null;
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
      builder: (_) => AlertDialog(
        title: const Text('Delete this student?'),
        content: const Text(
          'All points and logs will be removed, and paired devices will be unlinked. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
      final devSnap = await fs.collection('devices')
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
      await _deleteCollection(fs, 'hubs/$kHubId/students/$studentId/pointLogs', 300);

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
                child: Column(
                  children: [
                    // ── Header
                    Row(children: [const Spacer()]),
                    const SizedBox(height: 24),

                    // ── Main (좌: 아바타/버튼매핑, 우: 점수 카드)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 좌측 영역
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
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
                                    Positioned(
                                      right: 12,
                                      top: 12,
                                      child: _PointBadge(value: pts),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: 218,
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

                                const SizedBox(height: 66),

                                // 버튼 연결 UI
                                _DeviceMappingRow(
                                  studentId: studentId,
                                  onLink1: () => _captureToSlot('1'),
                                  onLink2: () => _captureToSlot('2'),
                                ),

                                const SizedBox(height: 16),

                                // ⬇️ 학생 삭제 버튼 (가운데, 빨간 휴지통)
                                Center(
                                  child: IconButton(
                                    tooltip: 'Delete student',
                                    onPressed: _deleteStudent,
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // 우측 영역
                          Expanded(
                            flex: 5,
                            child: _ScoreManagementCard(
                              onPick: (id, label, v) => _applyScore(
                                typeId: id,
                                typeName: label,
                                value: v,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
      stream: fs.collection('devices').where('studentId', isEqualTo: studentId).snapshots(),
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

        final isVoting = t.id == 'voting';
        final badge = isVoting ? '+N' : '+${t.value.abs()}';

        return _ScoreTileMini(
          emoji: t.emoji,
          label: t.label,
          asset: t.asset,
          badgeText: badge,
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
        // 카드 본문
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
                SizedBox(
  width: _imgSize,
  height: _imgSize,
  child: asset != null
      ? Image.asset(asset!, fit: BoxFit.contain)
      : Center(child: Text(emoji, style: const TextStyle(fontSize: _emojiSz))),
),
const SizedBox(height: _gap),
Text(
  label,
  maxLines: 2,
  textAlign: TextAlign.center,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(
    fontSize: _labelSz,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1F2A44),
    height: 1.2, // 살짝 키움
  ),
                ),
              ],
            ),
          ),
        ),

        // +1 배지 (우상단)
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
                style: TextStyle(
                  color: Color(0xFF128C4A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),

        // -1 버튼 (우하단)
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
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('스킬 추가는 곧 제공됩니다 😊')));
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD2D2D2), width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
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
