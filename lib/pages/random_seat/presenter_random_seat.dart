// lib/pages/tools/random_seat_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Providers
import '../../provider/session_provider.dart';
import '../../provider/seat_map_provider.dart';
import '../../provider/students_provider.dart';

const String kHubId = 'hub-001';

class RandomSeatPage extends StatefulWidget {
  const RandomSeatPage({super.key});

  @override
  State<RandomSeatPage> createState() => _RandomSeatPageState();
}

class _RandomSeatPageState extends State<RandomSeatPage> {
  String? _lastBoundSid; // 현재 페이지에서 마지막으로 bind한 세션ID (중복 바인딩 방지)
  bool _working = false;

  // 좌석 키: "1".."24"
  String _seatKey(int index) => '${index + 1}';

  @override
  void initState() {
    super.initState();
    // 첫 프레임 이후에 현재 세션으로 seatMap 구독 시도
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBind());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider 트리 갱신 타이밍에 한 번 더 보장
    _ensureBind();
  }

  Future<void> _ensureBind() async {
    if (!mounted) return;
    final session = context.read<SessionProvider>();
    final seatMap = context.read<SeatMapProvider>();
    final sid = session.sessionId;

    // 세션이 아직 없으면 잠깐 대기 (Tools에서 곧 설정되므로 다음 프레임에서 한 번 더 시도)
    if (sid == null) {
      // 다음 프레임에 재시도
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBind());
      return;
    }

    if (_lastBoundSid == sid) return; // 이미 바인딩한 세션이면 패스

    try {
      await seatMap.bindSession(sid);
      _lastBoundSid = sid;
      // hub도 최신 세션으로 동기화(옵션)
      await FirebaseFirestore.instance.doc('hubs/$kHubId').set(
        {'currentSessionId': sid, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {
      // 바인딩 실패시에도 다음 프레임 재시도 (일시적인 순서 문제 대비)
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBind());
    }
  }

  // 랜덤 섞기 (Empty 제외)
  Future<void> _randomize() async {
  final seatMapProvider = context.read<SeatMapProvider>();
  final studentsProvider = context.read<StudentsProvider>();
  final current = Map<String, String?>.from(seatMapProvider.seatMap);

  // 1) Empty 제외하고 현재 배정된 학생만 모으기
  final assignedSeatKeys = <String>[];
  final assignedStudentIds = <String>[];
  for (int i = 0; i < 24; i++) {
    final key = _seatKey(i);
    final sid = current[key];
    if (sid != null && sid.isNotEmpty) {
      assignedSeatKeys.add(key);
      assignedStudentIds.add(sid);
    }
  }
  if (assignedStudentIds.isEmpty) {
    _snack('배정된 학생이 없습니다.');
    return;
  }

  // 2) 학생 id 셔플
  assignedStudentIds.shuffle(Random());

  // 3) 업데이트 맵 구성 (Empty 좌석은 건들지 않음)
  final Map<String, String?> updates = {};
  for (int i = 0; i < assignedSeatKeys.length; i++) {
    updates[assignedSeatKeys[i]] = assignedStudentIds[i];
  }

  // 4) ✅ 한 번에 커밋 + 한 번만 notify → UI가 동시에 바뀜
  await seatMapProvider.assignSeatsBulk(updates);

  _snack('랜덤 배치가 적용되었습니다.');
}

  // 저장: 현재 좌석 상태로 새 세션을 만들고, 그 세션을 현재세션으로 전환
  Future<void> _saveAsNewSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('저장'),
        content: const Text('정말 저장하시겠습니까? 현재 좌석 배치를 새로운 세션으로 저장하고 전환합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('저장')),
        ],
      ),
    );
    if (ok != true) return;

    if (_working) return;
    setState(() => _working = true);

    try {
      final session = context.read<SessionProvider>();
      final oldSid = session.sessionId;
      final seatMap = context.read<SeatMapProvider>().seatMap;

      // 새 세션 ID
      final newSid = _defaultSessionId();

      final fs = FirebaseFirestore.instance;

      // 새 세션 문서
      await fs.doc('sessions/$newSid').set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'note': 'random seat saved from ${oldSid ?? "(unknown)"}',
      }, SetOptions(merge: true));

      // 좌석 맵 복사
      final batch = fs.batch();
      seatMap.forEach((seatNo, studentId) {
        final ref = fs.doc('sessions/$newSid/seatMap/$seatNo');
        batch.set(ref, {'studentId': studentId});
      });
      await batch.commit();

      // 현재 세션 전환 + SeatMapProvider 바인딩
      session.setSession(newSid);
      _lastBoundSid = null; // 새 세션으로 다시 bind 시도
      await context.read<SeatMapProvider>().bindSession(newSid);

      // hub도 동기화
      await fs.doc('hubs/$kHubId').set(
        {'currentSessionId': newSid, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      _snack('저장 완료: $newSid');
    } catch (e) {
      _snack('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _defaultSessionId() {
    final now = DateTime.now();
    return '${now.toIso8601String().substring(0, 10)}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    (m ?? ScaffoldMessenger.of(context))
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final seatMapProvider = context.watch<SeatMapProvider>();
    final studentsProvider = context.watch<StudentsProvider>();
    final seatMap = seatMapProvider.seatMap; // 실시간 구독

    return Scaffold(
      appBar: AppBar(
        title: const Text('Random Seat'),
        actions: [
          TextButton.icon(
            onPressed: _working ? null : _randomize,
            icon: const Icon(Icons.shuffle),
            label: const Text('Random'),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: _working ? null : _saveAsNewSession,
            icon: const Icon(Icons.save_alt),
            label: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              itemCount: 24,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6, // 6 columns
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8, // 4 rows 총 24개
              ),
              itemBuilder: (context, index) {
                final key = _seatKey(index);
                final sid = seatMap[key];
                final name = (sid == null || sid.isEmpty)
                    ? 'Empty'
                    : studentsProvider.displayName(sid);

                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6063C6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),

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
    );
  }
}
