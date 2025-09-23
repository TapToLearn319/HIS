// lib/pages/tools/random_seat_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Providers
import '../../provider/session_provider.dart';
import '../../provider/seat_map_provider.dart';
import '../../provider/students_provider.dart';

const _kAppBg = Color(0xFFF6FAFF);

// ===== 출석페이지와 동일한 카드/스타일 상수 =====
const _kCardW = 1011.0;
const _kCardH = 544.0;
const _kCardRadius = 10.0;
const _kCardBorder = Color(0xFFD2D2D2);

const _kAttendedBlue = Color(0xFFCEE6FF);
const _kAssignedDashed = Color(0xFFCBD5E1);
const _kTextDark = Color(0xFF0B1324);
const _kTextNum = Color(0xFF1F2937);

const String kHubId = 'hub-001';

class RandomSeatPage extends StatefulWidget {
  const RandomSeatPage({super.key});
  @override
  State<RandomSeatPage> createState() => _RandomSeatPageState();
}

class _RandomSeatPageState extends State<RandomSeatPage> {
  String? _lastBoundSid;
  bool _working = false;

  String _seatKey(int index) => '${index + 1}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBind());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureBind();
  }

  Future<void> _ensureBind() async {
    if (!mounted) return;
    final session = context.read<SessionProvider>();
    final seatMap = context.read<SeatMapProvider>();
    final sid = session.sessionId;

    if (sid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBind());
      return;
    }
    if (_lastBoundSid == sid) return;

    try {
      await seatMap.bindSession(sid);
      _lastBoundSid = sid;
      await FirebaseFirestore.instance.doc('hubs/$kHubId').set(
        {'currentSessionId': sid, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBind());
    }
  }

  // 랜덤 섞기(Empty 제외, 중복 없이) - 출석페이지와 같은 hub/sessions 경로로 일괄 갱신
