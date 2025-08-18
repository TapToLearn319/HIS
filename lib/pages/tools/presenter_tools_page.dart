// lib/pages/tools/presenter_tools_page.dart
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../sidebar_menu.dart';
import 'timer/presenter_timer.dart';
import 'vote/vote_manager.dart';


// ▶ Tools 입장만으로 세션/좌석을 바로 준비시키기 위해 추가
import '../../provider/session_provider.dart';
import '../../provider/seat_map_provider.dart';

const String kHubId = 'hub-001';

class PresenterToolsPage extends StatefulWidget {
  const PresenterToolsPage({super.key});

  @override
  State<PresenterToolsPage> createState() => _PresenterToolsPageState();
}

class _PresenterToolsPageState extends State<PresenterToolsPage> {
  // 6개 카드
  final List<ToolItem> tools = [
    ToolItem(
      id: 'attendance',
      title: 'Attendance',
      description: 'Smart attendance tracking',
      icon: Icons.check_circle_outline,
      color: const Color(0xFFEF4444),
      bgColor: const Color(0xFFFEF2F2),
      usage: '',
      trending: false,
      route: '/tools/attendance',
    ),
    ToolItem(
      id: 'grouping',
      title: 'Random Grouping',
      description: 'Fair team distribution system',
      icon: Icons.groups_2_outlined,
      color: const Color(0xFF8B5CF6),
      bgColor: const Color(0xFFF5F3FF),
      usage: '',
      trending: false,
      route: '/tools/grouping',
    ),
    ToolItem(
      id: 'random_seat',
      title: 'Random Seat',
      description: 'Optimal seat arrangements',
      icon: Icons.location_on_outlined,
      color: const Color(0xFF6366F1),
      bgColor: const Color(0xFFEEF2FF),
      usage: '',
      trending: false,
      route: '/tools/random_seat',
    ),
    ToolItem(
      id: 'timer',
      title: 'Timer',
      description: 'Manage class time with precision',
      icon: Icons.timer_outlined,
      color: const Color(0xFF3B82F6),
      bgColor: const Color(0xFFEFF6FF),
      usage: '',
      trending: false,
      route: '/tools/timer',
    ),
    
    ToolItem(
      id: 'voting',
      title: 'Voting',
      description: 'Collect instant class feedback',
      icon: Icons.how_to_vote_outlined,
      color: const Color(0xFF10B981),
      bgColor: const Color(0xFFECFDF5),
      usage: '',
      trending: false,
      route: '/tools/voting',
    ),
    ToolItem(
      id: 'quiz',
      title: 'Quiz',
      description: 'Interactive learning assessments',
      icon: Icons.psychology_alt_outlined,
      color: const Color(0xFFF59E0B),
      bgColor: const Color(0xFFFFFBEB),
      usage: "",
      trending: false,
      route: '/tools/quiz',
    ),
    
    
  ];

  final List<QuickAction> quickActions = const [
    QuickAction('Start Timer', Icons.timer_outlined, Color(0xFF3B82F6)),
    QuickAction('Take Attendance', Icons.check_circle_outline, Color(0xFFEF4444)),
    QuickAction('Create Poll', Icons.how_to_vote_outlined, Color(0xFF10B981)),
    QuickAction('New Quiz', Icons.psychology_alt_outlined, Color(0xFFF59E0B)),
  ];

  bool _boundOnce = false; // didChangeDependencies 보강 바인딩 1회만

