// lib/pages/profile/student_analysis_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../sidebar_menu.dart';
// import '../../services/openrouter_service.dart';

const String kHubId = 'hub-001';

class StudentAnalysisPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentAnalysisPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentAnalysisPage> createState() => _StudentAnalysisPageState();
}

class _StudentAnalysisPageState extends State<StudentAnalysisPage> {
  bool _isLoadingAI = false;
  Map<String, dynamic>? _aiResult;

  late Future<StudentAnalysisStats> _statsFuture;

  @override
  void initState() {
    super.initState();

    _statsFuture = StudentAnalysisStats.load(
      studentId: widget.studentId,
    );

    // ✅ OpenRouter 토큰 사용 방지를 위해 임시 비활성화
    _aiResult = {
      'summary': 'AI analysis is paused for testing.',
      'teacherNote':
          'AI analysis is temporarily disabled while connecting real chart data.',
      'strength': '',
      'suggestion': 'After chart data is verified, enable OpenRouter again.',
    };

    // _loadAIAnalysis();
  }

  /*
  Future<void> _loadAIAnalysis() async {
    try {
      final result = await OpenRouterService.getStudentAnalysis(
        studentName: widget.studentName,
      );

      if (!mounted) return;

      setState(() {
        _aiResult = result;
        _isLoadingAI = false;
      });
    } catch (e) {
      debugPrint('[AI ERROR] $e');

      if (!mounted) return;

      setState(() {
        _aiResult = {
          'summary': 'AI analysis is temporarily unavailable.',
          'teacherNote': 'The AI service is currently busy. Please try again shortly.',
          'strength': '',
          'suggestion': 'Try again later or switch to another OpenRouter model.',
        };
        _isLoadingAI = false;
      });
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      selectedIndex: 1,
      body: Scaffold(
        backgroundColor: const Color(0xFFF5FAFF),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(56, 36, 56, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(),
                    const SizedBox(height: 36),
                    _StudentHeader(
                      studentName: widget.studentName,
                      aiSummary: _aiResult?['summary'] ?? '',
                    ),
                    const SizedBox(height: 28),

                    FutureBuilder<StudentAnalysisStats>(
                      future: _statsFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snap.hasError) {
                          return Text('Failed to load stats: ${snap.error}');
                        }

                        final stats = snap.data!;

                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _ComparativePerformanceCard(
                                    studentName: widget.studentName,
                                    studentValues: stats.radarStudent,
                                    classAvgValues: stats.radarClassAvg,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                SizedBox(
                                  width: 330,
                                  child: _RightSummaryColumn(
                                    isLoadingAI: _isLoadingAI,
                                    aiResult: _aiResult,
                                    categoryScores: stats.categoryScores,
                                    overallPercent: stats.overallPercent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _TrendAnalysisCard(stats: stats),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────── Stats Model ───────────────── */

class StudentAnalysisStats {
  final List<double> radarStudent;
  final List<double> radarClassAvg;
  final Map<String, double> categoryScores;
  final double overallPercent;

  final List<String> monthLabels;
  final List<double> quizTrend;
  final List<double> homeworkTrend;
  final List<double> attitudeTrend;

  const StudentAnalysisStats({
    required this.radarStudent,
    required this.radarClassAvg,
    required this.categoryScores,
    required this.overallPercent,
    required this.monthLabels,
    required this.quizTrend,
    required this.homeworkTrend,
    required this.attitudeTrend,
  });

  static Future<StudentAnalysisStats> load({
    required String studentId,
  }) async {
    final fs = FirebaseFirestore.instance;

    final studentLogs = await fs
        .collection('hubs/$kHubId/students/$studentId/pointLogs')
        .get();

    final studentScores = _scoresFromLogs(studentLogs.docs);

    final studentsSnap = await fs.collection('hubs/$kHubId/students').get();

    final List<Map<String, double>> allScores = [];

    for (final studentDoc in studentsSnap.docs) {
      final logs = await fs
          .collection('hubs/$kHubId/students/${studentDoc.id}/pointLogs')
          .get();

      allScores.add(_scoresFromLogs(logs.docs));
    }

    final classAvg = _averageScores(allScores);
    final trend = _trendFromLogs(studentLogs.docs);
    final monthLabels = _lastSixMonthLabels();

    final radarStudent = [
      studentScores['attendance'] ?? 0,
      studentScores['quiz'] ?? 0,
      studentScores['homework'] ?? 0,
      studentScores['presentation'] ?? 0,
      studentScores['attitude'] ?? 0,
    ];

    final radarClassAvg = [
      classAvg['attendance'] ?? 0,
      classAvg['quiz'] ?? 0,
      classAvg['homework'] ?? 0,
      classAvg['presentation'] ?? 0,
      classAvg['attitude'] ?? 0,
    ];

    final overall =
        radarStudent.reduce((a, b) => a + b) / radarStudent.length;

    return StudentAnalysisStats(
      radarStudent: radarStudent,
      radarClassAvg: radarClassAvg,
      categoryScores: {
        'ATTENDANCE': studentScores['attendance'] ?? 0,
        'QUIZ AVG': studentScores['quiz'] ?? 0,
        'HOMEWORK': studentScores['homework'] ?? 0,
        'PRESENTATION': studentScores['presentation'] ?? 0,
      },
      overallPercent: overall,
      monthLabels: monthLabels,
      quizTrend: trend['quiz']!,
      homeworkTrend: trend['homework']!,
      attitudeTrend: trend['attitude']!,
    );
  }

