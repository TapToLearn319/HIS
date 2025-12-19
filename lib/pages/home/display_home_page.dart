import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';

const _kAppBg = Color(0xFFF6FAFF);
const _kCardW = 1011.0;
const _kCardH = 544.0;
const _kCardRadius = 10.0;
const _kCardBorder = Color(0xFFD2D2D2);

const _kDateFontSize = 16.0;
const _kDateLineHeight = 34.0 / 16.0;

const _weekdayTextStyle = TextStyle(
  color: Colors.black,
  fontSize: _kDateFontSize,
  fontWeight: FontWeight.w400,
  height: _kDateLineHeight,
);
const _dateNumTextStyle = TextStyle(
  color: Colors.black,
  fontSize: _kDateFontSize,
  fontWeight: FontWeight.w400,
  height: _kDateLineHeight,
);

// 좌석 색 규칙
const _kAttendedBlue = Color(0xFFCEE6FF); // 출석(수업 외 눌림)
const _kDuringClassGray = Color(0x33A2A2A2); // 출석(수업 중 첫 눌림)
const _kAssignedAbsent = Color(0xFFFFEBE2); // 배정만 되고 미눌림

class DisplayHomePage extends StatefulWidget {
  const DisplayHomePage({super.key});
  @override
  State<DisplayHomePage> createState() => _DisplayHomePageState();
}

class _DisplayHomePageState extends State<DisplayHomePage> {
  int? _enterMs;
  String? _enterSessionId;
  int get _sinceMs => _enterMs ??= DateTime.now().millisecondsSinceEpoch;

