// lib/pages/tools/display_random_seat_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String kHubId = 'hub-001';

class DisplayRandomSeatPage extends StatelessWidget {
  const DisplayRandomSeatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    // 1) 허브의 현재 세션 구독
    final hubStream = fs.doc('hubs/$kHubId').snapshots();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: hubStream,
          builder: (context, hubSnap) {
            if (hubSnap.connectionState == ConnectionState.waiting) {
              return const _WaitingSeatScreen();
            }
            final hub = hubSnap.data?.data();
            final sid = hub?['currentSessionId'] as String?;
            if (sid == null || sid.isEmpty) {
              return const _WaitingSeatScreen();
            }

            // 2) 세션 메타(행/열) + 좌석맵 + 학생목록 동시 구독(중첩)
            final sessionDocStream =
                fs.doc('sessions/$sid').snapshots(); // rows/cols(optional)
            final seatMapStream =
                fs.collection('sessions/$sid/seatMap').snapshots();
            final studentsStream = fs.collection('students').snapshots();

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: sessionDocStream,
              builder: (context, sessSnap) {
                final meta = sessSnap.data?.data();
                final int cols = (meta?['cols'] as num?)?.toInt() ?? 6;
                final int rows = (meta?['rows'] as num?)?.toInt() ?? 4;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: seatMapStream,
                  builder: (context, seatSnap) {
                    // seatNo -> studentId
                    final Map<String, String?> seatMap = {};
                    if (seatSnap.data != null) {
                      for (final d in seatSnap.data!.docs) {
                        seatMap[d.id] = (d.data()['studentId'] as String?)
                            ?.trim();
                      }
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: studentsStream,
                      builder: (context, stuSnap) {
                        // studentId -> name
                        final Map<String, String> nameOf = {};
                        if (stuSnap.data != null) {
                          for (final d in stuSnap.data!.docs) {
                            final x = d.data();
                            final n = (x['name'] as String?)?.trim();
                            if (n != null && n.isNotEmpty) {
                              nameOf[d.id] = n;
                            }
                          }
                        }

                        return _SeatBoard(
                          cols: cols,
                          rows: rows,
                          seatMap: seatMap,
                          nameOf: nameOf,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/* ------------------------ Seat Board ------------------------ */

class _SeatBoard extends StatelessWidget {
  const _SeatBoard({
    required this.cols,
    required this.rows,
    required this.seatMap,
    required this.nameOf,
  });

  final int cols;
  final int rows;
  final Map<String, String?> seatMap; // seatNo -> studentId?
  final Map<String, String> nameOf;   // studentId -> name

  String _seatKey(int index) => '${index + 1}';

  @override
  Widget build(BuildContext context) {
    final seatCount = cols * rows;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          _boardHeader(context),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                // 스크롤 없이 꽉 차게: 타일 비율 역산
                const crossSpacing = 16.0;
                const mainSpacing = 16.0;
                final gridW = c.maxWidth;
                final gridH = c.maxHeight;
                final tileW = (gridW - crossSpacing * (cols - 1)) / cols;
                final tileH = (gridH - mainSpacing * (rows - 1)) / rows;
                final ratio = (tileW / tileH).isFinite ? tileW / tileH : 1.0;

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: seatCount,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: crossSpacing,
                    mainAxisSpacing: mainSpacing,
                    childAspectRatio: ratio,
                  ),
                  itemBuilder: (context, index) {
                    final seatNo = _seatKey(index);
                    final studentId = seatMap[seatNo];
                    final hasStudent =
                        studentId != null && studentId.trim().isNotEmpty;
                    final name = hasStudent
                        ? (nameOf[studentId!.trim()] ?? studentId)
                        : null;

                    final Color fillColor =
                        hasStudent ? const Color(0xFFE6F0FF) : Colors.white;

                    final Border? solidBorder = hasStudent
                        ? Border.all(
                            color: const Color(0xFF8DB3FF), width: 1.2)
                        : null;

                    final child = Container(
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
                                  seatNo,
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

                    if (hasStudent) return child;

                    // empty → 점선 테두리
                    return CustomPaint(
                      foregroundPainter: _DashedBorderPainter(
                        radius: 12,
                        color: const Color(0xFFCBD5E1),
                        strokeWidth: 1.4,
                        dash: 6,
                        gap: 5,
                      ),
                      child: child,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _boardHeader(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    return Container(
      width: (screenW * 0.60).clamp(320.0, 720.0),
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
}

/* --------------------- Waiting Screen ---------------------- */

class _WaitingSeatScreen extends StatelessWidget {
  const _WaitingSeatScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 246, 250, 255),
      width: double.infinity,
      height: double.infinity,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_seat, size: 100, color: Colors.black38),
            SizedBox(height: 20),
            Text(
              '세션을 준비 중입니다…',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------- dashed border painter (공통) --------------- */

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
        final double len =
            distance + dash > metric.length ? metric.length - distance : dash;
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
