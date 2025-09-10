// lib/pages/profile/display_main_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/students_provider.dart';

class DisplayProfilePage extends StatefulWidget {
  const DisplayProfilePage({super.key});
  @override
  State<DisplayProfilePage> createState() => _DisplayMainPageState();
}

class _DisplayMainPageState extends State<DisplayProfilePage> {
  String _tab = 'students'; // 'students' | 'groups'
  String _query = '';

  int _colsForWidth(double w) {
    if (w >= 1500) return 6;
    if (w >= 1200) return 5;
    if (w >= 1000) return 4;
    if (w >= 700) return 3;
    return 2;
  }

  // 그대로 둠(디스플레이에서도 동일하게 동작 원한다는 요청이라 유지)
  Future<void> _addStudentDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
    if (ok == true) {
      final name = ctrl.text.trim();
      if (name.isNotEmpty) {
        await FirebaseFirestore.instance.collection('students').add({
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added: $name')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<StudentsProvider>();
    final width = MediaQuery.sizeOf(context).width;

    final students = sp.students.entries.map((e) => MapEntry(e.key, e.value)).toList()
      ..sort((a, b) => (a.value['name'] ?? '').toString().toLowerCase()
          .compareTo((b.value['name'] ?? '').toString().toLowerCase()));

    final filtered = (_query.trim().isEmpty)
        ? students
        : students.where((e) {
            final n = (e.value['name'] ?? '').toString().toLowerCase();
            return n.contains(_query.trim().toLowerCase());
          }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _addStudentDialog,
              icon: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.white),
              label: const Text(
                'Add Student',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF44A0FF),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            // Header (필요 시 검색 넣을 자리 – 현재 프레젠터와 동일하게 주석)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(color: Color(0xFFF6FAFF)),
              child: Row(children: const [Spacer()]),
            ),

            // Tabs
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

            // Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _tab == 'students'
                    ? _StudentsGrid(
                        cols: _colsForWidth(width),
                        students: filtered,
                        // 네비게이션만 display 경로로
                        goClass: () => Navigator.pushNamed(context, '/display/profile/class'),
                        goStudent: (id) => Navigator.pushNamed(
                          context,
                          '/display/profile/student',
                          arguments: {'id': id},
                        ),
                      )
                    : const _GroupsPlaceholder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ==== 공용 위젯 (프레젠터와 동일) ==== */

class TabChip extends StatelessWidget {
  const TabChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? const Color(0xFF001A36) : const Color(0xFFA2A2A2);
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
                fontSize: 18.3,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.0,
                fontFamily: 'Lufga',
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
  const _StudentsGrid({
    required this.cols,
    required this.students,
    required this.goClass,
    required this.goStudent,
  });
  final int cols;
  final List<MapEntry<String, Map<String, dynamic>>> students;
  final VoidCallback goClass;
  final void Function(String id) goStudent;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ClassCard(goClass: goClass),
      ...students.map((e) => _StudentCard(
            studentId: e.key,
            data: e.value,
            goStudent: () => goStudent(e.key),
          )),
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
      width: 30,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF44A0FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          fontFamily: 'Lufga',
          height: 1.0,
        ),
      ),
    );
  }
}

const kNameTextStyle = TextStyle(
  color: Color(0xFF001A36),
  fontSize: 20,
  fontWeight: FontWeight.w500,
  height: 1.0,
  fontFamily: 'Lufga',
);

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.goClass, super.key});
  final VoidCallback goClass;

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
          onTap: goClass, // display 경로로 이동
          child: Stack(
            children: [
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
                              width: 112,
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
                      Align(alignment: Alignment.topRight, child: _PointBubble(total)),
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

class _StudentCard extends StatelessWidget {
  const _StudentCard({super.key, required this.studentId, required this.data, required this.goStudent});
  final String studentId;
  final Map<String, dynamic> data;
  final VoidCallback goStudent;

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] as String?) ?? '(no name)';
    final pointsStream = FirebaseFirestore.instance.collection('students').doc(studentId).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: pointsStream,
      builder: (_, snap) {
        final pts = (snap.data?.data()?['points'] as num?)?.toInt() ?? 0;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: goStudent, // display 경로로 이동
          child: Stack(
            children: [
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
                              child: Image.asset('assets/logo_bird.png', fit: BoxFit.contain),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: SizedBox(
                                width: 112,
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
                      Align(alignment: Alignment.topRight, child: _PointBubble(pts)),
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
