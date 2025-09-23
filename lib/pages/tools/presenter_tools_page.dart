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

const double _kGutter = 16.0;
const double _kToolsAspect = 1.6;

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
      description: 'Track and record student presence easily',
      icon: Icons.front_hand_outlined,
      color: const Color(0xFFFF9A6E),
      bgColor: const Color(0x33FF9A6E),
      usage: '',
      trending: false,
      route: '/tools/attendance',
    ),
    ToolItem(
      id: 'grouping',
      title: 'Random Grouping',
      description: 'Create fair, balanced student groups',
      icon: Icons.groups_outlined,
      color: const Color(0xFF6ED3FF),
      bgColor: const Color(0x336ED3FF),
      usage: '',
      trending: false,
      route: '/tools/grouping',
    ),
    ToolItem(
      id: 'random_seat',
      title: 'Seating Chart',
      description: 'Organize and visualize classroom seating',
      icon: Icons.location_on_outlined,
      color: const Color(0xFFFF96F1),
      bgColor: const Color(0x33FF96F1),
      usage: '',
      trending: false,
      route: '/tools/random_seat',
    ),
    ToolItem(
      id: 'timer',
      title: 'Timer',
      description: 'Manage class time effeciantly',
      icon: Icons.alarm_outlined,
      color: const Color(0xFF9A6EFF),
      bgColor: const Color(0x339A6EFF),
      usage: '',
      trending: false,
      route: '/tools/timer',
    ),
    ToolItem(
      id: 'voting',
      title: 'Voting',
      description: 'Gather quick student opinions and decisions',
      icon: Icons.check_box_outlined,
      color: const Color(0xFFFBD367),
      bgColor: const Color(0x33FBD367),
      usage: '',
      trending: false,
      route: '/tools/voting',
    ),
    ToolItem(
      id: 'quiz',
      title: 'Quiz',
      description: 'Engage students with interactive questions',
      icon: Icons.stars,
      color: const Color(0xFFA9E817),
      bgColor: const Color(0x33A9E817),
      usage: "",
      trending: false,
      route: '/tools/quiz',
    ),
  ];

  final List<QuickAction> quickActions = const [
    QuickAction('Start Timer', Icons.timer_outlined, Color(0xFF3B82F6)),
    QuickAction(
      'Take Attendance',
      Icons.check_circle_outline,
      Color(0xFFEF4444),
    ),
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

    await fs.doc('hubs/$kHubId').set({
      'currentSessionId': sid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
          final snap =
              await FirebaseFirestore.instance
                  .collection('sessions')
                  .limit(1)
                  .get();
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
      builder:
          (_) => AlertDialog(
            title: const Text('세션이 필요해요'),
            content: const Text(
              '랜덤 좌석 기능을 사용하려면 먼저 세션을 생성하세요.\n상단의 Session 버튼에서 새 세션을 만들 수 있어요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  Widget _beforeClassSectionGrid(
    BuildContext context, {
    required int crossAxisCount,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount * 2,
        crossAxisSpacing: _kGutter,
        mainAxisSpacing: _kGutter,
        mainAxisExtent: 80,
      ),
      itemCount: 2,
      itemBuilder: (_, i) {
        if (i == 0) {
          return _bcCard(
            label: 'Button Test',
            icon: Icons.radio_button_checked,
            iconColor: const Color(0xFF5F5F5F),
            onTap: () => Navigator.pushNamed(context, '/tools/button_test'),
          );
        }
        return _bcCard(
          label: 'Warm-up',
          icon: Icons.mood,
          iconColor: const Color(0xFF44A0FF),
          onTap: () {}, // TODO
        );
      },
    );
  }

  // 버튼 카드 하나 (크기 지정 X: 그리드가 크기 결정)
  Widget _bcCard({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: iconColor, size: 40),
      label: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF001A36),
          fontSize: 30,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFD2D2D2), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bool wide = width >= 1024;

    return AppScaffold(
      selectedIndex: 0,
      body: Scaffold(
        backgroundColor: const Color(0xFFF6FAFF),
        body: LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 1;
            if (constraints.maxWidth >= 1200) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth >= 700) {
              crossAxisCount = 2;
            }
            final double cardW =
                (constraints.maxWidth - (crossAxisCount - 1) * _kGutter) /
                crossAxisCount;
            final double cardH = cardW / _kToolsAspect;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 77),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Before Class
                  const Text(
                    'Before Class',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF001A36),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _beforeClassSectionGrid(
                    context,
                    crossAxisCount: crossAxisCount,
                  ),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Classroom Tools',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 6개 카드 그리드
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: _kGutter,
                      mainAxisSpacing: _kGutter,
                      childAspectRatio: _kToolsAspect,
                    ),
                    itemCount: tools.length,
                    itemBuilder:
                        (context, i) => ToolCard(
                          item: tools[i],
                          onTap: () => _onToolTap(context, tools[i]),
                        ),
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
            const baseW = 360.0;
            const baseH = 220.0;
            final sx = cc.maxWidth / baseW;
            final sy = cc.maxHeight / baseH;
            final s = (sx < sy ? sx : sy).clamp(0.85, 1.8);

            final pad = 16.0 * s;
            final iconBox = 48.0 * s;
            final iconSize = 26.0 * s;
            final titleFs = 21.0 * s;
            final descFs = 17.0 * s;
            final usageFs = 12.0 * s;
            final gapLg = 14.0 * s;
            final gapSm = 6.0 * s;
            final chipPadH = 8.0 * s;
            final chipPadV = 4.0 * s;
            final chipFs = 11.0 * s;
            final topGap = 8.0 * s;

            return Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 상단: 아이콘 · (spacer) · trending · Open ────────────────
                  Row(
                    children: [
                      Container(
                        width: iconBox,
                        height: iconBox,
                        decoration: BoxDecoration(
                          color: item.bgColor,
                          borderRadius: BorderRadius.circular(12 * s),
                        ),
                        child: Icon(
                          item.icon,
                          color: item.color,
                          size: iconSize,
                        ),
                      ),
                      const Spacer(),
                      if (item.trending) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: chipPadH,
                            vertical: chipPadV,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 14.0 * s,
                                color: const Color(0xFF047857),
                              ),
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
                        SizedBox(width: 8 * s),
                      ],
                      _OpenButton(scale: s, onTap: onTap), // ▲ 상단 우측 버튼
                    ],
                  ),
                  SizedBox(height: topGap),

                  // 제목 / 설명
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: titleFs,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: gapSm),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: descFs,
                      height: 1.4,
                      color: const Color(0xFF6B7280),
                    ),
                  ),

                  const Spacer(),

                  // 하단: usage만 (버튼은 제거됨)
                  Text(
                    item.usage,
                    style: TextStyle(
                      fontSize: usageFs,
                      color: const Color(0xFF6B7280),
                    ),
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

class _OpenButton extends StatelessWidget {
  final double scale;
  final VoidCallback onTap;
  const _OpenButton({required this.scale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = 13.0 * scale;
    final hPad = 12.0 * scale;
    final vPad = 5.0 * scale;

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFF44A0FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: EdgeInsets.zero,
        minimumSize: Size(60 * scale, 30 * scale),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Open >',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11 * scale,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      ),
    );
  }
}