  int _eventMs(Map<String, dynamic> x) {
    final ts = x['ts'];
    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
    final hubTs = (x['hubTs'] as num?)?.toInt();
    if (hubTs != null && hubTs > 0) return hubTs;
    final ms = (x['ms'] as num?)?.toInt() ?? (x['lastMs'] as num?)?.toInt();
    if (ms != null && ms > 0) return ms;
    final upd = x['updatedAt'];
    if (upd is Timestamp) return upd.millisecondsSinceEpoch;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final String? kHubId = context.watch<HubProvider>().hubId;

    if (kHubId == null || kHubId.isEmpty) {
      return const Scaffold(body: SafeArea(child: _WaitingSeatScreen()));
    }

    final hubStream = fs.doc('hubs/$kHubId').snapshots();

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

            // 세션이 바뀌면 '입장 기준 시각' 갱신
            if (_enterSessionId != sid) {
              _enterSessionId = sid;
              _enterMs = DateTime.now().millisecondsSinceEpoch;
            }
            final sinceMs = _sinceMs;

            // 세션 메타(행/열 + runIntervals), 좌석맵, 학생목록
            final sessionMeta =
                fs.doc('hubs/$kHubId/sessions/$sid').snapshots();
            final seatMapStream =
                fs.collection('hubs/$kHubId/sessions/$sid/seatMap').snapshots();
            final studentsStream =
                fs.collection('hubs/$kHubId/students').snapshots();

            final liveStream =
                fs.collection('hubs/$kHubId/liveByDevice').snapshots();
            final devicesStream = fs.collection('hubs/$kHubId/devices').snapshots();

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: sessionMeta,
              builder: (context, sessSnap) {
                final meta = sessSnap.data?.data();
                final int cols = (meta?['cols'] as num?)?.toInt() ?? 6;
                final int rows = (meta?['rows'] as num?)?.toInt() ?? 4;

                // runIntervals 파싱
                final List<_Interval> intervals = [];
                final List<dynamic> rawIntervals =
                    (meta?['runIntervals'] as List?) ?? const [];
                for (final e in rawIntervals) {
                  final m = Map<String, dynamic>.from(e as Map);
                  final start = (m['startMs'] as num?)?.toInt();
                  final end = (m['endMs'] as num?)?.toInt();
                  if (start != null) intervals.add(_Interval(start, end));
                }

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

                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: liveStream,
                          builder: (context, liveSnap) {
                            final Map<String, Map<String, dynamic>>
                            liveByDevice = {};
                            if (liveSnap.data != null) {
                              for (final d in liveSnap.data!.docs) {
                                liveByDevice[d.id] = d.data();
                              }
                            }

                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: devicesStream,
                              builder: (context, devSnap) {
                                final Map<String, int> lastMsByStudent = {};
                                final Map<String, String> firstColorByStudent =
                                    {}; // 'gray' | 'blue'

                                if (devSnap.data != null) {
                                  for (final d in devSnap.data!.docs) {
                                    final devId = d.id;
                                    final dev = d.data();
                                    final sidStu =
                                        (dev['studentId'] as String?)?.trim();
                                    if (sidStu == null || sidStu.isEmpty) {
                                      continue;
                                    }

                                    final live = liveByDevice[devId];
                                    if (live == null) continue;

                                    final ms = _eventMs(live);
                                    if (ms <= 0 || ms < sinceMs) continue;

                                    if (!lastMsByStudent.containsKey(sidStu) ||
                                        ms > lastMsByStudent[sidStu]!) {
                                      lastMsByStudent[sidStu] = ms;
                                      firstColorByStudent[sidStu] =
                                          _inAnyInterval(ms, intervals)
                                              ? 'gray'
                                              : 'blue';
                                    }
                                  }
                                }

                                return LayoutBuilder(
                                  builder: (context, box) {
                                    const designW = 1280.0;
                                    const designH = 720.0;
                                    final scaleW = box.maxWidth / designW;
                                    final scaleH = box.maxHeight / designH;
                                    final scaleFit =
                                        scaleW < scaleH ? scaleW : scaleH;

                                    Widget surface = SizedBox(
                                      width: designW,
                                      height: designH,
                                      child: _DesignSurface(
                                        cols: cols,
                                        rows: rows,
                                        seatMap: seatMap,
                                        nameOf: nameOf,
                                        firstColorByStudent:
                                            firstColorByStudent,
                                      ),
                                    );

                                    if (scaleFit < 1) {
                                      return ClipRect(
                                        child: OverflowBox(
                                          alignment: Alignment.center,
                                          minWidth: 0,
                                          minHeight: 0,
                                          maxWidth: double.infinity,
                                          maxHeight: double.infinity,
                                          child: surface,
                                        ),
                                      );
                                    }
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
                                          child: surface,
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DesignSurface extends StatelessWidget {
  const _DesignSurface({
    required this.cols,
    required this.rows,
    required this.seatMap,
    required this.nameOf,
    required this.firstColorByStudent,
  });

  final int cols;
  final int rows;
  final Map<String, String?> seatMap;
  final Map<String, String> nameOf;
  final Map<String, String> firstColorByStudent;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdayStr =
        ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'][now.weekday % 7];
    final dateNumStr =
        '${now.month.toString().padLeft(2, "0")}.${now.day.toString().padLeft(2, "0")}';

    final totalSeats = cols * rows;
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
              Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(weekdayStr, style: _weekdayTextStyle),
                      const SizedBox(width: 8),
                      Text(dateNumStr, style: _dateNumTextStyle),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 680,
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 211, 255, 110),
                        borderRadius: BorderRadius.circular(12.05),
                      ),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Board',
                            maxLines: 1,
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
                  const Spacer(),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 142,
                    child: Text(
                      '$assignedCount / $totalSeats',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 25.26,
                        fontWeight: FontWeight.w700,
                        height: 25 / 25.26,
                        color: Color(0xFF001A36),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Expanded(
                child: _SeatGridReadOnly(
                  cols: cols,
                  rows: rows,
                  seatMap: seatMap,
                  nameOf: nameOf,
                  firstColorByStudent: firstColorByStudent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatGridReadOnly extends StatelessWidget {
  const _SeatGridReadOnly({
    required this.cols,
    required this.rows,
    required this.seatMap,
    required this.nameOf,
    required this.firstColorByStudent,
  });

  final int cols;
  final int rows;
  final Map<String, String?> seatMap;
  final Map<String, String> nameOf;
  final Map<String, String> firstColorByStudent;

  String _seatKey(int index) => '${index + 1}';

  @override
  Widget build(BuildContext context) {
    final seatCount = cols * rows;

    return LayoutBuilder(
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
          itemCount: seatCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: crossSpacing,
            mainAxisSpacing: mainSpacing,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) {
            final seatNo = _seatKey(index);
            final seatStudentId = seatMap[seatNo]?.trim();
            final hasStudent =
                seatStudentId != null && seatStudentId.isNotEmpty;
            final name =
                hasStudent ? (nameOf[seatStudentId!] ?? seatStudentId) : null;

            Color fillColor;
            if (!hasStudent) {
              fillColor = Colors.white;
            } else {
              final first = firstColorByStudent[seatStudentId!];
              if (first == 'gray') {
                fillColor = _kDuringClassGray;
              } else if (first == 'blue') {
                fillColor = _kAttendedBlue;
              } else {
                fillColor = _kAssignedAbsent;
              }
            }

            final isDark = fillColor.computeLuminance() < 0.5;
            final nameColor = isDark ? Colors.white : const Color(0xFF0B1324);
            final seatNoColor =
                isDark ? Colors.white70 : const Color(0xFF1F2937);
            final showDashed = !hasStudent;

            final tile = LayoutBuilder(
              builder: (ctx, cc) {
                const baseH = 76.0;
                final s = (cc.maxHeight / baseH).clamp(0.6, 2.2);

                final radius = 12.0 * s;
                final padH = (6.0 * s).clamp(2.0, 10.0);
                final padV = (4.0 * s).clamp(1.0, 8.0);
                final fsSeat = (12.0 * s).clamp(9.0, 16.0);
                final fsName = (14.0 * s).clamp(10.0, 18.0);
                final gap = (2.0 * s).clamp(1.0, 8.0);

                Widget contentColumn() => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seatNo,
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
                );

                final contentBox = Container(
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(radius),
                    border:
                        showDashed
                            ? null
                            : Border.all(color: Colors.transparent),
                  ),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: padH,
                    vertical: padV,
                  ),
                  child:
                      hasStudent
                          ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: contentColumn(),
                          )
                          : const SizedBox.shrink(),
                );

                return showDashed
                    ? CustomPaint(
                      foregroundPainter: _DashedBorderPainter(
                        radius: radius + 4,
                        color: const Color(0xFFCBD5E1),
                        strokeWidth: (2.0 * s).clamp(1.2, 3.0),
                        dash: (8.0 * s).clamp(5.0, 12.0),
                        gap: (6.0 * s).clamp(3.0, 10.0),
                      ),
                      child: contentBox,
                    )
                    : contentBox;
              },
            );

            return tile;
          },
        );
      },
    );
  }
}

class _Interval {
  _Interval(this.startMs, this.endMs);
  final int startMs;
  final int? endMs;
  bool contains(int t) {
    final end = endMs ?? DateTime.now().millisecondsSinceEpoch;
    return t >= startMs && t <= end;
  }
}

bool _inAnyInterval(int ms, List<_Interval> intervals) {
  for (final r in intervals) {
    if (r.contains(ms)) return true;
  }
  return false;
}

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

    final paint =
        Paint()
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
              '수업을 준비 중입니다…',
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
