// lib/pages/tools/random_seat_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Providers
import '../../provider/session_provider.dart';
import '../../provider/seat_map_provider.dart';
import '../../provider/students_provider.dart';

const String kHubId = 'hub-001';

class RandomSeatPage extends StatefulWidget {
  const RandomSeatPage({super.key});

  @override
  State<RandomSeatPage> createState() => _RandomSeatPageState();
}

class _RandomSeatPageState extends State<RandomSeatPage> {
  String? _lastBoundSid; // 현재 페이지에서 마지막으로 bind한 세션ID (중복 바인딩 방지)
  bool _working = false;

  // 좌석 키: "1".."24"
  String _seatKey(int index) => '${index + 1}';

  @override
  void initState() {
    super.initState();
    // 첫 프레임 이후에 현재 세션으로 seatMap 구독 시도
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBind());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider 트리 갱신 타이밍에 한 번 더 보장
    _ensureBind();
  }

  Future<void> _ensureBind() async {
    if (!mounted) return;
    final session = context.read<SessionProvider>();
    final seatMap = context.read<SeatMapProvider>();
    final sid = session.sessionId;

    // 세션이 아직 없으면 잠깐 대기 (Tools에서 곧 설정되므로 다음 프레임에서 한 번 더 시도)
    if (sid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBind());
      return;
    }

    if (_lastBoundSid == sid) return; // 이미 바인딩한 세션이면 패스

    try {
      await seatMap.bindSession(sid);
      _lastBoundSid = sid;
      // hub도 최신 세션으로 동기화(옵션)
      await FirebaseFirestore.instance.doc('hubs/$kHubId').set(
        {'currentSessionId': sid, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {
      // 바인딩 실패시에도 다음 프레임 재시도 (일시적인 순서 문제 대비)
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBind());
    }
  }

  // 랜덤 섞기 (Empty 제외, 중복 없이)
  Future<void> _randomize() async {
    final seatMapProvider = context.read<SeatMapProvider>();
    final seatMap = seatMapProvider.seatMap;
    final seats = List.generate(24, (i) => _seatKey(i));

    // 현재 좌석에 배정된 학생만 (중복 제거)
    final assignedSet = <String>{};
    final assignedSeatKeys = <String>[];
    for (final s in seats) {
      final sid = seatMap[s];
      if (sid != null && sid.trim().isNotEmpty) {
        assignedSeatKeys.add(s);           // 배정되어 있던 좌석 목록
        assignedSet.add(sid.trim());       // 학생 ID (중복 제거)
      }
    }
    final assigned = assignedSet.toList();
    if (assigned.isEmpty) {
      _snack('배정된 학생이 없습니다.');
      return;
    }

    // 랜덤 셔플
    assigned.shuffle(Random());

    // 배정되어 있던 좌석들만 다시 채우되, 중복 없이
    int idx = 0;
    for (final seatNo in assignedSeatKeys) {
      final newSid = (idx < assigned.length) ? assigned[idx++] : null;
      await seatMapProvider.assignSeat(seatNo, newSid); // 리스트 소진 시 Empty로
    }
  }

  // 저장: 현재 좌석 상태로 새 세션을 만들고, 그 세션을 현재세션으로 전환
  Future<void> _saveAsNewSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('저장'),
        content: const Text('정말 저장하시겠습니까? 현재 좌석 배치를 새로운 세션으로 저장하고 전환합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('저장')),
        ],
      ),
    );
    if (ok != true) return;

    if (_working) return;
    setState(() => _working = true);

    try {
      final session = context.read<SessionProvider>();
      final oldSid = session.sessionId;
      final seatMap = context.read<SeatMapProvider>().seatMap;

      // 새 세션 ID
      final newSid = _defaultSessionId();

      final fs = FirebaseFirestore.instance;

      // 새 세션 문서
      await fs.doc('sessions/$newSid').set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'note': 'random seat saved from ${oldSid ?? "(unknown)"}',
      }, SetOptions(merge: true));

      // 좌석 맵 복사
      final batch = fs.batch();
      seatMap.forEach((seatNo, studentId) {
        final ref = fs.doc('sessions/$newSid/seatMap/$seatNo');
        batch.set(ref, {'studentId': studentId});
      });
      await batch.commit();

      // 현재 세션 전환 + SeatMapProvider 바인딩
      session.setSession(newSid);
      _lastBoundSid = null; // 새 세션으로 다시 bind 시도
      await context.read<SeatMapProvider>().bindSession(newSid);

      // hub도 동기화
      await fs.doc('hubs/$kHubId').set(
        {'currentSessionId': newSid, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      _snack('저장 완료: $newSid');
    } catch (e) {
      _snack('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _defaultSessionId() {
    final now = DateTime.now();
    return '${now.toIso8601String().substring(0, 10)}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    (m ?? ScaffoldMessenger.of(context))
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // 상단 Board 표시 (단독)
  Widget _boardHeader(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFCCFF88),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Board',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seatMapProvider = context.watch<SeatMapProvider>();
    final studentsProvider = context.watch<StudentsProvider>();
    final seatMap = seatMapProvider.seatMap; // 실시간 구독

    return Scaffold(
      appBar: AppBar(
        title: const Text('Random Seat'),
        // actions 없음 (요청사항 반영)
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _boardHeader(context),
                const SizedBox(height: 12),
                // 홈페이지 스타일의 좌석 그리드 (empty=점선 / 배정=실선+연파/ index + name)
                Expanded(
                  child: GridView.builder(
                    itemCount: 24,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6, // 6 columns
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.8, // 4 rows 총 24개
                    ),
                    itemBuilder: (context, index) {
                      final key = _seatKey(index);
                      final sid = seatMap[key]?.trim();
                      final hasStudent = sid != null && sid.isNotEmpty;
                      final name = hasStudent ? studentsProvider.displayName(sid!) : null;

                      final Color fillColor = hasStudent
                          ? const Color(0xFFE6F0FF)
                          : Colors.white;

                      final Border? solidBorder = hasStudent
                          ? Border.all(color: const Color(0xFF8DB3FF), width: 1.2)
                          : null;

                      final content = Container(
                        decoration: BoxDecoration(
                          color: fillColor,
                          borderRadius: BorderRadius.circular(12),
                          border: solidBorder,
                        ),
                        alignment: Alignment.center,
                        child: hasStudent
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1F2937),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    name!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0B1324),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'empty',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      );

                      final showDashed = !hasStudent;

                      return showDashed
                          ? CustomPaint(
                              foregroundPainter: _DashedBorderPainter(
                                radius: 12,
                                color: const Color(0xFFCBD5E1),
                                strokeWidth: 1.4,
                                dash: 6,
                                gap: 5,
                              ),
                              child: content,
                            )
                          : content;
                    },
                  ),
                ),
              ],
            ),
          ),

          // 좌측 하단: Mix 이미지 FAB
          _MixFabImage(onTap: _randomize),

          // 우측 하단: Save 이미지 FAB
          _SaveFabImage(onTap: _saveAsNewSession),

          if (_working)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ---------- Mix FAB 이미지 위젯 (왼쪽 아래) ---------- */
