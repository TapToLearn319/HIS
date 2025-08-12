import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../sidebar_menu.dart';
import '../../login.dart';
import '../../provider/seat_provider.dart';
import 'presenter_student_log_page.dart';

class PresenterMainPage extends StatefulWidget {
  const PresenterMainPage({super.key});

  @override
  State<PresenterMainPage> createState() => _PresenterMainPageState();
}

class _PresenterMainPageState extends State<PresenterMainPage> {
  String selectedCategory = 'student';

  final List<String> categories = ['student', 'quiz'];

  final List<Map<String, String>> quizItems = [
    {'name': 'Timer', 'desc': 'Manage time effectively'},
    {'name': 'OX Quiz', 'desc': 'True/False quick check'},
    {'name': 'MCQ', 'desc': 'Multiple-choice quiz'},
  ];

  Color getCategoryColor(String category) {
    switch (category) {
      case 'student':
        return Colors.indigo;
      case 'quiz':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final seatAssignments = context.watch<SeatProvider>().seatAssignments;
    final studentEntries = seatAssignments.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return AppScaffold(
      selectedIndex: 1,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 + 로그아웃
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Class : 3B\nMathematics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        decoration: TextDecoration.none,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 카테고리 탭
            SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: categories.map((category) {
                  final isSelected = selectedCategory == category;
                  return GestureDetector(
                    onTap: () => setState(() => selectedCategory = category),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 20,
                            color: isSelected ? Colors.black : Colors.grey,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            height: 2,
                            width: 30,
                            color: Colors.black,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // 섹션 타이틀/설명
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                selectedCategory,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2E3A59),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Text(
                'Select an item in this category.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  decoration: TextDecoration.none,
                ),
              ),
            ),

            // 카드 그리드
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.all(12),
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                // 카드 높이(세로) 조절
                childAspectRatio: 3 / 1.5,
                children: selectedCategory == 'student'
                    // -------------------- 학생 카드 --------------------
                    ? studentEntries.map((e) {
                        final seat = e.key; // 0-based
                        final name = e.value;
                        final color = getCategoryColor('student');
                        return Card(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: color, width: 1.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StudentLogPage(
                                    studentName: name,
                                    seatIndex: seat,
                                  ),
                                ),
                              );
                            },
                            child: Stack(
                              children: [
                                // 상단 오른쪽 라벨
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Student ${seat + 1}', // 1부터
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),

                                // 카드 정중앙 아바타
                                Center(
                                  child: CircleAvatar(
                                    radius: 30, // 원 키움
                                    backgroundColor: Colors.black12,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          name, // 전체 이름 (길면 축소)
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // (선택) 하단 이름 라벨 쓰려면 주석 해제
                                // Positioned(
                                //   left: 8,
                                //   right: 8,
                                //   bottom: 8,
                                //   child: Text(
                                //     name,
                                //     maxLines: 1,
                                //     overflow: TextOverflow.ellipsis,
                                //     textAlign: TextAlign.center,
                                //     style: const TextStyle(
                                //       fontSize: 13,
                                //       fontWeight: FontWeight.bold,
                                //     ),
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        );
                      }).toList()
                    // -------------------- 퀴즈 카드 --------------------
                    : quizItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final color = getCategoryColor('quiz');
                        return Card(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: color, width: 1.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: InkWell(
                            onTap: () {
                              // TODO: 각 퀴즈 페이지로 라우팅
                              // Navigator.push(context, MaterialPageRoute(builder: (_) => ...));
                            },
                            child: Stack(
                              children: [
                                // 상단 오른쪽 라벨
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'quiz',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),

                                // 카드 정중앙 아이콘/타이틀
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.apps,
                                        size: 44,
                                        color: Colors.black26,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item['name']!,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // (선택) 하단 설명 라벨
                                Positioned(
                                  left: 8,
                                  right: 8,
                                  bottom: 8,
                                  child: Text(
                                    item['desc']!,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