  @override
  void initState() {
    super.initState();
    // Tools 들어오자마자 세션 확정 + seatMap 구독
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSessionAndBindSeatMap();
    });
    
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 위젯 트리 재결합 타이밍 보강 (1회만)
    if (!_boundOnce) {
      _boundOnce = true;
      _ensureSessionAndBindSeatMap();
    }
  }

  Future<void> _ensureSessionAndBindSeatMap() async {
    final fs = FirebaseFirestore.instance;
    final session = context.read<SessionProvider>();
    final seatMap = context.read<SeatMapProvider>();

    // 1) 세션 있으면 seatMap만 보장
    if (session.sessionId != null) {
      try {
        await seatMap.bindSession(session.sessionId!);
      } catch (_) {}
      return;
    }

    // 2) 최근 세션 선택 (없으면 새로 생성)
    String? sid;
    try {
      final snap = await fs.collection('sessions').get();
      if (snap.docs.isNotEmpty) {
        final docs = [...snap.docs];
        docs.sort((a, b) {
          final ta = a.data()['updatedAt'] as Timestamp?;
          final tb = b.data()['updatedAt'] as Timestamp?;
          final va = ta?.millisecondsSinceEpoch ?? 0;
          final vb = tb?.millisecondsSinceEpoch ?? 0;
          return vb.compareTo(va);
        });
        sid = docs.first.id;
      }
    } catch (_) {
      sid = null;
    }
    sid ??= _defaultSessionId();

    // 3) 세션 문서 보장
    await fs.doc('sessions/$sid').set({
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'note': 'auto (tools entry)',
    }, SetOptions(merge: true));

    // 4) Provider 바인딩 + hub 동기화
    session.setSession(sid);
    try {
      await seatMap.bindSession(sid); // ← 여기에서 seatMap이 바로 실시간 구독 시작
    } catch (_) {}

    await fs.doc('hubs/$kHubId').set(
      {'currentSessionId': sid, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  String _defaultSessionId() {
    final now = DateTime.now();
    return '${now.toIso8601String().substring(0, 10)}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bool wide = width >= 1024;

    return AppScaffold(
      selectedIndex: 0,
      body: Scaffold(
        backgroundColor: const Color.fromARGB(255, 246, 250, 255),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              // Material(
              //   elevation: 1,
              //   child: Container(
              //     width: double.infinity,
              //     // decoration: const BoxDecoration(
              //     //   color: Colors.white,
              //     //   border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              //     // ),
              //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              //     child: SafeArea(
              //       bottom: false,
              //       child: Row(
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //         children: [
              //           // const Column(
              //           //   crossAxisAlignment: CrossAxisAlignment.start,
              //           //   children: [
              //           //     Text('Classroom Overview',
              //           //         style: TextStyle(
              //           //           fontSize: 18,
              //           //           fontWeight: FontWeight.w600,
              //           //           color: Color(0xFF111827),
              //           //         )),
              //           //     SizedBox(height: 2),
              //           //     Text('Manage your class efficiently',
              //           //         style: TextStyle(
              //           //           fontSize: 12,
              //           //           color: Color(0xFF6B7280),
              //           //         )),
              //           //   ],
              //           // ),
              //           // if (wide)
              //           //   SizedBox(
              //           //     width: 280,
              //           //     child: TextField(
              //           //       decoration: InputDecoration(
              //           //         isDense: true,
              //           //         hintText: 'Search tools...',
              //           //         prefixIcon: const Icon(Icons.search, size: 18),
              //           //         border: OutlineInputBorder(
              //           //           borderRadius: BorderRadius.circular(10),
              //           //         ),
              //           //         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              //           //         filled: true,
              //           //         fillColor: const Color(0xFFFAFAFA),
              //           //       ),
              //           //     ),
              //           //   ),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 20),

              // 퀵 액션
              // const Text('Quick Actions',
              //     style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              // const SizedBox(height: 12),
              // SingleChildScrollView(
              //   scrollDirection: Axis.horizontal,
              //   child: Row(
              //     children: quickActions
              //         .map(
              //           (a) => Padding(
              //             padding: const EdgeInsets.only(right: 10),
              //             child: OutlinedButton.icon(
              //               onPressed: () {},
              //               icon: Icon(a.icon, size: 18, color: a.color),
              //               label: Text(a.label),
              //               style: OutlinedButton.styleFrom(
              //                 foregroundColor: const Color(0xFF111827),
              //                 side: const BorderSide(color: Color(0xFFE5E7EB)),
              //               ),
              //             ),
              //           ),
              //         )
              //         .toList(),
              //   ),
              // ),
              // const SizedBox(height: 28),

              // 그리드 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Classroom Tools',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      )),
                ],
              ),
              const SizedBox(height: 12),

              // 6개 카드 그리드
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 1;
                  if (constraints.maxWidth >= 1200) {
                    crossAxisCount = 3;
                  } else if (constraints.maxWidth >= 700) {
                    crossAxisCount = 2;
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: tools.length,
                    itemBuilder: (context, i) {
                      final t = tools[i];
                      return ToolCard(
                        item: t,
                        onTap: () => Navigator.pushNamed(context, t.route),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------- Models -------------------------- */

class ToolItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String usage;
  final bool trending;
  final String route;

  ToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.usage,
    required this.trending,
    required this.route,
  });
}

class QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  const QuickAction(this.label, this.icon, this.color);
}

/* ------------------------ Tool Card ------------------------- */

class ToolCard extends StatelessWidget {
  final ToolItem item;
  final VoidCallback onTap;
  const ToolCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: item.bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 26),
                  ),
                  const Spacer(),
                  if (item.trending)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up, size: 14, color: Color(0xFF047857)),
                          SizedBox(width: 4),
                          Text('Trending',
                              style: TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.description,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(item.usage, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF374151)),
                    label: const Text('Open', style: TextStyle(color: Color(0xFF374151))),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 246, 250, 255),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
