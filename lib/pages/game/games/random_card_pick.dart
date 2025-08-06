import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../provider/all_logs_provider.dart';

class RandomCardPickPage extends StatefulWidget {
  const RandomCardPickPage({super.key});

  @override
  State<RandomCardPickPage> createState() => _RandomCardPickPageState();
}

class _RandomCardPickPageState extends State<RandomCardPickPage>
    with SingleTickerProviderStateMixin {
  List<String> allStudents = [];
  bool gameStarted = false;

  OverlayEntry? _overlayEntry;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    fetchStudentsFromFirestore();

    // 🔥 진입 시 로그 초기화
    Future.microtask(() {
      context.read<AllLogsProvider>().clearLogs();
    });

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void fetchStudentsFromFirestore() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('students').get();
    setState(() {
      allStudents =
          snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  void startGame() {
    setState(() {
      gameStarted = true;
    });
  }

  void resetGame() {
    setState(() {
      gameStarted = false;
    });

    // 🔥 다시 시작 시 로그 초기화
    context.read<AllLogsProvider>().clearLogs();
  }

  void revealStudent(BuildContext context, String name, Rect cardRect) async {
    final overlay = Overlay.of(context);
    final center = MediaQuery.of(context).size.center(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (_) {
        return Positioned(
          left: center.dx - 100,
          top: center.dy - 100,
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Card(
                color: Colors.amber,
                elevation: 12,
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
    await _controller.forward();
    await Future.delayed(const Duration(seconds: 1));
    _overlayEntry?.remove();
    _overlayEntry = null;
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    final logsProvider = context.watch<AllLogsProvider>();
    final logs = logsProvider.allLogs;
    final isClearing = logsProvider.isClearing;

    if (isClearing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "Loading...",
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    final Set<String> participantSet = {
      for (var log in logs) log.studentName
    };
    final List<String> participants = participantSet.toList()..shuffle();

    return Scaffold(
      appBar: AppBar(title: const Text('랜덤 카드 뽑기')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: gameStarted
            ? Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (participants.isEmpty) {
                          return const Center(
                              child: Text('참여한 학생이 없습니다.'));
                        }

                        int crossAxisCount = (participants.length <= 3)
                            ? participants.length
                            : (participants.length <= 6)
                                ? 3
                                : (participants.length <= 9)
                                    ? 3
                                    : 4;
                        int rowCount =
                            (participants.length / crossAxisCount).ceil();

                        double spacing = 12;
                        double cardWidth = (constraints.maxWidth -
                                spacing * (crossAxisCount - 1)) /
                            crossAxisCount;
                        double cardHeight = (constraints.maxHeight -
                                spacing * (rowCount - 1)) /
                            rowCount;

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          childAspectRatio: cardWidth / cardHeight,
                          children: participants.map((name) {
                            return Builder(builder: (cardContext) {
                              return GestureDetector(
                                onTap: () {
                                  final renderBox =
                                      cardContext.findRenderObject()
                                          as RenderBox;
                                  final cardRect =
                                      renderBox.localToGlobal(Offset.zero) &
                                          renderBox.size;
                                  revealStudent(context, name, cardRect);
                                },
                                child: Card(
                                  color: Colors.grey.shade300,
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: const Text(
                                        '?',
                                        style: TextStyle(
                                          fontSize: 100,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            });
                          }).toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: resetGame,
                    child: const Text('게임 다시 시작'),
                  ),
                ],
              )
            : Center( // ✅ 전체를 Center로 감싸서 가운데 정렬
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: startGame,
                      child: const Text('게임 시작하기'),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: participants
                          .map((name) => Chip(label: Text(name)))
                          .toList(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
