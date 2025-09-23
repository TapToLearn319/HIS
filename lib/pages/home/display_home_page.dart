// lib/pages/home/display_home_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';

// 색 정의 (프레젠터와 동일)
const _kAttendedBlue = Color(0xFFCEE6FF); // 연파랑
const _kDuringClassGray = Color(0x33A2A2A2); // 회색(투명)
const _kAssignedAbsent = Color(0xFFFFEBE2); // 배정됐지만 누름 없음(살구빛)

class DisplayHomePage extends StatefulWidget {
  const DisplayHomePage({super.key});

  @override
  State<DisplayHomePage> createState() => _DisplayHomePageState();
}

class _DisplayHomePageState extends State<DisplayHomePage> {
  // ⬇️ 디스플레이 입장 이후에 눌린 것만 인정하기 위한 기준 시각(세션별)
  int? _enterMs;
  String? _enterSessionId;
  int get _sinceMs => _enterMs ??= DateTime.now().millisecondsSinceEpoch;

  // live/event 공통 타임스탬프 파싱 (프레젠터와 동일 우선순위)
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

    // ✅ 허브가 아직 선택되지 않았으면 대기 화면
    if (kHubId == null || kHubId.isEmpty) {
      return const Scaffold(body: SafeArea(child: _WaitingSeatScreen()));
    }

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

            // 세션이 바뀌면 '입장 기준 시각' 갱신
            if (_enterSessionId != sid) {
              _enterSessionId = sid;
              _enterMs = DateTime.now().millisecondsSinceEpoch;
            }
            final sinceMs = _sinceMs;

            // 세션 메타(행/열 + runIntervals), 좌석맵, 학생목록
            final sessionMeta = fs.doc('hubs/$kHubId/sessions/$sid').snapshots();
            final seatMapStream =
                fs.collection('hubs/$kHubId/sessions/$sid/seatMap').snapshots();
            final studentsStream =
                fs.collection('hubs/$kHubId/students').snapshots();

            // ✅ live: 버튼의 최신 상태
            final liveStream =
                fs.collection('hubs/$kHubId/liveByDevice').snapshots();
            // ✅ devices: 각 버튼 → 학생 매핑
            final devicesStream = fs.collection('devices').snapshots();

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

                        // ⬇️ liveByDevice + devices 조합으로 좌석 색 결정
                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: liveStream,
                          builder: (context, liveSnap) {
                            final Map<String, Map<String, dynamic>> liveByDevice =
                                {};
                            if (liveSnap.data != null) {
                              for (final d in liveSnap.data!.docs) {
                                liveByDevice[d.id] = d.data();
                              }
                            }

                            return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: devicesStream,
                              builder: (context, devSnap) {
                                // studentId -> 마지막 ms / 색상
                                final Map<String, int> lastMsByStudent = {};
                                final Map<String, String>
                                    firstColorByStudent = {}; // 'gray' | 'blue'

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
                                    // 🚦입장 이전 기록은 무시
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

                                return _SeatBoard(
                                  cols: cols,
                                  rows: rows,
                                  seatMap: seatMap,
                                  nameOf: nameOf,
                                  firstColorByStudent: firstColorByStudent,
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

/* ------------------------ Seat Board ------------------------ */

class _SeatBoard extends StatelessWidget {
  const _SeatBoard({
    required this.cols,
    required this.rows,
    required this.seatMap,
    required this.nameOf,
    required this.firstColorByStudent,
  });

  final int cols;
  final int rows;
  final Map<String, String?> seatMap; // seatNo -> studentId?
  final Map<String, String> nameOf; // studentId -> name
  final Map<String, String> firstColorByStudent; // studentId -> 'gray' | 'blue'

  String _seatKey(int index) => '${index + 1}';

  @override
  Widget build(BuildContext context) {
    final seatCount = cols * rows;
    final screenW = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // 상단 Board Pill (프레젠터 톤 맞춤)
          Container(
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
          ),
          const SizedBox(height: 12),

          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
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
                    final seatStudentId = seatMap[seatNo]?.trim();
                    final hasStudent =
                        seatStudentId != null && seatStudentId.isNotEmpty;
                    final name =
                        hasStudent ? (nameOf[seatStudentId!] ?? seatStudentId) : null;

                    // 프레젠터와 동일 규칙: live 기준 색
                    Color fillColor;
                    if (!hasStudent) {
                      fillColor = Colors.white;
                    } else {
                      final firstColor =
                          firstColorByStudent[seatStudentId!]; // null이면 아직 누르지 않음
                      if (firstColor == 'gray') {
                        fillColor = _kDuringClassGray; // 수업 중
                      } else if (firstColor == 'blue') {
                        fillColor = _kAttendedBlue; // 수업 외
                      } else {
                        fillColor = _kAssignedAbsent; // 배정만, 터치 없음
                      }
                    }

                    final core = Container(
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(12),
                        border: hasStudent
                            ? Border.all(
                                color: const Color(0xFF8DB3FF), width: 1.2)
                            : null,
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
                                  name ?? '',
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

                    if (!hasStudent) {
                      // 빈 좌석은 점선
                      return CustomPaint(
                        foregroundPainter: _DashedBorderPainter(
                          radius: 12,
                          color: const Color(0xFFCBD5E1),
                          strokeWidth: 1.4,
                          dash: 6,
                          gap: 5,
                        ),
                        child: core,
                      );
                    }
                    return core;
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------- Util / painter ---------------------- */

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

/* --------------------- Waiting Screen ---------------------- */

class _WaitingSeatScreen extends StatelessWidget {
  const _WaitingSeatScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6FAFF),
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
