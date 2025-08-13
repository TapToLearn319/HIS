import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:wave_progress_indicator/wave_progress_indicator.dart';    // 찬반형 UI
import 'package:flutter_polls/flutter_polls.dart'; // 문항형 UI
import '../../../main.dart';

import 'groupMaking/display_group_page.dart';
//import 'vote/display_vote_page.dart';

class DrawnLine {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawnLine({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class DisplayToolsPage extends StatefulWidget {
  const DisplayToolsPage({Key? key}) : super(key: key);

  @override
  _DisplayToolsPageState createState() => _DisplayToolsPageState();
}

class _DisplayToolsPageState extends State<DisplayToolsPage>
    with SingleTickerProviderStateMixin {
  int minutes = 0;
  int seconds = 0;
  bool isRunning = false;
  int totalSeconds = 0;
  bool timeUp = false;

  List<DrawnLine> boardLines = [];

  String musicPlatform = '';
  String? musicTrack;
  String? musicTitle;
  String musicStatus = 'stopped';

  String toolMode = 'none';
  String agendaText = '';

  bool _didRouteToGroupDisplay = false;
  bool _didRouteToVoteDisplay = false;

  // 투표 상태
  String? voteId;
  String voteTitle = '';
  String voteType = 'binary'; // 'binary', 'multiple'
  bool voteActive = false;
  List<Map<String, dynamic>> voteOptions = [];

  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _voteSub;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.stop();

    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(_controller);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(_controller);

    channel.onMessage.listen((msg) {
      try {
        final raw = msg.data;
        final data =
            (raw is String) ? jsonDecode(raw) : raw as Map<String, dynamic>;

        switch (data['type']) {
          case 'tool_mode':
            setState(() => toolMode = (data['mode'] as String?) ?? 'none');
            if (toolMode == 'grouping') _goToGroupingDisplay();
            break;

          case 'timer':
            setState(() {
              toolMode = 'timer';
              minutes = (data['minutes'] as num).toInt();
              seconds = (data['seconds'] as num).toInt();
              isRunning = (data['isRunning'] as bool?) ?? false;
              totalSeconds =
                  (data['totalSeconds'] as num?)?.toInt() ?? totalSeconds;
              timeUp = (minutes == 0 && seconds == 0 && !isRunning);
              if (timeUp) {
                _controller.repeat(reverse: true);
              } else {
                _controller.stop();
              }
            });
            break;

          case 'board':
            setState(() {
              toolMode = 'board';
              final linesRaw = (data['lines'] as List?) ?? const [];
              boardLines =
                  linesRaw.map((line) {
                    final pointsRaw = (line['points'] as List?) ?? const [];
                    final points =
                        pointsRaw.map((p) {
                          final dx = (p['dx'] as num?)?.toDouble() ?? 0.0;
                          final dy = (p['dy'] as num?)?.toDouble() ?? 0.0;
                          return Offset(dx, dy);
                        }).toList();
                    final color = Color((line['color'] as int?) ?? 0xFF000000);
                    final strokeWidth =
                        (line['strokeWidth'] as num?)?.toDouble() ?? 4.0;
                    return DrawnLine(
                      points: points,
                      color: color,
                      strokeWidth: strokeWidth,
                    );
                  }).toList();
            });
            break;

          case 'agenda':
            setState(() => agendaText = (data['text'] as String?) ?? '');
            break;

          case 'music':
            setState(() {
              toolMode = 'music';
              musicPlatform = (data['platform'] as String?) ?? '';
              musicTrack = data['track'] as String?;
              musicTitle = (data['title'] as String?) ?? 'Unknown Title';
              musicStatus = (data['status'] as String?) ?? 'stopped';
            });
            break;

          case 'ai':
            setState(() => toolMode = 'ai');
            break;

          // 랜덤 그룹
          case 'grouping_result':
            toolMode = 'grouping';
            _goToGroupingDisplay();
            break;

          // 투표 제어
          case 'vote_start':
            _attachVoteStream(
              id: data['voteId'] as String,
              title: (data['title'] as String?) ?? '',
              type: (data['voteType'] as String?) ?? 'binary',
            );
            break;

          case 'vote_close':
            if (voteId == data['voteId']) {
              setState(() => voteActive = false);
            }
            break;

          case 'vote_delete':
            if (voteId == data['voteId']) {
              _detachVoteStream();
              setState(() {
                voteId = null;
                voteTitle = '';
                voteOptions = [];
                voteActive = false;
                toolMode = 'none';
              });
            }
            break;
        }
      } catch (e) {
        debugPrint('DisplayToolsPage onMessage error: $e');
      }
    });
  }

  void _attachVoteStream({
    required String id,
    required String title,
    required String type,
  }) {
    _detachVoteStream();

    setState(() {
      voteId = id;
      voteTitle = title;
      voteType = type;
      toolMode = 'vote';
      voteActive = true;
      voteOptions = [];
    });

    _voteSub = FirebaseFirestore.instance
        .collection('votes')
        .doc(id)
        .snapshots()
        .listen(
          (snap) {
            if (!snap.exists) return;

            final data = snap.data()!;
            // 안전 파싱
            final rawTitle = data['title'];
            final rawType = data['type'];
            final rawActive = data['active'];
            final rawOptions = data['options'];

            final safeTitle = rawTitle is String ? rawTitle : voteTitle;
            final safeType =
                (rawType is String &&
                        (rawType == 'binary' || rawType == 'multiple'))
                    ? rawType
                    : voteType;
            final safeActive = rawActive is bool ? rawActive : voteActive;

            final List<Map<String, dynamic>> safeOptions = [];
            if (rawOptions is List) {
              for (final item in rawOptions) {
                if (item is Map) {
                  final id = item['id'];
                  final tt = item['title'];
                  final vv = item['votes'];
                  safeOptions.add({
                    'id': id is String ? id : (tt?.toString() ?? ''),
                    'title': tt is String ? tt : (id?.toString() ?? ''),
                    'votes': vv is num ? vv.toInt() : 0,
                  });
                } else if (item is String) {
                  safeOptions.add({'id': item, 'title': item, 'votes': 0});
                }
              }
            }

            setState(() {
              voteTitle = safeTitle;
              voteType = safeType;
              voteActive = safeActive;
              voteOptions = safeOptions;
            });
          },
          onError: (e) {
            debugPrint('vote stream error: $e');
          },
        );
  }

  void _detachVoteStream() {
    _voteSub?.cancel();
    _voteSub = null;
  }

  double get progress {
    if (totalSeconds == 0) return 0;
    final remaining = (minutes * 60) + seconds;
    return remaining / totalSeconds;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: toolMode == 'board' ? Colors.white : Colors.black,
      body: Builder(
        builder: (_) {
          switch (toolMode) {
            case 'none':
              return const Center(
                child: Text(
                  '도구를 선택하세요',
                  style: TextStyle(color: Colors.white, fontSize: 28),
                ),
              );
            case 'board':
              return CustomPaint(
                painter: BoardPainter(boardLines),
                size: Size.infinite,
              );
            case 'music':
              return buildMusicUI();
            case 'agenda':
              return buildAgendaUI();
            case 'grouping':
              return const SizedBox.shrink();
            case 'vote':
              return buildVoteUI();
            default:
              return buildTimerUI();
          }
        },
      ),
    );
  }

  void _goToGroupingDisplay() {
    if (!mounted || _didRouteToGroupDisplay) return;
    _didRouteToGroupDisplay = true;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GroupDisplayPage()))
        .then((_) {
          if (mounted) _didRouteToGroupDisplay = false;
        });
  }