class _MixFabImage extends StatelessWidget {
  final VoidCallback onTap;
  const _MixFabImage({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      bottom: 20,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: 200,
          height: 200,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              hoverColor: Colors.black.withOpacity(0.05),
              splashColor: Colors.black.withOpacity(0.1),
              onTap: onTap,
              child: Tooltip(
                message: 'Mix seats',
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Image.asset(
                    'assets/logo_bird_mix.png', // 원하는 이미지 경로 (없으면 아이콘으로 대체)
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.shuffle,
                      size: 64,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------- Save FAB 이미지 위젯 (오른쪽 아래) ---------- */
class _SaveFabImage extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveFabImage({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: 200,
          height: 200,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              hoverColor: Colors.black.withOpacity(0.05),
              splashColor: Colors.black.withOpacity(0.1),
              onTap: onTap,
              child: Tooltip(
                message: 'Save seat layout',
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Image.asset(
                    'assets/logo_bird_save.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.save_alt,
                      size: 64,
                      color: Colors.indigo,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------- dashed border painter (홈과 동일) ---------- */
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.radius,
    required this.color,
    this.strokeWidth = 1.0,
    this.dash = 6.0,
    this.gap = 4.0,
  });

  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = distance + dash > metric.length
            ? metric.length - distance
            : dash;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth ||
        dash != oldDelegate.dash ||
        gap != oldDelegate.gap ||
        color != oldDelegate.color;
  }
}