Future<void> _randomize() async {
  if (_working) return;
  setState(() => _working = true);

  try {
    final fs = FirebaseFirestore.instance;
    final sid = context.read<SessionProvider>().sessionId;
    if (sid == null) {
      _snack('세션이 없습니다.');
      return;
    }

    // 1) 현재 seatMap 읽기 (hubs/{hubId}/sessions/{sid}/seatMap)
    final seatCol = fs.collection('hubs/$kHubId/sessions/$sid/seatMap');
    final snap = await seatCol.get();

    // 좌석번호 오름차순으로 정렬(1..N)
    final docs = [...snap.docs]..sort((a, b) {
      int ai = int.tryParse(a.id) ?? 0;
      int bi = int.tryParse(b.id) ?? 0;
      return ai.compareTo(bi);
    });

    // 배정된 좌석 목록 & 학생ID 집합(중복 제거)
    final assignedSeatNos = <String>[];
    final assignedStudentSet = <String>{};
    for (final d in docs) {
      final sid = (d.data()['studentId'] as String?)?.trim();
      if (sid != null && sid.isNotEmpty) {
        assignedSeatNos.add(d.id);
        assignedStudentSet.add(sid);
      }
    }

    if (assignedStudentSet.isEmpty) {
      _snack('배정된 학생이 없습니다.');
      return;
    }

    // 2) 셔플
    final shuffled = assignedStudentSet.toList()..shuffle(Random());

    // 3) 배치로 일괄 반영 (중복 없이 1:1 매핑, 남는 좌석은 비우기)
    final batch = fs.batch();
    for (int i = 0; i < assignedSeatNos.length; i++) {
      final seatNo = assignedSeatNos[i];
      final newSid = (i < shuffled.length) ? shuffled[i] : null;
      batch.set(
        seatCol.doc(seatNo),
        {'studentId': newSid},
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    // 4) 허브 currentSessionId 최신화(옵션)
    await fs.doc('hubs/$kHubId').set(
      {'currentSessionId': sid, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    _snack('MIX 완료!');
  } catch (e) {
    _snack('MIX 실패: $e');
  } finally {
    if (mounted) setState(() => _working = false);
  }
}

  // 현재 좌석을 새 세션으로 저장
  Future<void> _saveAsNewSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('저장'),
        content: const Text('현재 좌석 배치를 새로운 세션으로 저장하고 전환합니다.'),
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

      final newSid = _defaultSessionId();
      final fs = FirebaseFirestore.instance;

      await fs.doc('sessions/$newSid').set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'note': 'random seat saved from ${oldSid ?? "(unknown)"}',
      }, SetOptions(merge: true));

      final batch = fs.batch();
      seatMap.forEach((seatNo, studentId) {
        final ref = fs.doc('sessions/$newSid/seatMap/$seatNo');
        batch.set(ref, {'studentId': studentId});
      });
      await batch.commit();

      session.setSession(newSid);
      _lastBoundSid = null;
      await context.read<SeatMapProvider>().bindSession(newSid);

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

  @override
Widget build(BuildContext context) {
  final seatMapProvider = context.watch<SeatMapProvider>();
  final studentsProvider = context.watch<StudentsProvider>();
  final seatMap = seatMapProvider.seatMap;
  final fs = FirebaseFirestore.instance;
  final sid = context.watch<SessionProvider>().sessionId;

  return Scaffold(
    backgroundColor: _kAppBg,
    appBar: AppBar(title: const Text('Random Seat')),
    body: Stack(
      children: [
        // === 세션 메타(rows/cols) 구독 ===
        if (sid == null)
          const Center(child: Text('세션이 없습니다.'))
        else
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: fs.doc('hubs/$kHubId/sessions/$sid').snapshots(),
            builder: (context, sessSnap) {
              final meta = sessSnap.data?.data();
              final int cols = (meta?['cols'] as num?)?.toInt() ?? 6;
              final int rows = (meta?['rows'] as num?)?.toInt() ?? 4;

              // === 출석페이지와 동일한 1280×720 스케일/클리핑 래퍼 ===
              return LayoutBuilder(
                builder: (context, box) {
                  const designW = 1280.0;
                  const designH = 720.0;
                  final scaleW = box.maxWidth / designW;
                  final scaleH = box.maxHeight / designH;
                  final scaleFit = scaleW < scaleH ? scaleW : scaleH;

                  final child = SizedBox(
                    width: designW,
                    height: designH,
                    child: _DesignSurfaceRandom(
                      seatMap: seatMap,
                      studentsProvider: studentsProvider,
                      cols: cols,
                      rows: rows,
                      onMix: _randomize,
                    ),
                  );

                  if (scaleFit < 1) {
                    // 더 작아지면 축소 없이 잘라내기
                    return ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        minWidth: 0,
                        minHeight: 0,
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        child: child,
                      ),
                    );
                  }
                  // 더 크면 확대
                  return ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.center,
                      minWidth: 0,
                      minHeight: 0,
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Transform.scale(
                        scale: scaleFit,
                        alignment: Alignment.center,
                        child: child,
                      ),
                    ),
                  );
                },
              );
            },
          ),

        // 우측 하단: SAVE 그대로
        _SaveFabImage(onTap: _saveAsNewSession),

        if (_working)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    ),
  );
}
}

class _DesignSurfaceRandom extends StatelessWidget {
  const _DesignSurfaceRandom({
    required this.seatMap,
    required this.studentsProvider,
    required this.cols,
    required this.rows,
    required this.onMix,
  });

  final Map<String, String?> seatMap;
  final StudentsProvider studentsProvider;
  final int cols;
  final int rows;
  final VoidCallback onMix;

  String _seatKey(int index) => '${index + 1}';