//   // 랜덤 그룹
//   Widget buildGroupingUI() {
//   return Padding(
//     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             const Icon(Icons.groups, color: Colors.white, size: 32),
//             const SizedBox(width: 10),
//             Text(
//               groupingTitle,
//               style: const TextStyle(
//                 fontSize: 42,
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 24),
//         Expanded(
//           child: LayoutBuilder(builder: (_, c) {
//             final cross = c.maxWidth > 1300 ? 5 : (c.maxWidth > 1000 ? 4 : (c.maxWidth > 700 ? 3 : 2));
//             return GridView.builder(
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: cross,
//                 crossAxisSpacing: 16,
//                 mainAxisSpacing: 16,
//                 childAspectRatio: 0.9,
//               ),
//               itemCount: groups.length,
//               itemBuilder: (_, i) => _groupCard(i + 1, groups[i]),
//             );
//           }),
//         ),
//       ],
//     ),
//   );
// }

// Widget _groupCard(int idx, List<String> members) {
//   return Container(
//     decoration: BoxDecoration(
//       color: Colors.white.withValues(alpha: 0.95),
//       borderRadius: BorderRadius.circular(12),
//     ),
//     padding: const EdgeInsets.all(16),
//     child: Column(
//       children: [
//         Text('Team $idx',
//             style: const TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.w800,
//               color: Color(0xFF0F172A),
//             )),
//         const SizedBox(height: 8),
//         const Divider(height: 1),
//         const SizedBox(height: 8),
//         Expanded(
//           child: ListView.separated(
//             itemCount: members.length,
//             itemBuilder: (_, i) => Center(
//               child: Text(
//                 members[i],
//                 style: const TextStyle(fontSize: 16, color: Color(0xFF111827)),
//               ),
//             ),
//             separatorBuilder: (_, __) => const SizedBox(height: 6),
//           ),
//         ),
//       ],
//     ),
//   );
// }

  // ========= 투표 UI =========
  Widget buildVoteUI() {
    if (voteId == null) {
      return const Center(
        child: Text(
          '진행 중인 투표가 없습니다',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      );
    }

    final content =
        (voteType == 'multiple') ? _buildMultiplePolls() : _buildBinaryWaves();

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                voteTitle.isEmpty ? '투표' : voteTitle,
                style: const TextStyle(
                  fontSize: 42,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: Center(child: content)),
            ],
          ),
        ),

        // 종료 오버레이
        if (!voteActive)
          Container(
            color: Colors.black.withValues(alpha: 0.55),
            alignment: Alignment.center,
            child: const Text(
              '투표 종료',
              style: TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMultiplePolls() {
    if (voteOptions.length < 2) {
      return const SizedBox(
        width: 420,
        child: Center(
          child: Text(
            '옵션을 불러오는 중...',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    final options =
        voteOptions
            .map(
              (o) => PollOption(
                id: (o['id'] as String?) ?? '',
                title: Text(
                  (o['title'] as String?) ?? '',
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                ),
                votes: (o['votes'] as int?) ?? 0,
              ),
            )
            .toList();

    return IgnorePointer(
      ignoring: true,
      child: FlutterPolls(
        pollId: voteId!,
        hasVoted: false,
        userVotedOptionId: null,
        pollEnded: !voteActive,
        votedAnimationDuration: 300,
        onVoted: (option, total) async => true,
        pollTitle: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            voteTitle,
            style: const TextStyle(fontSize: 22, color: Colors.white70),
          ),
        ),
        pollOptions: options,
        votesText: 'Votes',
        votesTextStyle: const TextStyle(color: Colors.white54),
        votedPercentageTextStyle: const TextStyle(
          fontSize: 18,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        votedBackgroundColor: Colors.white.withValues(alpha: 0.10),
        voteInProgressColor: Colors.white.withValues(alpha: 0.12),
        votedProgressColor: Colors.lightBlueAccent.withValues(alpha: 0.45),
        pollOptionsBorderRadius: BorderRadius.circular(14),
        pollOptionsHeight: 56,
        heightBetweenTitleAndOptions: 16,
        heightBetweenOptions: 12,
      ),
    );
  }

  Widget _buildBinaryWaves() {
    int agree = 0;
    int disagree = 0;
    for (final o in voteOptions) {
      final t = ((o['title'] as String?) ?? '').trim();
      final v = (o['votes'] as int?) ?? 0;
      if (t == '찬성') agree = v;
      if (t == '반대') disagree = v;
    }

    final total = (agree + disagree);
    final agreeRatio = total == 0 ? 0.0 : agree / total;
    final disagreeRatio = total == 0 ? 0.0 : disagree / total;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _waveCircle(
          label: '찬성',
          ratio: agreeRatio,
          count: agree,
          color: Colors.lightBlue,
        ),
        const SizedBox(width: 60),
        _waveCircle(
          label: '반대',
          ratio: disagreeRatio,
          count: disagree,
          color: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _waveCircle({
    required String label,
    required double ratio,
    required int count,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 24)),
        const SizedBox(height: 10),
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(60),
          ),
          child: _SimpleWave(
            value: ratio,
            gradientColors: [color.withValues(alpha: 0.8), color, color],
            child: Center(
              child: Text(
                '${(ratio * 100).round()}%',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$count명',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _detachVoteStream();
    super.dispose();
  }

  // ===== 기타 기존 UI들 =====
  Widget buildAgendaUI() {
    final formattedDate = DateFormat('M월 d일').format(DateTime.now());

    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          '$formattedDate 알 림 장',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 1200,
            height: 700,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green[700],
              border: Border.all(color: Colors.brown, width: 12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Text(
                agendaText,
                style: const TextStyle(color: Colors.white, fontSize: 50),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMusicUI() {
    final videoId =
        musicTrack != null
            ? Uri.tryParse(musicTrack!)?.queryParameters['v']
            : null;
    final thumbnailUrl =
        videoId != null
            ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
            : null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note, size: 60, color: Colors.pinkAccent),
          const SizedBox(height: 20),
          if (thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                thumbnailUrl,
                width: 320,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            musicTitle ?? 'No title available',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Status: $musicStatus',
            style: const TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget buildTimerUI() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.5 ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isRunning ? 'Running...' : 'Paused',
                style: TextStyle(
                  fontSize: 24,
                  color: isRunning ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
        if (timeUp)
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Container(
                alignment: Alignment.center,
                color: Colors.black.withValues(alpha: 0.7),
                child: const Text(
                  'TIME\'S UP!',
                  style: TextStyle(
                    fontSize: 90,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class BoardPainter extends CustomPainter {
  final List<DrawnLine> lines;
  BoardPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      final paint =
          Paint()
            ..color = line.color
            ..strokeCap = StrokeCap.round
            ..strokeWidth = line.strokeWidth;
      for (int i = 0; i < line.points.length - 1; i++) {
        canvas.drawLine(line.points[i], line.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => true;
}

class _SimpleWave extends StatelessWidget {
  final double value;
  final List<Color> gradientColors;
  final Widget? child;

  const _SimpleWave({
    Key? key,
    required this.value,
    required this.gradientColors,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final fillH = h * v;
        return ClipRRect(
          borderRadius: BorderRadius.circular(60),
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.white)),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: fillH,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              if (child != null) Positioned.fill(child: child!),
            ],
          ),
        );
      },
    );
  }
}
