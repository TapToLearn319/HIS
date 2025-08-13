import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../sidebar_menu.dart'; // AppScaffold
import '../../login.dart';
import '../../provider/students_provider.dart';

const String kHubId = 'hub-001'; // 현재 허브(교실) ID

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

  // 최근 성공한 링크 표시용 (studentId-slotIndex)
  String? _flashKey;

  // ─────────── UI helpers ───────────

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

  void _safeSnack(String msg) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } else {
      debugPrint('[SNACK fallback] $msg');
    }
  }

  Future<String?> _inputText({
    required String title,
    required String label,
    String? initial,
    String? hint,
  }) async {
    final c = TextEditingController(text: initial ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true) {
      final v = c.text.trim();
      return v.isEmpty ? null : v;
    }
    return null;
  }

  // ─────────── Sanity (옵션) ───────────

  Future<void> _sanityWrite() async {
    try {
      final fs = FirebaseFirestore.instance;
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await fs.collection('zzz_sanity').doc(id).set(<String, Object?>{
        'ok': true,
        'at': FieldValue.serverTimestamp(),
      });
      debugPrint('sanity ok');
      _safeSnack('Sanity write OK');
    } on FirebaseException catch (e) {
      debugPrint('sanity FirebaseException: code=${e.code}, msg=${e.message}');
      _safeSnack('Sanity write failed: ${e.code}');
    } catch (e, st) {
      debugPrint('sanity generic: $e\n$st');
      _safeSnack('Sanity write failed (client).');
    }
  }

  // ─────────── Device mapping helpers ───────────

  String? _sanitizeDeviceId(String? raw) {
    final id = (raw ?? '').trim();
    if (id.isEmpty) return null;
    const bad = ['/', '#', '?', '[', ']'];
    if (bad.any(id.contains)) return null;
    return id;

  }

  String _last5DigitsFromSerial(String? id) {
  if (id == null || id.isEmpty) return '';
  final digitsOnly = id.replaceAll(RegExp(r'\D'), ''); // 숫자만 남기기
  if (digitsOnly.isEmpty) return '';
  final start = digitsOnly.length > 5 ? digitsOnly.length - 5 : 0;
  return digitsOnly.substring(start); // 마지막 5자리
}

  Future<void> _writeDeviceMapping({
    required FirebaseFirestore fs,
    required String deviceId,
    required String studentId,
    required String slotIndex, // "1" | "2"
  }) async {
    final ref = fs.collection('devices').doc(deviceId);
    final Map<String, Object?> payload = {
      'studentId': studentId,
      'slotIndex': slotIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await ref.set(payload);
  }

  // ─────────── Students actions ───────────

  Future<void> _addStudent() async {
    final name = await _inputText(
      title: 'Add student',
      label: 'Student name',
      hint: 'e.g., Taeyeon Kim',
    );
    if (name == null) return;

    final fs = FirebaseFirestore.instance;
    try {
      final doc = fs.collection('students').doc();
      final Map<String, Object?> payload = {
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await doc.set(payload);
      _safeSnack('Added student: $name');
    } on FirebaseException catch (e) {
      debugPrint('Firestore set error(students): code=${e.code}, message=${e.message}');
      _safeSnack('Write failed: ${e.code}');
    } catch (e, st) {
      debugPrint('Generic set error(students): $e\n$st');
      _safeSnack('Write failed (client).');
    }
  }

  Future<void> _editStudentName({
    required String studentId,
    required String currentName,
  }) async {
    final newName = await _inputText(
      title: 'Edit student',
      label: 'Student name',
      initial: currentName,
    );
    if (newName == null) return;

    try {
      await FirebaseFirestore.instance.collection('students').doc(studentId).set(
        <String, Object?>{
          'name': newName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _safeSnack('Updated: $newName');
    } on FirebaseException catch (e) {
      debugPrint('Firestore set error(update student): code=${e.code}, message=${e.message}');
      _safeSnack('Update failed: ${e.code}');
    } catch (e, st) {
      debugPrint('Generic set error(update student): $e\n$st');
      _safeSnack('Update failed (client).');
    }
  }

  Future<void> _deleteStudent({required String studentId, required String name}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete student'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('students').doc(studentId).delete();
      _safeSnack('Deleted: $name');
    } on FirebaseException catch (e) {
      debugPrint('Firestore delete error(students): code=${e.code}, message=${e.message}');
      _safeSnack('Delete failed: ${e.code}');
    } catch (e, st) {
      debugPrint('Generic delete error(students): $e\n$st');
      _safeSnack('Delete failed (client).');
    }
  }

  Future<void> registerDeviceForStudent({
  required String deviceId,   // 최근 로그에서 잡아온 시리얼
  required String studentId,  // students/{autoId}의 문서 ID
  required String slotIndex,  // "1" 또는 "2"
}) async {
  final fs = FirebaseFirestore.instance;
  await fs.doc('devices/$deviceId').set(
    {
      'studentId': studentId,
      'slotIndex': slotIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}

  // ─────────── Auto-link last pressed button ───────────

  Future<void> _assignLastPressedButtonToSlot({
    required String studentId,
    required String slotIndex, // "1" or "2"
  }) async {
    final fs = FirebaseFirestore.instance;

    try {
      final hub = await fs.collection('hubs').doc(kHubId).get();
      final sid = hub.data()?['currentSessionId'] as String?;
      if (sid == null || sid.isEmpty) {
        _safeSnack('No active session on this hub.');
        return;
      }

      final q = await fs
          .collection('sessions')
          .doc(sid)
          .collection('events')
          .orderBy('ts', descending: true)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        _safeSnack('No recent button event found.');
        return;
      }

      final data = q.docs.first.data();
      final deviceId = _sanitizeDeviceId(data['deviceId'] as String?);
      if (deviceId == null) {
        _safeSnack('Invalid deviceId in latest event.');
        return;
      }

      await _writeDeviceMapping(
        fs: fs,
        deviceId: deviceId,
        studentId: studentId,
        slotIndex: slotIndex,
      );

      // ✅ UI 하이라이트(초록 체크) 1.2초
      setState(() => _flashKey = '$studentId-$slotIndex');
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _flashKey == '$studentId-$slotIndex') {
          setState(() => _flashKey = null);
        }
      });

      _safeSnack('Linked $deviceId (slot $slotIndex)');
    } on FirebaseException catch (e) {
      debugPrint('Firestore set error(devices): code=${e.code}, message=${e.message}');
      _safeSnack('Write failed: ${e.code}');
    } catch (e, st) {
      debugPrint('Generic set error(devices): $e\n$st');
      _safeSnack('Write failed (client).');
    }
  }

  // ─────────── Slot chip ───────────

  Widget _slotChip(String slotIndex, String? deviceId) {
  final has = deviceId != null && deviceId.isNotEmpty;
  final last5 = _last5DigitsFromSerial(deviceId);
  final labelText = (has && last5.isNotEmpty) ? last5 : 'Not set';

  return Chip(
    avatar: CircleAvatar(
      radius: 10,
      child: Text(slotIndex, style: const TextStyle(fontSize: 12)),
    ),
    label: Text(labelText, style: const TextStyle(fontFamily: 'monospace')),
    backgroundColor: (has && last5.isNotEmpty) ? Colors.green.shade50 : Colors.grey.shade200,
    side: BorderSide(color: (has && last5.isNotEmpty) ? Colors.green : Colors.grey.shade400),
    visualDensity: VisualDensity.compact,
  );
}


  // ─────────── Build ───────────

  @override
  Widget build(BuildContext context) {
    final studentsProvider = context.watch<StudentsProvider>();
    final entries = studentsProvider.students.entries.toList()
      ..sort((a, b) {
        final an = (a.value['name'] as String? ?? '').toLowerCase();
        final bn = (b.value['name'] as String? ?? '').toLowerCase();
        return an.compareTo(bn);
      });

    return AppScaffold(
      selectedIndex: 1,
      body: Scaffold( // ✅ 로컬 Scaffold 추가: SnackBar 안정화
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                        color: Colors.black,
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _sanityWrite,
                          icon: const Icon(Icons.health_and_safety),
                          label: const Text('Test write'),
                        ),
                        const SizedBox(width: 8),
                        if (selectedCategory == 'student')
                          OutlinedButton.icon(
                            onPressed: _addStudent,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add student'),
                          ),
                        const SizedBox(width: 8),
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
                  ],
                ),
              ),

              // Tabs
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

              // Section title
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

              // Grid
              Expanded(
                child: GridView.count(
                  padding: const EdgeInsets.all(12),
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3 / 1.7,
                  children: selectedCategory == 'student'
                      ? entries.map((e) {
                          final studentId = e.key;
                          final name = (e.value['name'] as String?) ?? '(no name)';
                          final color = getCategoryColor('student');
                          final fk1 = '$studentId-1';
                          final fk2 = '$studentId-2';

                          return Card(
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: color, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              children: [
                                // Settings icon (top-right)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: IconButton(
                                    icon: const Icon(Icons.settings),
                                    tooltip: 'Edit / Delete',
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (_) => SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons.edit),
                                                title: const Text('Edit name'),
                                                onTap: () async {
                                                  Navigator.pop(context);
                                                  await _editStudentName(
                                                    studentId: studentId,
                                                    currentName: name,
                                                  );
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.delete, color: Colors.red),
                                                title: const Text('Delete student'),
                                                onTap: () async {
                                                  Navigator.pop(context);
                                                  await _deleteStudent(
                                                    studentId: studentId,
                                                    name: name,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                // Body
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Name
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            name,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ▼ devices/{device} 실시간 매핑 표시 (Slot 1/2)
                                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                        stream: FirebaseFirestore.instance
                                            .collection('devices')
                                            .where('studentId', isEqualTo: studentId)
                                            .snapshots(),
                                        builder: (context, snap) {
                                          String? s1;
                                          String? s2;
                                          if (snap.hasData) {
                                            for (final d in snap.data!.docs) {
                                              final si = d.data()['slotIndex']?.toString();
                                              if (si == '1') s1 = d.id;
                                              if (si == '2') s2 = d.id;
                                            }
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                _slotChip('1', s1),
                                                _slotChip('2', s2),
                                              ],
                                            ),
                                          );
                                        },
                                      ),

                                      // Action buttons (auto-link last pressed)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => _assignLastPressedButtonToSlot(
                                              studentId: studentId,
                                              slotIndex: '1',
                                            ),
                                            icon: const Icon(Icons.link),
                                            label: const Text('Button 1'),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => _assignLastPressedButtonToSlot(
                                              studentId: studentId,
                                              slotIndex: '2',
                                            ),
                                            icon: const Icon(Icons.link),
                                            label: const Text('Button 2'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // ✅ 링크 성공 오버레이 (초록 체크) — 1.2초 표시
                                if (_flashKey == fk1 || _flashKey == fk2)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: AnimatedOpacity(
                                        opacity: 1.0,
                                        duration: const Duration(milliseconds: 150),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Center(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle, color: Colors.green, size: 24),
                                                SizedBox(width: 8),
                                                Text('Linked!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList()
                      : quizItems.map((item) {
                          final color = getCategoryColor('quiz');
                          return Card(
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: color, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () {},
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.apps, size: 44, color: Colors.black26),
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
      ),
    );
  }
}
