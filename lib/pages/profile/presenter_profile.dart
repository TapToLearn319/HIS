


// PresenterMainPage — 전체 학생 페이지 (리팩터링)
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../sidebar_menu.dart';
import '../../provider/students_provider.dart';

const String kHubId = 'hub-001';

class PresenterMainPage extends StatefulWidget {
  const PresenterMainPage({super.key});
  @override
  State<PresenterMainPage> createState() => _PresenterMainPageState();
}

class _PresenterMainPageState extends State<PresenterMainPage> {
  String _tab = 'students'; // 'students' | 'groups'
  String _query = '';

  // ── helpers ─────────────────────────────────────────────
  int _colsForWidth(double w) {
    if (w >= 1500) return 6;
    if (w >= 1200) return 5;
    if (w >= 1000) return 4;
    if (w >= 700) return 3;
    return 2;
  }

  // State 클래스 안에 함수 추가
  Future<void> _addStudentDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Add student'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Student name',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add'),
              ),
            ],
          ),
    );
    if (ok != true) return;

    final name = ctrl.text.trim();
    if (name.isEmpty) return;

    final fs = FirebaseFirestore.instance;
    await fs.collection('students').add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      // 필요시 초기 필드 추가 가능: 'deviceId': null,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Added: $name')));
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StudentsProvider>();
    final width = MediaQuery.sizeOf(context).width;

    // 학생 목록 정렬 + 검색 필터
    final students =
        sp.students.entries.map((e) => MapEntry(e.key, e.value)).toList()..sort(
          (a, b) => (a.value['name'] ?? '').toString().toLowerCase().compareTo(
            (b.value['name'] ?? '').toString().toLowerCase(),
          ),
        );

    final filtered =
        (_query.trim().isEmpty)
            ? students
            : students.where((e) {
              final n = (e.value['name'] ?? '').toString().toLowerCase();
              return n.contains(_query.trim().toLowerCase());
            }).toList();

    return AppScaffold(
      selectedIndex: 1,
      body: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _addStudentDialog,
                icon: const Icon(
                  Icons.person_add_alt_1,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Add Student',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF44A0FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF6FAFF),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(color: Color(0xFFF6FAFF)),
                child: Row(
                  children: [
                    const Spacer(),
                    // SizedBox(
                    //   width: 280,
                    //   child: TextField(
                    //     onChanged: (v) => setState(() => _query = v),
                    //     decoration: InputDecoration(
                    //       prefixIcon: const Icon(Icons.search, size: 18),
                    //       hintText: 'Search Students',
                    //       isDense: true,
                    //       contentPadding: const EdgeInsets.symmetric(
                    //         horizontal: 10,
                    //         vertical: 10,
                    //       ),
                    //       border: OutlineInputBorder(
                    //         borderRadius: BorderRadius.circular(20),
                    //         borderSide: const BorderSide(
                    //           color: Color(0xFFF6FAFF),
                    //         ),
                    //       ),
                    //       filled: true,
                    //       fillColor: const Color(0xFFF6FAFF),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),

              // ── Tabs ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                color: const Color(0xFFF6FAFF),
                child: Row(
                  children: [
                    TabChip(
                      label: 'Students',
                      selected: _tab == 'students',
                      onTap: () => setState(() => _tab = 'students'),
                    ),
                    const SizedBox(width: 16),
                    TabChip(
                      label: 'Groups',
                      selected: _tab == 'groups',
                      onTap: () => setState(() => _tab = 'groups'),
                    ),
                  ],
                ),
              ),

              // ── Grid ────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child:
                      _tab == 'students'
                          ? _StudentsGrid(
                            cols: _colsForWidth(width),
                            students: filtered,
                          )
                          : const _GroupsPlaceholder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ========================== Widgets ========================== */

class TabChip extends StatelessWidget {
  const TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 선택 시/비선택 시 색상만 바꾸고, 폰트는 동일 스펙 유지
    final Color color =
        selected ? const Color(0xFF001A36) : const Color(0xFFA2A2A2);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 18.3, // 18.3px
                fontWeight: FontWeight.w600, // 600
                color: color, // #001A36(선택) / #9CA3AF(미선택)
                height: 1.0, // line-height: normal
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentsGrid extends StatelessWidget {
  const _StudentsGrid({required this.cols, required this.students});
  final int cols;
  final List<MapEntry<String, Map<String, dynamic>>> students;

  @override
  Widget build(BuildContext context) {
    final items = [
      const _ClassCard(), // 첫 칸: 전체(Class) 카드
      ...students.map((e) => _StudentCard(studentId: e.key, data: e.value)),
    ];

    return GridView.builder(
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (_, i) => items[i],
    );
  }
}

class _PointBubble extends StatelessWidget {
  const _PointBubble(this.value, {super.key});
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, // 카드에서 쓰는 29.8px → 반올림
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF44A0FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          color: Colors.white, // #FFFFFF
          fontSize: 18, // 18px
          fontWeight: FontWeight.w500, // 500
          height: 1.0, // line-height normal
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: fs.collection('students').snapshots(),
      builder: (_, snap) {
        int total = 0;
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            total += ((d.data()['points'] as num?) ?? 0).toInt();
          }
        }

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.pushNamed(context, '/profile/class'),
          child: Stack(
            children: [
              // 카드 본체 (학생 카드와 동일)
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD2D2D2), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(
                              width: 112,
                              height: 103,
                              child: Image(
                                image: AssetImage('assets/logo_bird.png'),
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(height: 10),
                            SizedBox(
                              width: 112, // 선택: 동일 고정폭
                              child: Text(
                                'Class',
                                textAlign: TextAlign.center,
                                style: kNameTextStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: _PointBubble(total),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const kNameTextStyle = TextStyle(
  color: Color(0xFF001A36),
  fontSize: 20,
  fontWeight: FontWeight.w500,
  height: 1.0, // line-height: normal
);

/// 학생 카드
class _StudentCard extends StatelessWidget {
  const _StudentCard({super.key, required this.studentId, required this.data});
  final String studentId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] as String?) ?? '(no name)';
    final pointsStream =
        FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: pointsStream,
      builder: (_, snap) {
        final pts = (snap.data?.data()?['points'] as num?)?.toInt() ?? 0;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap:
              () => Navigator.pushNamed(
                context,
                '/profile/student',
                arguments: {'id': studentId},
              ),
          child: Stack(
            children: [
              // 카드 본체
              // 기존: width: 170, height: 170
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD2D2D2), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 112,
                              height: 103,
                              child: Image.asset(
                                'assets/logo_bird.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // ⬇️ 학생 이름 추가
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: SizedBox(
                                width:
                                    112, // Figma에서 준 레이아웃(112x26)에 맞춰 고정폭(선택)
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: kNameTextStyle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: _PointBubble(pts),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupsPlaceholder extends StatelessWidget {
  const _GroupsPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Groups (coming soon)', style: TextStyle(color: Colors.grey)),
    );
  }
}