  @override
  Widget build(BuildContext context) {
    final assignedCount =
        seatMap.values.where((v) => (v?.trim().isNotEmpty ?? false)).length;

    return Center(
      child: SizedBox(
        width: _kCardW,
        height: _kCardH,
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: _kCardBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== 헤더: 좌(총원/배치정보) • 중(Board) • 우(MIX) =====
              Row(
                children: [
                  // 좌측 정보
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total $assignedCount',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('$cols column / $rows row',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // 가운데 Board 바
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFD3FF6E),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Board',
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 우측 MIX 버튼(상단으로 이동, 파스텔 핑크)
                  TextButton.icon(
                    onPressed: onMix,
                    icon: const Icon(Icons.shuffle, size: 18, color: Color(0xFFE35BFF)),
                    label: const Text('MIX',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE35BFF))),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      backgroundColor: const Color(0xFFFFECFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ===== 좌석 그리드 (출석페이지와 동일 계산) =====
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    const crossSpacing = 24.0;
                    const mainSpacing = 24.0;

                    final gridW = c.maxWidth;
                    final gridH = c.maxHeight - 2;
                    final tileW = (gridW - crossSpacing * (cols - 1)) / cols;
                    final tileH = (gridH - mainSpacing * (rows - 1)) / rows;
                    final ratio = (tileW / tileH).isFinite ? tileW / tileH : 1.0;

                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cols * rows,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: crossSpacing,
                        mainAxisSpacing: mainSpacing,
                        childAspectRatio: ratio,
                      ),
                      itemBuilder: (context, index) {
                        final key = _seatKey(index);
                        final sid = seatMap[key]?.trim();
                        final hasStudent = sid != null && sid.isNotEmpty;
                        final name = hasStudent
                            ? studentsProvider.displayName(sid!)
                            : null;

                        return _SeatTileLikeHome(
                          index: index,
                          hasStudent: hasStudent,
                          name: name,
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
    );
  }
}

/* ========== 타일(출석페이지 룩&사이즈) ========== */
class _SeatTileLikeHome extends StatelessWidget {
  const _SeatTileLikeHome({
    required this.index,
    required this.hasStudent,
    required this.name,
  });

  final int index; // 0-based
  final bool hasStudent;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cc) {
        const baseH = 76.0;
        final s = (cc.maxHeight / baseH).clamp(0.6, 2.2);

        final radius = 12.0 * s;
        final padH = (6.0 * s).clamp(2.0, 10.0);
        final padV = (4.0 * s).clamp(1.0, 8.0);
        final fsSeat = (12.0 * s).clamp(9.0, 16.0);
        final fsName = (14.0 * s).clamp(10.0, 18.0);
        final gap = (2.0 * s).clamp(1.0, 8.0);

        final Color fillColor = hasStudent ? _kAttendedBlue : Colors.white;
        final isDark = fillColor.computeLuminance() < 0.5;
        final nameColor = isDark ? Colors.white : _kTextDark;
        final seatNoColor = isDark ? Colors.white70 : _kTextNum;

        final box = Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(radius),
            border: hasStudent ? Border.all(color: Colors.transparent) : null,
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: hasStudent
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${index + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fsSeat,
                          height: 1.0,
                          color: seatNoColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: gap),
                      Text(
                        name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fsName,
                          height: 1.0,
                          color: nameColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        );

        if (hasStudent) return box;

        return CustomPaint(
          foregroundPainter: _DashedBorderPainter(
            radius: radius + 4,
            color: _kAssignedDashed,
            strokeWidth: (2.0 * s).clamp(1.2, 3.0),
            dash: (8.0 * s).clamp(5.0, 12.0),
            gap: (6.0 * s).clamp(3.0, 10.0),
          ),
          child: box,
        );
      },
    );
  }
}

/* ---------- dashed painter (출석페이지 동일) ---------- */
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
        final len = distance + dash > metric.length
            ? metric.length - distance
            : dash;
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) {
    return radius != old.radius ||
        strokeWidth != old.strokeWidth ||
        dash != old.dash ||
        gap != old.gap ||
        color != old.color;
  }
}

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
                      Icons.save_alt, size: 64, color: Colors.indigo),
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