import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wave_progress_indicator/wave_progress_indicator.dart';
import '../../../main.dart';

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
  int agreeCount = 0;
  int disagreeCount = 0;

  List<DrawnLine> boardLines = [];

  String musicPlatform = '';
  String? musicTrack;
  String? musicTitle;
  String musicStatus = 'stopped';

  String toolMode = 'none';
  String agendaText = '';

  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

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
      final data = jsonDecode(msg.data as String);

      if (data['type'] == 'tool_mode') {
        setState(() {
          toolMode = data['mode'];
        });
      } else if (data['type'] == 'timer') {
        setState(() {
          toolMode = 'timer';
          minutes = data['minutes'];
          seconds = data['seconds'];
          isRunning = data['isRunning'];
          totalSeconds = data['totalSeconds'] ?? totalSeconds;
          timeUp = (minutes == 0 && seconds == 0 && !isRunning);
          if (timeUp) {
            _controller.repeat(reverse: true);
          } else {
            _controller.stop();
          }
        });
      } else if (data['type'] == 'board') {
        setState(() {
          toolMode = 'board';
          boardLines =
              (data['lines'] as List).map((line) {
                final points =
                    (line['points'] as List)
                        .map(
                          (p) => Offset(
                            (p['dx'] as num).toDouble(),
                            (p['dy'] as num).toDouble(),
                          ),
                        )
                        .toList();
                final color = Color(line['color']);
                final strokeWidth = (line['strokeWidth'] as num).toDouble();
                return DrawnLine(
                  points: points,
                  color: color,
                  strokeWidth: strokeWidth,
                );
              }).toList();
        });
      } else if (data['type'] == 'agenda') {
        setState(() {
          agendaText = data['text'];
        });
      } else if (data['type'] == 'music') {
        setState(() {
          toolMode = 'music';
          musicPlatform = data['platform'];
          musicTrack = data['track'];
          musicTitle = data['title'] ?? 'Unknown Title';
          musicStatus = data['status'];
        });
      } else if (data['type'] == 'ai') {
        toolMode = 'ai';
      } else if (data['type'] == 'debate_vote') {
        setState(() {
          agreeCount = data['agreeCount'] ?? 0;
          disagreeCount = data['disagreeCount'] ?? 0;
        });
      }
    });
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
      body:
          toolMode == 'none'
              ? const Center(
                child: Text(
                  '도구를 선택하세요',
                  style: TextStyle(color: Colors.white, fontSize: 28),
                ),
              )
              : toolMode == 'board'
              ? CustomPaint(
                painter: BoardPainter(boardLines),
                size: Size.infinite,
              )
              : toolMode == 'music'
              ? buildMusicUI()
              : toolMode == 'agenda'
              ? buildAgendaUI()
              : toolMode == 'debate'
              ? buildDebateUI()
              : buildTimerUI(),
    );
  }

  Widget buildDebateUI() {
    int total = agreeCount + disagreeCount;
    double agreeRatio = total == 0 ? 0 : agreeCount / total;
    double disagreeRatio = total == 0 ? 0 : disagreeCount / total;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '찬성',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 10),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(60),
              ),
              child: WaveProgressIndicator(
                value: agreeRatio,
                gradientColors: [
                  Colors.lightBlue,
                  Colors.blue,
                  Colors.blueAccent,
                ],
                waveHeight: 12,
                speed: 1.2,
                borderRadius: BorderRadius.circular(60),
                child: Center(
                  child: Text(
                    '${(agreeRatio * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$agreeCount명',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(width: 60),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '반대',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 10),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white, // 배경색
                borderRadius: BorderRadius.circular(60),
              ),
              child: WaveProgressIndicator(
                value: disagreeRatio,
                gradientColors: [
                  Colors.redAccent,
                  Colors.red,
                  Colors.deepOrange,
                ],
                waveHeight: 12,
                speed: 1.2,
                borderRadius: BorderRadius.circular(60),
                child: Center(
                  child: Text(
                    '${(disagreeRatio * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$disagreeCount명',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

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

          // ✅ 썸네일 + 플랫폼 로고
          if (thumbnailUrl != null)
            Stack(
              alignment: Alignment.topLeft,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    thumbnailUrl,
                    width: 320,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                if (musicPlatform.toLowerCase() == 'youtube')
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.play_circle_fill,
                            color: Colors.redAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'YouTube',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 16),

          // ✅ 영상 제목
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

          // ✅ 재생 상태
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
                color: Colors.black.withOpacity(0.7),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
