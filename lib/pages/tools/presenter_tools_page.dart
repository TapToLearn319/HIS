
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
      description: 'Quickly record who’s present with a single click',
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
      description: 'Form random student groups instantly for activities',
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
      description: 'Assign seats randomly for a fresh classroom setup',
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
      description: 'Manage class time easily with a countdown timer',
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
      description: 'Gather live feedback and opinions from students',
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
      description: 'Make learning fun with interactive classroom quizzes',
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

  // ----------------- ✅ 카드 탭 가드: Random Seat 차단 -----------------
  Future<void> _onToolTap(BuildContext context, ToolItem t) async {
    if (t.id == 'random_seat') {
      final session = context.read<SessionProvider>();
      // 세션 바인딩이 아직 없으면 실제로 세션 존재 여부까지 확인
      if (session.sessionId == null) {
        try {
          final snap = await FirebaseFirestore.instance.collection('sessions').limit(1).get();
          final hasAnySession = snap.docs.isNotEmpty;
          if (!hasAnySession) {
            await _showNeedSessionDialog(context);
            return; // ▶ 진입 차단
          }
        } catch (_) {
          // 조회 에러 시도 세션이 확실치 않으면 진입 막고 안내
          await _showNeedSessionDialog(context);
          return;
        }
      }
    }
    // 통과 시 정상 이동
    if (!mounted) return;
    Navigator.pushNamed(context, t.route);
  }

  Future<void> _showNeedSessionDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('세션이 필요해요'),
        content: const Text('랜덤 좌석 기능을 사용하려면 먼저 세션을 생성하세요.\n상단의 Session 버튼에서 새 세션을 만들 수 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
        ],
      ),
    );
  }
  // --------------------------------------------------------------------

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
                        onTap: () => _onToolTap(context, t), // ▶ 여기만 변경
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
        child: LayoutBuilder(
          builder: (context, cc) {
            // ▶ 기준(디자인) 크기 설정: 카드 가로 360, 세로 220 가정
            const baseW = 360.0;
            const baseH = 220.0;

            // 현재 타일 크기 대비 스케일
            final sx = cc.maxWidth / baseW;
            final sy = cc.maxHeight / baseH;
            final s = (sx < sy ? sx : sy).clamp(0.85, 1.8);

            // 스케일 적용한 사이즈들
            final pad = 16.0 * s;
            final iconBox = 48.0 * s;
            final iconSize = 26.0 * s;
            final titleFs = 16.0 * s;
            final descFs  = 13.0 * s;
            final usageFs = 12.0 * s;
            final gapLg   = 14.0 * s;
            final gapSm   = 6.0 * s;
            final btnPadH = 10.0 * s;
            final btnPadV = 6.0 * s;
            final trendIcon = 14.0 * s;
            final chipPadH  = 8.0 * s;
            final chipPadV  = 4.0 * s;
            final chipFs    = 11.0 * s;

            return Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: iconBox,
                        height: iconBox,
                        decoration: BoxDecoration(
                          color: item.bgColor,
                          borderRadius: BorderRadius.circular(12 * s),
                        ),
                        child: Icon(item.icon, color: item.color, size: iconSize),
                      ),
                      const Spacer(),
                      if (item.trending)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: chipPadH, vertical: chipPadV),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up,
                                  size: trendIcon, color: const Color(0xFF047857)),
                              SizedBox(width: 4 * s),
                              Text(
                                'Trending',
                                style: TextStyle(
                                  color: const Color(0xFF047857),
                                  fontSize: chipFs,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: gapLg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: titleFs,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                  SizedBox(height: gapSm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.description,
                      style: TextStyle(
                        fontSize: descFs,
                        height: 1.4,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        item.usage,
                        style: TextStyle(fontSize: usageFs, color: const Color(0xFF6B7280)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onTap,
                        icon: Icon(Icons.arrow_forward,
                            size: 16 * s, color: const Color(0xFF374151)),
                        label: Text('Open',
                            style: TextStyle(
                              fontSize: 13 * s,
                              color: const Color(0xFF374151),
                            )),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 246, 250, 255),
                          padding: EdgeInsets.symmetric(
                            horizontal: btnPadH, vertical: btnPadV),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8 * s),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}