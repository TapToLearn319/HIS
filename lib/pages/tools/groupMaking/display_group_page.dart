import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../main.dart';
import 'dart:async';

class GroupDisplayPage extends StatefulWidget {
  const GroupDisplayPage({super.key});

  @override
  State<GroupDisplayPage> createState() => _GroupDisplayPageState();
}

class _GroupDisplayPageState extends State<GroupDisplayPage> {
  String title = 'Find your Team !';
  List<List<String>> groups = const [];
  StreamSubscription? _sub;
  @override
void initState() {
  super.initState();

  channel.onMessage.listen((msg) {
    try {
      final raw = msg.data;
      final data =
          (raw is String) ? jsonDecode(raw) : raw as Map<String, dynamic>;

      final type = data['type'];

      if (type == 'grouping_clear') {
        if (mounted) {
          setState(() {
            title = 'Find your Team !';
            groups = const [];
          });
        }
        return;
      }

      // 🔵 1) 그룹 결과 표시
      if (type == 'grouping_result') {
        final newTitle = data['title'] ?? 'Find your Team !';

        final List<List<String>> parsed = [];
        final rawGroups = data['groups'];
        if (rawGroups is List) {
          for (final g in rawGroups) {
            if (g is List) {
              parsed.add(g.map((e) => e.toString()).toList());
            }
          }
        }

        if (mounted) {
          setState(() {
            title = newTitle;
            groups = parsed;
          });
        }
        return;
      }

      // 🔵 2) Presenter가 Hide 눌렀을 때
      if (type == 'grouping_hide') {
        if (mounted) {
          setState(() {
            title = 'Find your Team !';
            groups = const [];
          });
        }
        return;
      }

      // 🔵 3) grouping 화면 진입 또는 Clear
      if ((type == 'tool_mode' && data['mode'] == 'grouping') ||
          type == 'grouping_clear') {
        if (mounted) {
          setState(() {
            title = 'Find your Team !';
            groups = const [];
          });
        }
        return;
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  });
}


  @override
  Widget build(BuildContext context) {
    const _ink = Color(0xFF001A36);
    const _inkSub = Color(0xFF000000);
    const _surface = Color(0xFFF2F7FD);
    const _paper = Colors.white;
    const _stroke = Color(0xFFE3E9F2);

    final w = MediaQuery.sizeOf(context).width;
    final cols =
        w >= 1280
            ? 4
            : w >= 992
            ? 3
            : w >= 640
            ? 2
            : 1;

    return Scaffold(
      appBar: AppBar(
        elevation: 0, backgroundColor: Color(0xFFF6FAFF),
        automaticallyImplyLeading: false,
        leading: const SizedBox.shrink(),
      ),
      backgroundColor: Color(0xFFF6FAFF),   // 수정 완료
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6ED3FF).withValues(alpha: 0.2),   // 수정 완료
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups_outlined,
                      size: 45,
                      color: Color(0xFF6ED3FF),   // 수정 완료
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 44,
                        height: 1.15,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child:
                    groups.isEmpty
                        ? const Center(
                          child: Text(
                            'Waiting for groups...',
                            style: TextStyle(
                              fontSize: 20,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        )
                        : GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                                childAspectRatio: 320 / 360,
                              ),
                          itemCount: groups.length,
                          itemBuilder:
                              (_, i) =>
                                  _TeamCard(index: i + 1, members: groups[i]),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.index, required this.members});
  final int index;
  final List<String> members;

  @override
  Widget build(BuildContext context) {
    const _ink = Color(0xFF0B2239);
    const _inkSub = Color(0xFF1B385A);
    const _paper = Colors.white;
    const _stroke = Color(0xFFE3E9F2);

    return Container(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD2D2D2)),   // 수정 완료
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        children: [
          Text(
            'Team $index',
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w500,
              color: Color(0xFF001A36),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _stroke, thickness: 2),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 46,   // ← ★ 각 이름 셀의 높이(44~50 사이로 취향 조정)
                mainAxisSpacing: 6,   // ← ★ 행 간격(세로 간격)
                crossAxisSpacing: 12,  // 셀 가로:세로 비 (글자 높이에 맞게 약간 조정)
              ),
              itemCount: members.length,
              itemBuilder: (_, i) => Center(
                child: Text(
                  members[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF001A36),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
