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
        child: Center(
          child: (hubId == null)
              ? const Text('No hub', style: TextStyle(color: Colors.black))
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .doc('hubs/$hubId/draws/display')
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || !snap.data!.exists) {
                      return const Text('Waiting…',
                          style:
                              TextStyle(color: Colors.black54, fontSize: 36));
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
                        return const Text(
                          'Waiting…',
                          style: TextStyle(color: Colors.black54, fontSize: 36),
                        );
                      }
                    if (!show || names.isEmpty) {
                      return const Text('Waiting…',
                          style:
                              TextStyle(color: Colors.black54, fontSize: 36));
                    }

                    // 전체 학생 풀 가져오기
                    FirebaseFirestore.instance
                        .collection('hubs/$hubId/students')
                        .get()
                        .then((snap) {
                      _allNamesPool = snap.docs
                          .map((d) => (d.data()['name'] as String?)?.trim())
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

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (title.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        _buildAnimatedList(mode, _displayNames.isEmpty ? names : _displayNames),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildAnimatedList(String mode, List<String> names) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD2D2D2), width: 1),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 40,
        runSpacing: 12,
        children: [
          for (int i = 0; i < names.length; i++)
            ScaleTransition(
              scale: _zoomControllers.length > i
                  ? _zoomControllers[i]
                  : const AlwaysStoppedAnimation(1.0),
              child: Text(
                mode == 'ordering' ? '${i + 1}. ${names[i]}' : names[i],
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
