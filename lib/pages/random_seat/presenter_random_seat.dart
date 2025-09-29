import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Providers
import '../../provider/students_provider.dart';
import '../../provider/hub_provider.dart';
import '../../sidebar_menu.dart';

const _kAppBg = Color(0xFFF6FAFF);

// ===== 카드/스타일 =====
const _kCardW = 1011.0;
const _kCardH = 544.0;
const _kCardRadius = 10.0;
const _kCardBorder = Color(0xFFD2D2D2);

const _kAttendedBlue = Color(0xFFCEE6FF);
const _kAssignedDashed = Color(0xFFCBD5E1);
const _kTextDark = Color(0xFF0B1324);
const _kTextNum = Color(0xFF1F2937);

class RandomSeatPage extends StatefulWidget {
  const RandomSeatPage({super.key});
  @override
  State<RandomSeatPage> createState() => _RandomSeatPageState();
}

class _RandomSeatPageState extends State<RandomSeatPage> {
  bool _working = false;
  bool _didBootstrap = false;

  String _seatKey(int index) => '${index + 1}';

  String? get _fileId {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['fileId'] is String)
      return args['fileId'] as String;
    return null;
  }

  Future<void> _bootstrapFileSeatMapIfEmpty({
    required String hubId,
    required String fileId,
  }) async {
    if (_didBootstrap) return;
    final fs = FirebaseFirestore.instance;

    // 1) 파일 seatMap이 비었는지 확인
    final seatCol = fs.collection(
      'hubs/$hubId/randomSeatFiles/$fileId/seatMap',
    );
    final cur = await seatCol.limit(1).get();
    if (cur.size > 0) {
      _didBootstrap = true;
      return;
    }

    // 2) 복사할 원본 세션 결정: hubs/{hubId}.currentSessionId 또는 파일 문서의 baseSessionId
    final fileDoc = await fs.doc('hubs/$hubId/randomSeatFiles/$fileId').get();
    final hubDoc = await fs.doc('hubs/$hubId').get();
    final baseSid = (fileDoc.data()?['baseSessionId'] as String?)?.trim();
    final hubSid = (hubDoc.data()?['currentSessionId'] as String?)?.trim();
    final sid = (baseSid?.isNotEmpty == true ? baseSid : hubSid);

    if (sid == null || sid.isEmpty) {
      // 세션이 없으면 학생 전원 미배정 상태로 생성하지 않고 종료
      _didBootstrap = true;
      return;
    }

    // 3) 원본 세션 seatMap 복사
    final src = await fs.collection('hubs/$hubId/sessions/$sid/seatMap').get();
    final batch = fs.batch();
    for (final d in src.docs) {
      final data = d.data();
      batch.set(seatCol.doc(d.id), {
        'studentId': data['studentId'],
      }, SetOptions(merge: true));
    }
    // 파일 메타에 rows/cols 없으면 세션 메타에서 가져와 채워 넣기(옵션)
    final sessMeta = await fs.doc('hubs/$hubId/sessions/$sid').get();
    final cols = (sessMeta.data()?['cols'] as num?)?.toInt();
    final rows = (sessMeta.data()?['rows'] as num?)?.toInt();
    batch.set(fs.doc('hubs/$hubId/randomSeatFiles/$fileId'), {
      if (cols != null) 'cols': cols,
      if (rows != null) 'rows': rows,
      'updatedAt': FieldValue.serverTimestamp(),
      'baseSessionId': sid,
    }, SetOptions(merge: true));

    await batch.commit();
    _didBootstrap = true;
  }

  // === MIX: 해당 카드 seatMap만 셔플 ===
  Future<void> _randomize() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final hubId = context.read<HubProvider>().hubId;
      final fileId = _fileId;
      if (hubId == null || hubId.isEmpty || fileId == null) {
        _snack('파일 정보를 찾지 못했습니다.');
        return;
      }

      final fs = FirebaseFirestore.instance;
      final seatCol = fs.collection(
        'hubs/$hubId/randomSeatFiles/$fileId/seatMap',
      );
      final snap = await seatCol.get();

      // 좌석번호 오름차순
      final docs = [...snap.docs]..sort((a, b) {
        int ai = int.tryParse(a.id) ?? 0;
        int bi = int.tryParse(b.id) ?? 0;
        return ai.compareTo(bi);
      });

      // 배정된 좌석/학생
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

      // 셔플 & 반영
      final shuffled = assignedStudentSet.toList()..shuffle(Random());
      final batch = fs.batch();
      for (int i = 0; i < assignedSeatNos.length; i++) {
        final seatNo = assignedSeatNos[i];
        final newSid = (i < shuffled.length) ? shuffled[i] : null;
        batch.set(seatCol.doc(seatNo), {
          'studentId': newSid,
        }, SetOptions(merge: true));
      }
      // 파일 updatedAt 갱신
      batch.set(fs.doc('hubs/$hubId/randomSeatFiles/$fileId'), {
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();

      _snack('MIX 완료! (이 카드에만 적용됨)');
    } catch (e) {
      _snack('MIX 실패: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // === SAVE: 세션이 아닌, 현재 카드 seatMap에 저장 ===
  // (현재 화면도 카드 seatMap을 실시간으로 보고 있으므로,
  //  서버 상태를 다시 읽어 동일 경로에 명시적으로 반영 + updatedAt 갱신)
  Future<void> _saveToCard() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final hubId = context.read<HubProvider>().hubId;
      final fileId = _fileId;
      if (hubId == null || hubId.isEmpty || fileId == null) {
        _snack('파일 정보를 찾지 못했습니다.');
        return;
      }

      final fs = FirebaseFirestore.instance;
      final seatCol = fs.collection(
        'hubs/$hubId/randomSeatFiles/$fileId/seatMap',
      );

      // 현재 서버 seatMap 스냅샷(=화면과 동일)을 읽어 같은 경로에 저장(보수적 저장)
      final cur = await seatCol.get();
      final batch = fs.batch();
      for (final d in cur.docs) {
        final data = d.data();
        batch.set(seatCol.doc(d.id), {
          'studentId': data['studentId'],
        }, SetOptions(merge: true));
      }
      // updatedAt만 확실히 갱신
      batch.set(fs.doc('hubs/$hubId/randomSeatFiles/$fileId'), {
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();

      _snack('이 카드에 좌석 배치를 저장했습니다.');
    } catch (e) {
      _snack('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    (m ?? ScaffoldMessenger.of(context))
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final studentsProvider = context.watch<StudentsProvider>();
    final hubId = context.watch<HubProvider>().hubId;
    final fileId = _fileId;

    return AppScaffold(
      selectedIndex: 0,
      
      body: Scaffold(
        backgroundColor: _kAppBg,
        appBar: AppBar(
                  elevation: 0,
                  backgroundColor: const Color(0xFFF6FAFF),
                  leading: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
        body:
            (hubId == null || fileId == null)
                ? const Center(child: Text('파일을 찾을 수 없습니다.'))
                : Stack(
                  children: [
                    // === 파일 메타(rows/cols) + seatMap 구독 ===
                    _FileSeatBoard(
                      hubId: hubId,
                      fileId: fileId,
                      studentsProvider: studentsProvider,
                      onMix: _randomize,
                    ),

                    // 우측 하단: SAVE (→ 카드에 저장)
                    _SaveFabImage(onTap: _saveToCard),

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
      ),
    );
  }
}

/* ------------------------ Seat Board (파일 스코프) ------------------------ */

class _FileSeatBoard extends StatelessWidget {
  const _FileSeatBoard({
    required this.hubId,
    required this.fileId,
    required this.studentsProvider,
    required this.onMix,
  });

  final String hubId;
  final String fileId;
  final StudentsProvider studentsProvider;
  final VoidCallback onMix;

  String _seatKey(int index) => '${index + 1}';

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    final fileDocStream =
        fs.doc('hubs/$hubId/randomSeatFiles/$fileId').snapshots();
    final seatMapStream =
        fs
            .collection('hubs/$hubId/randomSeatFiles/$fileId/seatMap')
            .snapshots();
    final studentsStream = fs.collection('hubs/$hubId/students').snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fileDocStream,
      builder: (context, metaSnap) {
        final meta = metaSnap.data?.data();
        final int cols = (meta?['cols'] as num?)?.toInt() ?? 6;
        final int rows = (meta?['rows'] as num?)?.toInt() ?? 4;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: seatMapStream,
          builder: (context, seatSnap) {
            // ★ 비어 있으면 한 번만 초기화 시도
            if ((seatSnap.data?.size ?? 0) == 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final state =
                    context.findAncestorStateOfType<_RandomSeatPageState>();
                state?._bootstrapFileSeatMapIfEmpty(
                  hubId: hubId,
                  fileId: fileId,
                );
              });
            }

            final Map<String, String?> seatMap = {};
            if (seatSnap.data != null) {
              for (final d in seatSnap.data!.docs) {
                seatMap[d.id] = (d.data()['studentId'] as String?)?.trim();
              }
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: studentsStream,
              builder: (context, stuSnap) {
                // 화면 타이틀 왼쪽 총원 계산
                final assignedCount =
                    seatMap.values
                        .where((v) => (v?.isNotEmpty ?? false))
                        .length;

                final child = _DesignSurfaceRandom(
                  cols: cols,
                  rows: rows,
                  seatMap: seatMap,
                  studentsProvider: studentsProvider,
                  assignedCount: assignedCount,
                  onMix: onMix,
                );

                // 1280×720 스케일/클리핑 래퍼
                return LayoutBuilder(
                  builder: (context, box) {
                    const designW = 1280.0;
                    const designH = 720.0;
                    final scaleW = box.maxWidth / designW;
                    final scaleH = box.maxHeight / designH;
                    final scaleFit = scaleW < scaleH ? scaleW : scaleH;

                    if (scaleFit < 1) {
                      return ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          minWidth: 0,
                          minHeight: 0,
                          maxWidth: double.infinity,
                          maxHeight: double.infinity,
                          child: SizedBox(
                            width: designW,
                            height: designH,
                            child: child,
                          ),
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
                          child: SizedBox(
                            width: designW,
                            height: designH,
                            child: child,
                          ),
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
  }
}

/* ------------------------ 디자인 ------------------------ */

class _DesignSurfaceRandom extends StatelessWidget {
  const _DesignSurfaceRandom({
    required this.seatMap,
    required this.studentsProvider,
    required this.cols,
    required this.rows,
    required this.assignedCount,
    required this.onMix,
  });

  final Map<String, String?> seatMap;
  final StudentsProvider studentsProvider;
  final int cols;
  final int rows;
  final int assignedCount;
  final VoidCallback onMix;

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
              // 헤더: 좌(총원/배치정보) • 중(Board) • 우(MIX)
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total $assignedCount',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$cols column / $rows row',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
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
                  TextButton.icon(
                    onPressed: onMix,
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: const Text(
                      'MIX',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFFF96F1),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      fixedSize: const Size(106, 40),
                      backgroundColor: const Color(0x33FF96F1),
                      foregroundColor: const Color(0xFFFF96F1),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 좌석 그리드
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    const crossSpacing = 24.0;
                    const mainSpacing = 24.0;

                    final gridW = c.maxWidth;
                    final gridH = c.maxHeight - 2;
                    final tileW = (gridW - crossSpacing * (cols - 1)) / cols;
                    final tileH = (gridH - mainSpacing * (rows - 1)) / rows;
                    final ratio =
                        (tileW / tileH).isFinite ? tileW / tileH : 1.0;

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
                        final name =
                            hasStudent
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

/* ========== 타일 ========== */
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
          child:
              hasStudent
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

/* ---------- dashed painter ---------- */
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
        final len =
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
                message: 'Save seat layout (this card)',
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Image.asset(
                    'assets/logo_bird_save.png',
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) => const Icon(
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