  static Map<String, double> _scoresFromLogs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int quiz = 0;
    int homework = 0;
    int presentation = 0;
    int attitude = 0;
    int attendance = 0;

    const attitudeIds = {
      'focused',
      'questioning',
      'presentation',
      'cooperate',
      'perseverance',
      'positive',
    };

    for (final doc in docs) {
      final data = doc.data();
      final typeId = data['typeId']?.toString() ?? '';
      final value = (data['value'] as num?)?.toInt() ?? 0;

      if (typeId == 'quiz') quiz += value;
      if (typeId == 'homework') homework += value;
      if (typeId == 'presentation') presentation += value;
      if (typeId == 'attendance') attendance += value;

      if (attitudeIds.contains(typeId)) {
        attitude += value;
      }
    }

    return {
      'attendance': _normalize(attendance),
      'quiz': _normalize(quiz),
      'homework': _normalize(homework),
      'presentation': _normalize(presentation),
      'attitude': _normalize(attitude),
    };
  }

  static double _normalize(int raw) {
    final score = 50 + (raw * 10);
    return score.clamp(0, 100).toDouble();
  }

  static Map<String, double> _averageScores(List<Map<String, double>> list) {
    if (list.isEmpty) {
      return {
        'attendance': 0,
        'quiz': 0,
        'homework': 0,
        'presentation': 0,
        'attitude': 0,
      };
    }

    double avg(String key) {
      return list.map((e) => e[key] ?? 0).reduce((a, b) => a + b) /
          list.length;
    }

    return {
      'attendance': avg('attendance'),
      'quiz': avg('quiz'),
      'homework': avg('homework'),
      'presentation': avg('presentation'),
      'attitude': avg('attitude'),
    };
  }

  static List<String> _lastSixMonthLabels() {
    const names = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];

    final now = DateTime.now();

    return List.generate(6, (i) {
      final date = DateTime(now.year, now.month - 5 + i);
      return names[date.month - 1];
    });
  }

  static Map<String, List<double>> _trendFromLogs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();

    final monthKeys = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - 5 + i);
      return '${d.year}-${d.month}';
    });

    final quizRaw = List<int>.filled(6, 0);
    final homeworkRaw = List<int>.filled(6, 0);
    final attitudeRaw = List<int>.filled(6, 0);

    const attitudeIds = {
      'focused',
      'questioning',
      'presentation',
      'cooperate',
      'perseverance',
      'positive',
    };

    for (final doc in docs) {
      final data = doc.data();
      final typeId = data['typeId']?.toString() ?? '';
      final value = (data['value'] as num?)?.toInt() ?? 0;
      final createdAt = data['createdAt'];

      if (createdAt is! Timestamp) continue;

      final date = createdAt.toDate();
      final key = '${date.year}-${date.month}';
      final index = monthKeys.indexOf(key);

      if (index == -1) continue;

      if (typeId == 'quiz') quizRaw[index] += value;
      if (typeId == 'homework') homeworkRaw[index] += value;
      if (attitudeIds.contains(typeId)) attitudeRaw[index] += value;
    }

    return {
      'quiz': quizRaw.map(_normalize).toList(),
      'homework': homeworkRaw.map(_normalize).toList(),
      'attitude': attitudeRaw.map(_normalize).toList(),
    };
  }
}

