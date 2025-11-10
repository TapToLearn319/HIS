import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../provider/hub_provider.dart';

class DisplayRandomDrawPage extends StatefulWidget {
  const DisplayRandomDrawPage({super.key});

  @override
  State<DisplayRandomDrawPage> createState() => _DisplayRandomDrawPageState();
}

class _DisplayRandomDrawPageState extends State<DisplayRandomDrawPage>
    with TickerProviderStateMixin {
  bool _animating = false;
  List<String> _displayNames = [];
  List<String> _allNamesPool = [];
  List<bool> _locked = []; // 이미 멈춘 슬롯
  List<AnimationController> _zoomControllers = [];
  bool _firstLoad = true;

  final Random _rand = Random();

  Future<void> _startSlotAnimation(List<String> finalNames) async {
    if (_animating) return;
    setState(() {
      _animating = true;
      _displayNames = List.generate(finalNames.length, (_) => '');
      _locked = List.generate(finalNames.length, (_) => false);
      _zoomControllers = List.generate(
        finalNames.length,
        (_) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
          lowerBound: 1.0,
          upperBound: 1.3,
        ),
      );
    });

    // 슬롯별로 독립적인 회전 루프
    for (int i = 0; i < finalNames.length; i++) {
      _spinSingleSlot(i);
    }

    // 순차적으로 2초 간격으로 멈춤
    for (int i = 0; i < finalNames.length; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _locked[i] = true;
        _displayNames[i] = finalNames[i];
      });
      _zoomControllers[i].forward(from: 0);
      // 줌인 후 다시 줄이기
      _zoomControllers[i].addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _zoomControllers[i].reverse();
        }
      });
    }

    setState(() {
      _animating = false;
    });
  }

  Future<void> _spinSingleSlot(int index) async {
    int delay = 50;
    while (mounted && !_locked[index]) {
      await Future.delayed(Duration(milliseconds: delay));
      if (!_locked[index] && _allNamesPool.isNotEmpty) {
        setState(() {
          _displayNames[index] =
              _allNamesPool[_rand.nextInt(_allNamesPool.length)];
        });
      }
      // 점점 느려지는 효과
      if (delay < 150) delay += 2;
    }
  }

  @override
  void dispose() {
    for (final c in _zoomControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hubId = context.watch<HubProvider>().hubId;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF), // 밝은 하늘색
      body: SafeArea(
        child:
            (hubId == null)
                ? const Center(
                  child: Text('No hub', style: TextStyle(color: Colors.black)),
                )
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance
                          .doc('hubs/$hubId/draws/display')
                          .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || !snap.data!.exists) {
                      return const Center(
                        child: Text(
                          'Waiting…',
                          style: TextStyle(color: Colors.black54, fontSize: 36),
                        ),
                      );
                    }

                    final data = snap.data!.data()!;
                    final show = (data['show'] as bool?) ?? false;
                    final mode = (data['mode'] as String?) ?? 'lots';
                    final title = (data['title'] as String?) ?? '';
                    final names =
                        (data['names'] as List?)?.cast<String>() ?? const [];

                    // ✅ 첫 진입일 경우, 이전 show=true 데이터가 있더라도 무조건 Waiting 표시
                    if (_firstLoad) {
                      _firstLoad = false;
                      return const Center(
                        child: Text(
                          'Waiting…',
                          style: TextStyle(color: Colors.black54, fontSize: 36),
                        ),
                      );
                    }
                    if (!show || names.isEmpty) {
                      return const Center(
                        child: Text(
                          'Waiting…',
                          style: TextStyle(color: Colors.black54, fontSize: 36),
                        ),
                      );
                    }

                    // 전체 학생 풀 가져오기
                    FirebaseFirestore.instance
                        .collection('hubs/$hubId/students')
                        .get()
                        .then((snap) {
                          _allNamesPool =
                              snap.docs
                                  .map(
                                    (d) =>
                                        (d.data()['name'] as String?)?.trim(),
                                  )
                                  .whereType<String>()
                                  .toList();
                        });

                    // 새로운 draw 시작
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_animating &&
                          (_displayNames.isEmpty ||
                              !_displayNames.contains(names.first))) {
                        _startSlotAnimation(names);
                      }
                    });

                    // ✅ Stack을 사용해 타이틀은 위, 이름박스는 중앙에 배치
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // 중앙 학생 리스트
                        _buildAnimatedList(
                          mode,
                          _displayNames.isEmpty ? names : _displayNames,
                        ),

                        // 상단 타이틀
                        if (title.isNotEmpty)
                          Positioned(
                            top: 120, // ← 원하는 높이 조절 가능 (예: 60~120)
                            left: 0,
                            right: 0,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  (title.isNotEmpty) ? title : '(Title)',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF001A36),
                                    fontFamily: 'Montserrat',
                                    fontSize: 59,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Positioned(
                                  left:
                                      MediaQuery.of(context).size.width / 2 -
                                      240,
                                  child: Container(
                                    width: 89.9,
                                    height: 89.9,
                                    decoration: BoxDecoration(
                                      color: const Color(0x3344DAAD),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.check_box_outlined,
                                        color: Color(0xFF44DAAD),
                                        size: 57.4,
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
                ),
      ),
    );
  }

  Widget _buildAnimatedList(String mode, List<String> names) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double baseWidth = 1280;
        final double scale = (constraints.maxWidth / baseWidth).clamp(0.6, 1.0);

        const int maxPerRow = 3;
        final int totalRows = (names.length / maxPerRow).ceil();
        final double dynamicScale =
            (1.0 - (names.length / 60).clamp(0.0, 0.4)) * scale;

        final double fontSize = (58 * dynamicScale).clamp(26, 58);
        final double spacing = 100 * dynamicScale;
        final double runSpacing = 40 * dynamicScale;
        final double padding = 40 * dynamicScale;

        // 한 줄에 3명씩 분할
        List<List<String>> grouped = [];
        for (int i = 0; i < names.length; i += maxPerRow) {
          grouped.add(
            names.sublist(
              i,
              (i + maxPerRow > names.length) ? names.length : i + maxPerRow,
            ),
          );
        }

        // 화면 높이의 70%까지만 확장 허용
        final double maxBoxHeight = constraints.maxHeight * 0.7;

        // 실제 내용 높이 예상치 계산 (대략적)
        final double expectedHeight =
            (totalRows * (fontSize + runSpacing)) + (padding * 2);

        return Center(
          child: Container(
            width: 1200 * scale,
            constraints: BoxConstraints(
              maxHeight: maxBoxHeight, // 최대 높이 제한
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12 * scale),
              border: Border.all(
                color: const Color(0xFFD2D2D2),
                width: 1 * scale,
              ),
            ),
            padding: EdgeInsets.symmetric(
              vertical: padding,
              horizontal: padding * 1.2,
            ),
            child: SingleChildScrollView(
              // ✅ 내용이 넘치면 스크롤
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int row = 0; row < grouped.length; row++)
                    Padding(
                      padding: EdgeInsets.only(bottom: runSpacing),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int j = 0; j < grouped[row].length; j++)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: spacing / 2,
                              ),
                              child: ScaleTransition(
                                scale:
                                    _zoomControllers.length >
                                            (row * maxPerRow + j)
                                        ? _zoomControllers[row * maxPerRow + j]
                                        : const AlwaysStoppedAnimation(1.0),
                                child: Text(
                                  mode == 'ordering'
                                      ? '${row * maxPerRow + j + 1}. ${grouped[row][j]}'
                                      : grouped[row][j],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF001A36),
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
