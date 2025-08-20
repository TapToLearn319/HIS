

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
    if (w >= 700)  return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StudentsProvider>();
    final width = MediaQuery.sizeOf(context).width;

    // 학생 목록 정렬 + 검색 필터
    final students = sp.students.entries
        .map((e) => MapEntry(e.key, e.value))
        .toList()
      ..sort((a, b) =>
          (a.value['name'] ?? '').toString().toLowerCase()
              .compareTo((b.value['name'] ?? '').toString().toLowerCase()));

    final filtered = (_query.trim().isEmpty)
        ? students
        : students.where((e) {
            final n = (e.value['name'] ?? '').toString().toLowerCase();
            return n.contains(_query.trim().toLowerCase());
          }).toList();

    return AppScaffold(
      selectedIndex: 1,
      body: Scaffold(
        backgroundColor: const Color(0xFFF6FAFF),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF6FAFF),
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 18),
                          hintText: 'Search Students',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Color(0xFFF6FAFF)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF6FAFF),
                        ),
                      ),
                    ),
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
                  child: _tab == 'students'
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
  const TabChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = selected ? const Color(0xFF0F172A) : const Color(0xFF9CA3AF);
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
                fontSize: 18,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: c,
                decoration: TextDecoration.none,
              ),
            ),
            if (selected)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 8),
                height: 2, width: 28, color: c,
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
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (_, i) => items[i],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF60A5FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
          )),
    );
  }
}

/// 전체(Class) 카드 — 모든 학생 points 합계를 뱃지로 표시
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

        return Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              // ▷ 전체 학생 일괄 점수 부여 화면
              Navigator.pushNamed(context, '/profile/class');
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Stack(
                children: [
                  // 우상단: 전체 총점
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _Badge('$total'),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _AvatarPlaceholder(group: true),
                      SizedBox(height: 10),
                      Text(
                        'Class',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
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

/// 학생 카드
class _StudentCard extends StatelessWidget {
  const _StudentCard({super.key, required this.studentId, required this.data});
  final String studentId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] as String?) ?? '(no name)';

    // points: students/{id}.points (int) 또는 0
    final pointsStream = FirebaseFirestore.instance
        .collection('students')
        .doc(studentId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: pointsStream,
      builder: (_, snap) {
        final pts = (snap.data?.data()?['points'] as num?)?.toInt() ?? 0;

        return Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              // TODO: 학생 상세 (점수 부여/버튼 매핑) 페이지로 이동
              Navigator.pushNamed(context, '/profile/student',
                  arguments: {'id': studentId});
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Stack(
                children: [
                  Positioned(right: 0, top: 0, child: _Badge('$pts')),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _AvatarPlaceholder(),
                      const SizedBox(height: 10),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
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

/// 캐릭터 자리(이미지 교체 지점)
class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({this.group = false, super.key});
  final bool group;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Image.asset('assets/logo_bird.png', fit: BoxFit.contain),
    );
  }
}

/// Groups 탭은 자리만
class _GroupsPlaceholder extends StatelessWidget {
  const _GroupsPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Groups (coming soon)', style: TextStyle(color: Colors.grey)),
    );
  }
}