// lib/pages/tools/display_random_seat_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';

// ===== 출석(프레젠터)와 동일한 디자인 상수 =====
const _kAppBg = Color(0xFFF6FAFF);
const _kCardW = 1011.0;
const _kCardH = 544.0;
const _kCardRadius = 10.0;
const _kCardBorder = Color(0xFFD2D2D2);

const _kAttendedBlue = Color(0xFFCEE6FF);
const _kDashedGrey = Color(0xFFCBD5E1);
const _kTextDark = Color(0xFF0B1324);
const _kTextNum = Color(0xFF1F2937);

class DisplayRandomSeatPage extends StatelessWidget {
  const DisplayRandomSeatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final hubId = context.watch<HubProvider>().hubId;

    if (hubId == null || hubId.isEmpty) {
      return const Scaffold(backgroundColor: _kAppBg, body: _WaitingSeatScreen());
    }

    // 허브의 현재 세션 구독
    final hubStream = fs.doc('hubs/$hubId').snapshots();

    return Scaffold(
      backgroundColor: _kAppBg,
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

            // 세션/좌석/학생 동시 구독
            final sessionDocStream =
                fs.doc('hubs/$hubId/sessions/$sid').snapshots(); // rows/cols
            final seatMapStream =
                fs.collection('hubs/$hubId/sessions/$sid/seatMap').snapshots();
            final studentsStream =
                fs.collection('hubs/$hubId/students').snapshots();

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: sessionDocStream,
              builder: (context, sessSnap) {
                final meta = sessSnap.data?.data();
                final int cols = (meta?['cols'] as num?)?.toInt() ?? 6;
                final int rows = (meta?['rows'] as num?)?.toInt() ?? 4;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: seatMapStream,
                  builder: (context, seatSnap) {
                    final Map<String, String?> seatMap = {};
                    if (seatSnap.data != null) {
                      for (final d in seatSnap.data!.docs) {
                        seatMap[d.id] =
                            (d.data()['studentId'] as String?)?.trim();
                      }
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: studentsStream,
                      builder: (context, stuSnap) {
                        final Map<String, String> nameOf = {};
                        if (stuSnap.data != null) {
                          for (final d in stuSnap.data!.docs) {
                            final x = d.data();
                            final n = (x['name'] as String?)?.trim();
                            if (n != null && n.isNotEmpty) nameOf[d.id] = n;
                          }
                        }

                        // === 출석페이지와 동일 스케일 래퍼(1280×720) ===
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
                              child: _DesignSurfaceDisplay(
                                cols: cols,
                                rows: rows,
                                seatMap: seatMap,
                                nameOf: nameOf,
                              ),
                            );

                            if (scaleFit < 1) {
                              // 작아지면 축소 없이 잘라내기(프레젠터와 동일)
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
                            // 커지면 확대
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

/* ============== 디자인 내부(1280×720) ============== */

class _DesignSurfaceDisplay extends StatelessWidget {
  const _DesignSurfaceDisplay({
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
              // Board 바 (프레젠터 동일)
              SizedBox(
                width: double.infinity,
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
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        textAlign: TextAlign.center,
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
              const SizedBox(height: 18),

              // 좌석 그리드(출석페이지와 동일한 계산식)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    const crossSpacing = 24.0;
                    const mainSpacing = 24.0;

                    final gridW = c.maxWidth;
                    final gridH = c.maxHeight - 2; // 동일 여유
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
                        final seatNo = _seatKey(index);
                        final sid = seatMap[seatNo]?.trim();
                        final hasStudent = sid != null && sid.isNotEmpty;
                        final name =
                            hasStudent ? (nameOf[sid!] ?? sid) : null;

                        return _SeatTileLikePresenter(
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

/* ---------- 타일: 프레젠터 스타일 ---------- */

class _SeatTileLikePresenter extends StatelessWidget {
  const _SeatTileLikePresenter({
    required this.index,
    required this.hasStudent,
    required this.name,
  });

  final int index;
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

        final fillColor = hasStudent ? _kAttendedBlue : Colors.white;
        final isDark = fillColor.computeLuminance() < 0.5;
        final nameColor = isDark ? Colors.white : _kTextDark;
        final seatNoColor = isDark ? Colors.white70 : _kTextNum;

        final inner = Container(
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

        if (hasStudent) return inner;

        // empty → 점선
        return CustomPaint(
          foregroundPainter: _DashedBorderPainter(
            radius: radius + 4,
            color: _kDashedGrey,
            strokeWidth: (2.0 * s).clamp(1.2, 3.0),
            dash: (8.0 * s).clamp(5.0, 12.0),
            gap: (6.0 * s).clamp(3.0, 10.0),
          ),
          child: inner,
        );
      },
    );
  }
}

/* --------------------- Waiting Screen ---------------------- */

class _WaitingSeatScreen extends StatelessWidget {
  const _WaitingSeatScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kAppBg,
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

/* --------------- dashed border painter(공통) --------------- */

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
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
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