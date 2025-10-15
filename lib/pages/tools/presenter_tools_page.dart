// lib/pages/tools/presenter_tools_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../sidebar_menu.dart';
import 'timer/presenter_timer.dart';
import 'vote/vote_manager.dart';

// ▶ Tools 입장만으로 세션/좌석을 바로 준비시키기 위해 추가
import '../../provider/session_provider.dart';
import '../../provider/seat_map_provider.dart';
import '../../provider/hub_provider.dart'; // ✅ 허브 프로바이더 추가

const double _kGutter = 16.0;
const double _kToolsAspect = 1.6;

class PresenterToolsPage extends StatefulWidget {
  const PresenterToolsPage({super.key});

  @override
  State<PresenterToolsPage> createState() => _PresenterToolsPageState();
}

class _PresenterToolsPageState extends State<PresenterToolsPage> {
  bool _displayReady = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _readySub;

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
      description: 'Manage class time efficiently',
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
    ToolItem(
      id: 'random_draw',
      title: 'Random draw',
      description: 'Select students at random',
      icon: Icons.check_box_outlined,
      color: const Color(0xFF44DAAD),
      bgColor: const Color(0x3344DAAD),
      usage: "",
      trending: false,
      route: '/tools/draw',
    ),
  ];

  final List<QuickAction> quickActions = const [
    QuickAction('Start Timer', Icons.timer_outlined, Color(0xFF3B82F6)),
    QuickAction('Take Attendance', Icons.check_circle_outline, Color(0xFFEF4444)),
    QuickAction('Create Poll', Icons.how_to_vote_outlined, Color(0xFF10B981)),
    QuickAction('New Quiz', Icons.psychology_alt_outlined, Color(0xFFF59E0B)),
  ];

  bool _boundOnce = false;

  @override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _ensureSessionAndBindSeatMap();

    // ✅ hubId 준비될 때까지 대기
    final hub = context.read<HubProvider>();
    if (hub.hubId == null || hub.hubId!.isEmpty) {
      debugPrint('⏳ Waiting for hubId to be set...');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // ✅ hubId가 준비된 후에만 실행
    if (mounted && hub.hubId != null && hub.hubId!.isNotEmpty) {
      _listenDisplayReady();
    }
  });
}

void _listenDisplayReady() async {
  final hubId = context.read<HubProvider>().hubId;
  if (hubId == null || !mounted) return;
  debugPrint('✅ Start listening displayStatus for hubId=$hubId');

  final fs = FirebaseFirestore.instance;
  final docRef = fs
      .collection('hubs')
      .doc(hubId)
      .collection('displayStatus')
      .doc('display-main');

  try {
    final docSnap = await docRef.get();
    if (!docSnap.exists) {
      await docRef.set({
        'ready': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('🆕 Created display-main doc');
    } else {
      // ✅ 기존 문서가 있으면 상태만 갱신
      await docRef.set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
  } catch (e) {
    debugPrint('⚠️ Firestore init failed: $e');
    return;
  }

  _readySub?.cancel();
  _readySub = docRef.snapshots().listen((snap) {
    final data = snap.data();
    final ready = data?['ready'] == true;
    debugPrint('📡 Display ready = $ready');
    if (mounted) setState(() => _displayReady = ready);
  });
}



  @override
  void dispose() {
    _readySub?.cancel();
    super.dispose();
  }
  String? _currentHubId;
 // ✅ 추가 (State 클래스 맨 위에 선언)

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (!_boundOnce) {
    _boundOnce = true;
    _ensureSessionAndBindSeatMap();
  }
}



  Future<void> _ensureSessionAndBindSeatMap() async {
    final fs = FirebaseFirestore.instance;
    final hubId = context.read<HubProvider>().hubId; // ✅ 여기서도 Provider 사용
    if (hubId == null) return;

    final session = context.read<SessionProvider>();
    final seatMap = context.read<SeatMapProvider>();

    final hubRef = fs.doc('hubs/$hubId');
    final hubSnap = await hubRef.get();
    final hubSid = hubSnap.data()?['currentSessionId'] as String?;
    if (hubSid != null && hubSid.isNotEmpty) {
      if (session.sessionId != hubSid) session.setSession(hubSid);
      try { await seatMap.bindSession(hubSid); } catch (_) {}
      return;
    }

    if (session.sessionId != null) {
      final sid = session.sessionId!;
      try { await seatMap.bindSession(sid); } catch (_) {}
      await hubRef.set({
        'currentSessionId': sid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    String? sid;
    try {
      final hubSess = await fs
          .collection('hubs/$hubId/sessions')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();
      if (hubSess.docs.isNotEmpty) sid = hubSess.docs.first.id;
    } catch (_) {}

    if (sid == null) {
      try {
        final rootSess = await fs
            .collection('sessions')
            .orderBy('updatedAt', descending: true)
            .limit(1)
            .get();
        if (rootSess.docs.isNotEmpty) sid = rootSess.docs.first.id;
      } catch (_) {}
    }

    sid ??= _defaultSessionId();

    await fs.doc('hubs/$hubId/sessions/$sid').set({
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'note': 'auto (tools entry)',
    }, SetOptions(merge: true));

    session.setSession(sid);
    try { await seatMap.bindSession(sid); } catch (_) {}
    await hubRef.set({
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

  Future<void> _onToolTap(BuildContext context, ToolItem t) async {
    if (t.id == 'random_seat') {
      final session = context.read<SessionProvider>();
      if (session.sessionId == null) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('sessions')
              .limit(1)
              .get();
          final hasAnySession = snap.docs.isNotEmpty;
          if (!hasAnySession) {
            await _showNeedSessionDialog(context);
            return;
          }
        } catch (_) {
          await _showNeedSessionDialog(context);
          return;
        }
      }
    }
    if (!mounted) return;
    Navigator.pushNamed(context, t.route);
  }

  Future<void> _showNeedSessionDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
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

  Widget _beforeClassSectionGrid(BuildContext context, {required int crossAxisCount}) {
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
          onTap: () {},
        );
      },
    );
  }

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
    final hubId = context.watch<HubProvider>().hubId;

  // ✅ 허브 로딩이 안 끝났으면 Firestore 접근 금지
  if (hubId == null || hubId.isEmpty) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: Colors.black),
      ),
    );
  }
    final width = MediaQuery.sizeOf(context).width;

    return Stack(
      children: [
        AppScaffold(
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

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 77),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Before Class',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF001A36),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _beforeClassSectionGrid(context, crossAxisCount: crossAxisCount),
                      const SizedBox(height: 32),
                      const Text(
                        'Classroom Tools',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                        itemBuilder: (context, i) =>
                            ToolCard(item: tools[i], onTap: () => _onToolTap(context, tools[i])),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (!_displayReady)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.85),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.black),
                    SizedBox(height: 20),
                    Text(
                      'Waiting for Display to be ready...',
                      style: TextStyle(fontSize: 18, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
            final topGap = 8.0 * s;

            return Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      _OpenButton(scale: s, onTap: onTap),
                    ],
                  ),
                  SizedBox(height: topGap),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: titleFs,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 6 * s),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: descFs,
                      height: 1.4,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
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
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFF44A0FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13 * scale),
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