/* ───────────────── Top ───────────────── */

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.person_outline, size: 24),
        const SizedBox(width: 8),
        const Text(
          'Students Management',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 14,
            color: Colors.white,
          ),
          label: const Text(
            'Back',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF439FFF),
            elevation: 0,
            minimumSize: const Size(82, 31),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.3),
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentHeader extends StatelessWidget {
  final String studentName;
  final String aiSummary;

  const _StudentHeader({
    required this.studentName,
    required this.aiSummary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: AssetImage('assets/logo_bird.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                width: 21,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF44DAAD),
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                studentName,
                style: const TextStyle(
                  color: Color(0xFF002B4E),
                  fontSize: 24,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Grade 5 • Section A • Student ID: 2024-0452',
                style: TextStyle(
                  color: Color(0xFF52606D),
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 470,
                child: Text(
                  aiSummary,
                  style: const TextStyle(
                    color: Color(0xFF004883),
                    fontSize: 17,
                    fontFamily: 'Lexend',
                    fontWeight: FontWeight.w400,
                    height: 1.06,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(201, 47),
            side: const BorderSide(color: Color(0xFF001A36)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: const Text(
            'Full PDF Report',
            style: TextStyle(
              color: Color(0xFF001A36),
              fontSize: 17,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 47),
            side: const BorderSide(color: Color(0xFF001A36)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: const Icon(
            Icons.share_outlined,
            color: Color(0xFF001A36),
            size: 20,
          ),
        ),
      ],
    );
  }
}

/* ───────────────── Main Cards ───────────────── */

class _ComparativePerformanceCard extends StatelessWidget {
  final String studentName;
  final List<double> studentValues;
  final List<double> classAvgValues;

  const _ComparativePerformanceCard({
    required this.studentName,
    required this.studentValues,
    required this.classAvgValues,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 629,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 28),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comparative Performance',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
              height: 2.13,
            ),
          ),
          const Text(
            'Individual performance vs. class average across all key metrics',
            style: TextStyle(
              color: Color(0xFFA1A1A1),
              fontSize: 16,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w500,
              height: 2.13,
            ),
          ),
          const SizedBox(height: 34),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 430,
                height: 430,
                child: RadarChart(
                  RadarChartData(
                    radarShape: RadarShape.circle,
                    tickCount: 5,
                    ticksTextStyle: const TextStyle(
                      color: Colors.transparent,
                      fontSize: 0,
                    ),
                    gridBorderData: const BorderSide(
                      color: Color(0xFFE1ECF7),
                      width: 1,
                    ),
                    tickBorderData: const BorderSide(
                      color: Color(0xFFE1ECF7),
                      width: 1,
                    ),
                    radarBorderData: const BorderSide(
                      color: Color(0xFFE1ECF7),
                      width: 1,
                    ),
                    titlePositionPercentageOffset: 0.18,
                    titleTextStyle: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w500,
                    ),
                    getTitle: (index, angle) {
                      const titles = [
                        'Attendance',
                        'Quiz',
                        'Homework',
                        'Presentation',
                        'Attitude',
                      ];
                      return RadarChartTitle(text: titles[index]);
                    },
                    dataSets: [
                      RadarDataSet(
                        fillColor: const Color(0xFF2E92F8).withOpacity(0.32),
                        borderColor: const Color(0xFF2E92F8),
                        entryRadius: 4,
                        dataEntries: studentValues
                            .map((v) => RadarEntry(value: v))
                            .toList(),
                      ),
                      RadarDataSet(
                        fillColor: const Color(0xFFD2D2D2).withOpacity(0.22),
                        borderColor: const Color(0xFFD2D2D2),
                        entryRadius: 3,
                        dataEntries: classAvgValues
                            .map((v) => RadarEntry(value: v))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _DotLegend(color: const Color(0xFF2E92F8), label: studentName),
              const SizedBox(width: 22),
              const _DotLegend(
                color: Color(0xFFD2D2D2),
                label: 'Class Avg',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RightSummaryColumn extends StatelessWidget {
  final bool isLoadingAI;
  final Map<String, dynamic>? aiResult;
  final Map<String, double> categoryScores;
  final double overallPercent;

  const _RightSummaryColumn({
    required this.isLoadingAI,
    required this.aiResult,
    required this.categoryScores,
    required this.overallPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopRankCard(overallPercent: overallPercent),
        const SizedBox(height: 20),
        _CategoryRankingCard(categoryScores: categoryScores),
        const SizedBox(height: 20),
        _TeacherNoteCard(isLoadingAI: isLoadingAI, aiResult: aiResult),
      ],
    );
  }
}

class _TopRankCard extends StatelessWidget {
  final double overallPercent;

  const _TopRankCard({
    required this.overallPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFCEE6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: Color.fromRGBO(0, 26, 54, 1),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${overallPercent.round()}% Overall',
                style: const TextStyle(
                  color: Color(0xFF001A36),
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Based on current score logs',
                style: TextStyle(
                  color: Color(0xFF001A36),
                  fontSize: 14,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryRankingCard extends StatelessWidget {
  final Map<String, double> categoryScores;

  const _CategoryRankingCard({
    required this.categoryScores,
  });

  @override
  Widget build(BuildContext context) {
    final items = categoryScores.entries
        .map((e) => _CategoryScore(e.key, e.value / 100))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Ranking',
            style: TextStyle(
              color: Color(0xFF002B4E),
              fontSize: 16,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 131 / 111,
            ),
            itemBuilder: (_, index) {
              final item = items[index];
              return _CategoryScoreTile(item: item);
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryScore {
  final String label;
  final double value;

  const _CategoryScore(this.label, this.value);
}

class _CategoryScoreTile extends StatelessWidget {
  final _CategoryScore item;

  const _CategoryScoreTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final value = item.value.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 6,
                    color: Color(0xFFE1ECF7),
                  ),
                ),
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 6,
                    color: const Color(0xFF44A0FF),
                    backgroundColor: Colors.transparent,
                  ),
                ),
                Text(
                  '${(value * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    height: 1.33,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherNoteCard extends StatelessWidget {
  final bool isLoadingAI;
  final Map<String, dynamic>? aiResult;

  const _TeacherNoteCard({
    required this.isLoadingAI,
    required this.aiResult,
  });

  @override
  Widget build(BuildContext context) {
    final teacherNote =
        aiResult?['teacherNote'] ??
        aiResult?['teacher_note'] ??
        'No analysis available';
    final suggestion = aiResult?['suggestion'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0x4CCEE6FF),
        border: Border.all(color: const Color(0xFFCEE6FF), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: isLoadingAI
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Teacher's Note",
                  style: TextStyle(
                    color: Color(0xFF002B4E),
                    fontSize: 16,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  teacherNote,
                  style: const TextStyle(
                    color: Color(0xFF868C98),
                    fontSize: 16,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                if (suggestion.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Suggestion',
                    style: TextStyle(
                      color: Color(0xFF002B4E),
                      fontSize: 14,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion,
                    style: const TextStyle(
                      color: Color(0xFF868C98),
                      fontSize: 14,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/* ───────────────── Trend ───────────────── */

class _TrendAnalysisCard extends StatelessWidget {
  final StudentAnalysisStats stats;

  const _TrendAnalysisCard({
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 431,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: _TrendTitle()),
              _LineLegend(color: Color(0xFF44DAAD), label: 'Quizzes'),
              SizedBox(width: 24),
              _LineLegend(color: Color(0xFF868C98), label: 'Homework'),
              SizedBox(width: 24),
              _LineLegend(color: Color(0xFFFF96F1), label: 'Attitude'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 5,
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 25,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFE1ECF7),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: const TextStyle(
                            color: Color(0xFFBFDBF7),
                            fontSize: 14,
                            fontFamily: 'Lexend',
                            fontWeight: FontWeight.w400,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final months = stats.monthLabels;
                        final i = value.toInt();

                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            months[i],
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontFamily: 'Lexend',
                              fontWeight: FontWeight.w400,
                              height: 1,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  _lineData(
                    color: const Color(0xFF44DAAD),
                    values: stats.quizTrend,
                  ),
                  _lineData(
                    color: const Color(0xFF868C98),
                    values: stats.homeworkTrend,
                  ),
                  _lineData(
                    color: const Color(0xFFFF96F1),
                    values: stats.attitudeTrend,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static LineChartBarData _lineData({
    required Color color,
    required List<double> values,
  }) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
      spots: List.generate(
        values.length,
        (index) => FlSpot(index.toDouble(), values[index]),
      ),
    );
  }
}

class _TrendTitle extends StatelessWidget {
  const _TrendTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '6-Month Trend Analysis',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Progression of core learning factors over the current semester',
          style: TextStyle(
            color: Color(0xFFA1A1A1),
            fontSize: 16,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/* ───────────────── Common ───────────────── */

BoxDecoration _cardDecoration({Border? border}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    border: border,
    boxShadow: const [
      BoxShadow(
        color: Color(0x0A000000),
        blurRadius: 20,
        offset: Offset(0, 4),
      ),
    ],
  );
}

class _DotLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _DotLegend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            height: 1.33,
          ),
        ),
      ],
    );
  }
}

class _LineLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _LineLegend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 32, height: 2, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF52606D),
            fontSize: 12,
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w600,
            height: 1.33,
          ),
        ),
      ],
    );
  }
}