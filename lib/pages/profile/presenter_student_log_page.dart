

// lib/pages/profile/presenter_student_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const String kHubId = 'hub-001';

class ScoreType {
  final String id; // 내부용 키
  final String label; // 표시 이름
  final String emoji; // 이모지
  final int value; // +1, -1 같은 기본값 (양/음수는 onTapMinus에서 바꿔줌)
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
    final stuRef = fs.doc('students/$studentId');
    final logRef = fs.collection('students/$studentId/pointLogs').doc();

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

  // ─── 버튼 매핑(기존 로직 요약 버전)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _capSub;
  Timer? _capTimer;
  bool _capturing = false;

  Future<void> _captureToSlot(String slotIndex) async {
    if (_capturing) return;
    _capturing = true;

    final fs = FirebaseFirestore.instance;
    // 현재 허브의 세션
    final hub = await fs.doc('hubs/$kHubId').get();
    final sid = hub.data()?['currentSessionId'] as String?;
    if (sid == null) {
      _toast('No active session.');
      _capturing = false;
      return;
    }

    final startMs = DateTime.now().millisecondsSinceEpoch;
    String? initTop;
    try {
      final init =
          await fs
              .collection('sessions/$sid/events')
              .orderBy('ts', descending: true)
              .limit(1)
              .get();
      if (init.docs.isNotEmpty) initTop = init.docs.first.id;
    } catch (_) {}

    final ok = await showDialog<bool>(
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

    if (ok == false) {
      _capturing = false;
      return;
    }

    bool handled = false;
    _capSub = fs
        .collection('sessions/$sid/events')
        .orderBy('ts', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) async {
          if (handled || snap.docs.isEmpty) return;
          final d = snap.docs.first;
          if (initTop != null && d.id == initTop) return;

          final data = d.data();
          final devId = (data['deviceId'] as String?)?.trim();
          final ts = (data['ts'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;

          if (devId == null || devId.isEmpty) return;
          if (ts < startMs - 2000) return; // 약간의 버퍼

          handled = true;
          await fs.doc('devices/$devId').set({
            'studentId': studentId,
            'slotIndex': slotIndex,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          if (mounted) Navigator.of(context, rootNavigator: true).pop(true);
          _toast('Linked $devId (slot $slotIndex)');
        });

    _capTimer = Timer(const Duration(seconds: 25), () {
      if (!_capturing || handled) return;
      _toast('Timed out.');
      if (mounted) Navigator.of(context, rootNavigator: true).pop(false);
    });
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
    final stuStream = fs.doc('students/$studentId').snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: stuStream,
          builder: (_, snap) {
            final name = (snap.data?.data()?['name'] as String?) ?? '(no name)';
            final pts = (snap.data?.data()?['points'] as num?)?.toInt() ?? 0;

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  // Header
                  // Header
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () {
                          Navigator.maybePop(context).then((popped) {
                            if (popped == false) {
                              Navigator.pushReplacementNamed(
                                context,
                                '/profile',
                              );
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),

                      const Spacer(),
                      SizedBox(
                        width: 280,
                        child: TextField(
                          decoration: InputDecoration(
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            hintText: 'Search Tools',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Main
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Avatar + name + mapping
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // avatar block
                              Stack(
                                children: [
                                  Container(
                                    width: 360,
                                    height: 360,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF6FAFF),
                                    ),
                                    alignment: Alignment.center,
                                    child: Image.asset(
                                      'assets/logo_bird.png', // 자리 이미지
                                      width: 1200,
                                      fit: BoxFit.contain,
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
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // device mapping row
                              _DeviceMappingRow(
                                studentId: studentId,
                                onLink1: () => _captureToSlot('1'),
                                onLink2: () => _captureToSlot('2'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 24),

                        // Right: Score Management
                        Expanded(
                          flex: 5,
                          child: _ScoreManagementCard(
                            onPick:
                                (typeId, typeName, value) => _applyScore(
                                  typeId: typeId,
                                  typeName: typeName,
                                  value: value,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF60A5FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
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
              .collection('devices')
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

        Chip _chip(String label, String? id, VoidCallback onLink) {
          final has = id != null && id.isNotEmpty;
          final last = _last5(id);
          return Chip(
            avatar: const Icon(Icons.link, size: 16),
            label: Text(has ? last : label),
            side: BorderSide(color: has ? Colors.black : Colors.black26),
            backgroundColor: Colors.white,
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.link, size: 16),
              label: Text(s1 == null ? 'Link Slot 1' : 'S1 • ${_last5(s1)}'),
              onPressed: onLink1,
            ),
            ActionChip(
              avatar: const Icon(Icons.link, size: 16),
              label: Text(s2 == null ? 'Link Slot 2' : 'S2 • ${_last5(s2)}'),
              onPressed: onLink2,
            ),
          ],
        );
      },
    );
  }
}

class _ScoreManagementCard extends StatelessWidget {
  const _ScoreManagementCard({required this.onPick});
  final void Function(String typeId, String typeName, int value) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Score Management',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0B1B33),
          ),
        ),
        const SizedBox(height: 12),

        // 카드 컨테이너
        Expanded(
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, box) {
                  // 반응형 컬럼 수 계산
                  final w = box.maxWidth;
                  int cols = (w / 240).floor(); // 타일 가로폭 기준치 (~240px)
                  cols = cols.clamp(2, 4);

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('Attitude Score'),
                        const SizedBox(height: 8),
                        _ScoreSectionGrid(
                          columns: cols,
                          types: kAttitudeTypes,
                          onPick: onPick,
                        ),
                        const SizedBox(height: 20),

                        const _SectionTitle('Activity Score'),
                        const SizedBox(height: 8),
                        _ScoreSectionGrid(
                          columns: cols,
                          types: kActivityTypes,
                          onPick: onPick,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
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
  });

  final int columns;
  final List<ScoreType> types;
  final void Function(String id, String name, int value) onPick;

  @override
  Widget build(BuildContext context) {
    // 마지막에 “Add Skill” 타일 하나 추가
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
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1, // 정사각 느낌
      ),
      itemBuilder: (_, i) {
        final t = items[i];
        if (t.id == '_add') {
          return _AddSkillTile(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('스킬 추가는 곧 제공됩니다 😊')),
              );
            },
          );
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
        // 카드 본문
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 6),
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 10),
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
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  tooltip: '-1',
                  onPressed: onMinus,
                  icon: const Icon(Icons.remove_circle_outline),
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  iconSize: 20,
                ),
              ),
            ],
          ),
        ),
        // +1 배지 (우상단 고정)
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
      ],
    );
  }
}

class _AddSkillTile extends StatelessWidget {
  const _AddSkillTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xE0E3EAF5)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.add_circle_outline,
                size: 42,
                color: Color(0xFF6C58F6),
              ),
              SizedBox(height: 8),
              Text(
                '스킬 추가',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6C58F6),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
