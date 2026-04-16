import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/hub_provider.dart';

class StatisticDetailPage extends StatefulWidget {
  const StatisticDetailPage({
    super.key,
    required this.topicId,
    required this.title,
  });

  final String topicId;
  final String title;

  @override
  State<StatisticDetailPage> createState() => _StatisticDetailPageState();
}

class _StatisticDetailPageState extends State<StatisticDetailPage> {
  bool _showByProblem = true;
  String? _expandedQuizId;
  String? _expandedStudentId;

  @override
  Widget build(BuildContext context) {
    final hubPath = context.watch<HubProvider>().hubDocPath;

    if (hubPath == null) {
      return const Scaffold(
        body: Center(
          child: Text('허브를 먼저 선택하세요.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFEFF2F6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF001A36),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                _TopTabButton(
                  label: 'By problem',
                  selected: _showByProblem,
                  onTap: () {
                    setState(() {
                      _showByProblem = true;
                      _expandedStudentId = null;
                    });
                  },
                ),
                const SizedBox(width: 28),
                _TopTabButton(
                  label: 'By student',
                  selected: !_showByProblem,
                  onTap: () {
                    setState(() {
                      _showByProblem = false;
                      _expandedQuizId = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            Expanded(
              child: _showByProblem
                  ? _ByProblemView(
                      hubPath: hubPath,
                      topicId: widget.topicId,
                      expandedQuizId: _expandedQuizId,
                      onToggleExpanded: (quizId) {
                        setState(() {
                          _expandedQuizId =
                              _expandedQuizId == quizId ? null : quizId;
                        });
                      },
                    )
                  : _ByStudentView(
                      hubPath: hubPath,
                      topicId: widget.topicId,
                      expandedStudentId: _expandedStudentId,
                      onToggleExpanded: (studentId) {
                        setState(() {
                          _expandedStudentId =
                              _expandedStudentId == studentId ? null : studentId;
                        });
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ByProblemView extends StatefulWidget {
  const _ByProblemView({
    required this.hubPath,
    required this.topicId,
    required this.expandedQuizId,
    required this.onToggleExpanded,
  });

  final String hubPath;
  final String topicId;
  final String? expandedQuizId;
  final ValueChanged<String> onToggleExpanded;

  @override
  State<_ByProblemView> createState() => _ByProblemViewState();
}

class _ByProblemViewState extends State<_ByProblemView> {
  late Future<_ProblemListBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadProblemList(
      hubPath: widget.hubPath,
      topicId: widget.topicId,
    );
  }

  @override
  void didUpdateWidget(covariant _ByProblemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hubPath != widget.hubPath ||
        oldWidget.topicId != widget.topicId) {
      _future = _loadProblemList(
        hubPath: widget.hubPath,
        topicId: widget.topicId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProblemListBundle>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _DetailWaitingBox();
        }

        if (snap.hasError) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD9D9D9)),
            ),
            child: Center(
              child: Text(
                '통계를 불러오지 못했습니다.\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        final bundle = snap.data;
        if (bundle == null || bundle.items.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD9D9D9)),
            ),
            child: const Center(
              child: Text(
                '표시할 문제 통계가 없습니다.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD9D9D9)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(
                        'No.',
                        style: TextStyle(
                          color: Color(0xFF001A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: Text(
                        'Question',
                        style: TextStyle(
                          color: Color(0xFF001A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 165,
                      child: Text(
                        'Answer rate',
                        style: TextStyle(
                          color: Color(0xFF001A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        'Correct / Total',
                        style: TextStyle(
                          color: Color(0xFF001A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        'Details',
                        style: TextStyle(
                          color: Color(0xFF001A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: const Color(0xFFE0E0E0),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  itemCount: bundle.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final item = bundle.items[index];
                    final isExpanded = widget.expandedQuizId == item.quizId;

                    return Column(
                      children: [
                        _ProblemRow(
                          item: item,
                          index: index + 1,
                          expanded: isExpanded,
                          onTapMore: () => widget.onToggleExpanded(item.quizId),
                        ),
                        if (isExpanded)
                          _ProblemExpandedSection(
                            hubPath: widget.hubPath,
                            topicId: widget.topicId,
                            item: item,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ByStudentView extends StatefulWidget {
  const _ByStudentView({
    required this.hubPath,
    required this.topicId,
    required this.expandedStudentId,
    required this.onToggleExpanded,
  });

  final String hubPath;
  final String topicId;
  final String? expandedStudentId;
  final ValueChanged<String> onToggleExpanded;

  @override
  State<_ByStudentView> createState() => _ByStudentViewState();
}

class _ByStudentViewState extends State<_ByStudentView> {
  late Future<_StudentListBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadStudentList(
      hubPath: widget.hubPath,
      topicId: widget.topicId,
    );
  }

  @override
  void didUpdateWidget(covariant _ByStudentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hubPath != widget.hubPath ||
        oldWidget.topicId != widget.topicId) {
      _future = _loadStudentList(
        hubPath: widget.hubPath,
        topicId: widget.topicId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StudentListBundle>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _DetailWaitingBox();
        }

        if (snap.hasError) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD9D9D9)),
            ),
            child: Center(
              child: Text(
                '통계를 불러오지 못했습니다.\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        final bundle = snap.data;
        if (bundle == null || bundle.items.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD9D9D9)),
            ),
            child: const Center(
              child: Text(
                '표시할 학생 통계가 없습니다.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD9D9D9)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(
                        'No.',
                        style: TextStyle(
                          color: Color(0xFF001A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Text(
                        'Name',
                        style: TextStyle(
                          color: Color(0xFF001A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Text(
                        'Contents',
                        style: TextStyle(
                          color: Color(0xFF001A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: Text(
                        'Answer rate (%)',
                        style: TextStyle(
                          color: Color(0xFF001A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        'Rank',
                        style: TextStyle(
                          color: Color(0xFF001A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        'Details',
                        style: TextStyle(
                          color: Color(0xFF001A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: const Color(0xFFE0E0E0),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  itemCount: bundle.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final item = bundle.items[index];
                    final isExpanded =
                        widget.expandedStudentId == item.studentId;

                    return Column(
                      children: [
                        _StudentRow(
                          item: item,
                          index: index + 1,
                          expanded: isExpanded,
                          onTapMore: () =>
                              widget.onToggleExpanded(item.studentId),
                        ),
                        if (isExpanded)
                          _StudentExpandedSection(
                            hubPath: widget.hubPath,
                            topicId: widget.topicId,
                            studentId: item.studentId,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<_ProblemListBundle> _loadProblemList({
  required String hubPath,
  required String topicId,
}) async {
  final fs = FirebaseFirestore.instance;
  final topicSnap = await fs.doc('$hubPath/quizTopics/$topicId').get();
  final topicData = topicSnap.data() ?? {};

  final sessionId = (topicData['sessionId'] as String?)?.trim();
  final runId = (topicData['activeRunId'] as String?)?.trim();

  if (sessionId == null ||
      sessionId.isEmpty ||
      runId == null ||
      runId.isEmpty) {
    return const _ProblemListBundle(items: []);
  }

  final hubId = _extractHubId(hubPath);

  final quizzesSnap = await fs
      .collection('$hubPath/quizTopics/$topicId/quizzes')
      .orderBy('createdAt')
      .get();

  final publicQuizDocs = quizzesSnap.docs.where((doc) {
    final data = doc.data();
    final p = data['public'];
    if (p is bool) return p;
    if (p is String) return p.toLowerCase() == 'true';
    return false;
  }).toList();

  final responsesSnap = await fs
      .collection('hubs/$hubId/sessions/$sessionId/quizRuns/$runId/responses')
      .get();

  final allParticipantIds = responsesSnap.docs
      .map((d) => (d.data()['studentId'] ?? '').toString())
      .where((id) => id.isNotEmpty)
      .toSet();

  final totalParticipants = allParticipantIds.length;
  final items = <_ProblemListItem>[];

  for (final quizDoc in publicQuizDocs) {
    final quizId = quizDoc.id;
    final quizData = quizDoc.data();

    final question = (quizData['question'] ?? '').toString();
    final options = (quizData['options'] as List?) ?? const [];
    final correctBinding =
        Map<String, dynamic>.from((quizData['correctBinding'] as Map?) ?? {});

    int correctIndex = -1;

    for (int i = 0; i < options.length; i++) {
      final opt = Map<String, dynamic>.from(options[i] as Map);
      final binding = Map<String, dynamic>.from(
        (opt['binding'] as Map?) ?? {},
      );

      final sameButton = binding['button'] == correctBinding['button'];
      final sameGesture = binding['gesture'] == correctBinding['gesture'];

      if (sameButton && sameGesture) {
        correctIndex = i;
        break;
      }
    }

    final quizResponses = responsesSnap.docs.where((d) {
      final x = d.data();
      return x['quizId'] == quizId;
    }).toList();

    int correctCount = 0;

    for (final responseDoc in quizResponses) {
      final x = responseDoc.data();
      final selectedIndex = (x['selectedIndex'] as num?)?.toInt();
      if (selectedIndex != null && selectedIndex == correctIndex) {
        correctCount++;
      }
    }

    final answerRate = totalParticipants == 0
        ? 0.0
        : (correctCount / totalParticipants) * 100.0;

    items.add(
      _ProblemListItem(
        quizId: quizId,
        question: question,
        answerRate: answerRate,
        correctCount: correctCount,
        totalCount: totalParticipants,
      ),
    );
  }

  return _ProblemListBundle(items: items);
}

Future<_StudentListBundle> _loadStudentList({
  required String hubPath,
  required String topicId,
}) async {
  final fs = FirebaseFirestore.instance;
  final topicSnap = await fs.doc('$hubPath/quizTopics/$topicId').get();
  final topicData = topicSnap.data() ?? {};

  final sessionId = (topicData['sessionId'] as String?)?.trim();
  final runId = (topicData['activeRunId'] as String?)?.trim();

  if (sessionId == null ||
      sessionId.isEmpty ||
      runId == null ||
      runId.isEmpty) {
    return const _StudentListBundle(items: []);
  }

  final hubId = _extractHubId(hubPath);

  final quizzesSnap = await fs
      .collection('$hubPath/quizTopics/$topicId/quizzes')
      .orderBy('createdAt')
      .get();

  final publicQuizDocs = quizzesSnap.docs.where((doc) {
    final data = doc.data();
    final p = data['public'];
    if (p is bool) return p;
    if (p is String) return p.toLowerCase() == 'true';
    return false;
  }).toList();

  final quizDocsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
    for (final q in publicQuizDocs) q.id: q,
  };

  final responsesSnap = await fs
      .collection('hubs/$hubId/sessions/$sessionId/quizRuns/$runId/responses')
      .get();

  final studentsSnap = await fs.collection('$hubPath/students').get();

  final studentNameById = <String, String>{
    for (final d in studentsSnap.docs)
      d.id: ((d.data()['name'] ?? d.data()['studentName'] ?? d.id).toString())
  };

  final studentResponses =
      <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  for (final doc in responsesSnap.docs) {
    final studentId = (doc.data()['studentId'] ?? '').toString();
    if (studentId.isEmpty) continue;
    studentResponses.putIfAbsent(studentId, () => []).add(doc);
  }

  final tempItems = <_StudentListItemTemp>[];

  for (final entry in studentResponses.entries) {
    final studentId = entry.key;
    final responses = entry.value;

    int correctCount = 0;
    int totalCount = publicQuizDocs.length;

    for (final responseDoc in responses) {
      final data = responseDoc.data();
      final quizId = (data['quizId'] ?? '').toString();
      final selectedIndex = (data['selectedIndex'] as num?)?.toInt();

      if (quizId.isEmpty || selectedIndex == null) continue;

      final quizDoc = quizDocsById[quizId];
      if (quizDoc == null) continue;

      final quizData = quizDoc.data();
      final options = (quizData['options'] as List?) ?? const [];
      final correctBinding =
          Map<String, dynamic>.from((quizData['correctBinding'] as Map?) ?? {});

      int correctIndex = -1;
      for (int i = 0; i < options.length; i++) {
        final opt = Map<String, dynamic>.from(options[i] as Map);
        final binding = Map<String, dynamic>.from(
          (opt['binding'] as Map?) ?? {},
        );

        final sameButton = binding['button'] == correctBinding['button'];
        final sameGesture = binding['gesture'] == correctBinding['gesture'];

        if (sameButton && sameGesture) {
          correctIndex = i;
          break;
        }
      }

      if (selectedIndex == correctIndex) {
        correctCount++;
      }
    }

    final answerRate =
        totalCount == 0 ? 0.0 : (correctCount / totalCount) * 100.0;

    tempItems.add(
      _StudentListItemTemp(
        studentId: studentId,
        name: studentNameById[studentId] ?? studentId,
        answerRate: answerRate,
        correctCount: correctCount,
        totalCount: totalCount,
      ),
    );
  }

  tempItems.sort((a, b) {
    final byCorrect = b.correctCount.compareTo(a.correctCount);
    if (byCorrect != 0) return byCorrect;
    return a.name.compareTo(b.name);
  });

  final items = <_StudentListItem>[];
  int currentRank = 0;
  int? prevScore;

  for (int i = 0; i < tempItems.length; i++) {
    final item = tempItems[i];
    if (prevScore != item.correctCount) {
      currentRank = i + 1;
      prevScore = item.correctCount;
    }

    items.add(
      _StudentListItem(
        studentId: item.studentId,
        name: item.name,
        answerRate: item.answerRate,
        rank: currentRank,
        correctCount: item.correctCount,
        totalCount: item.totalCount,
      ),
    );
  }

  return _StudentListBundle(items: items);
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({
    required this.item,
    required this.index,
    required this.expanded,
    required this.onTapMore,
  });

  final _ProblemListItem item;
  final int index;
  final bool expanded;
  final VoidCallback onTapMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: Text(
              item.question,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 165,
            child: Text(
              '${item.answerRate.round()}%',
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              '${item.correctCount} / ${item.totalCount}',
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 72,
                height: 32,
                child: ElevatedButton(
                  onPressed: onTapMore,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF4C98F0),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'More',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.item,
    required this.index,
    required this.expanded,
    required this.onTapMore,
  });

  final _StudentListItem item;
  final int index;
  final bool expanded;
  final VoidCallback onTapMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: const Text(
              'Questions',
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: Text(
              '${item.answerRate.round()}%',
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              '${item.rank}',
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 82,
                height: 32,
                child: ElevatedButton(
                  onPressed: onTapMore,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF4C98F0),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'More',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemExpandedSection extends StatelessWidget {
  const _ProblemExpandedSection({
    required this.hubPath,
    required this.topicId,
    required this.item,
  });

  final String hubPath;
  final String topicId;
  final _ProblemListItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 18, 10),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: SizedBox(
        height: 155,
        child: FutureBuilder<List<_ProblemOptionDetail>>(
          future: _loadExpandedDetails(
            hubPath: hubPath,
            topicId: topicId,
            quizId: item.quizId,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Text(
                  '로딩중...',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            if (snap.hasError) {
              return Center(
                child: Text(
                  '상세 통계 로딩 실패\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            final details = snap.data ?? [];
            if (details.isEmpty) {
              return const Center(
                child: Text(
                  '상세 응답이 없습니다.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            return Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Column(
                  children: details.map((detail) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ExpandedOptionRow(detail: detail),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StudentExpandedSection extends StatelessWidget {
  const _StudentExpandedSection({
    required this.hubPath,
    required this.topicId,
    required this.studentId,
  });

  final String hubPath;
  final String topicId;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 18, 10),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: SizedBox(
        height: 155,
        child: FutureBuilder<List<_StudentQuestionDetail>>(
          future: _loadStudentExpandedDetails(
            hubPath: hubPath,
            topicId: topicId,
            studentId: studentId,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Text(
                  '로딩중...',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            if (snap.hasError) {
              return Center(
                child: Text(
                  '상세 통계 로딩 실패\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            final details = snap.data ?? [];
            if (details.isEmpty) {
              return const Center(
                child: Text(
                  '상세 응답이 없습니다.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            return Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Column(
                  children: details.map((detail) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StudentQuestionResultRow(detail: detail),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<List<_ProblemOptionDetail>> _loadExpandedDetails({
  required String hubPath,
  required String topicId,
  required String quizId,
}) async {
  final fs = FirebaseFirestore.instance;
  final topicSnap = await fs.doc('$hubPath/quizTopics/$topicId').get();
  final topicData = topicSnap.data() ?? {};

  final sessionId = (topicData['sessionId'] as String?)?.trim();
  final runId = (topicData['activeRunId'] as String?)?.trim();

  if (sessionId == null ||
      sessionId.isEmpty ||
      runId == null ||
      runId.isEmpty) {
    return [];
  }

  final hubId = _extractHubId(hubPath);

  final quizSnap =
      await fs.doc('$hubPath/quizTopics/$topicId/quizzes/$quizId').get();
  final quizData = quizSnap.data() ?? {};

  final responsesSnap = await fs
      .collection('hubs/$hubId/sessions/$sessionId/quizRuns/$runId/responses')
      .get();

  final studentsSnap = await fs.collection('$hubPath/students').get();

  final studentNameById = <String, String>{
    for (final d in studentsSnap.docs)
      d.id: ((d.data()['name'] ?? d.data()['studentName'] ?? d.id).toString())
  };

  final options = (quizData['options'] as List?) ?? const [];
  final correctBinding =
      Map<String, dynamic>.from((quizData['correctBinding'] as Map?) ?? {});

  int correctIndex = -1;
  for (int i = 0; i < options.length; i++) {
    final opt = Map<String, dynamic>.from(options[i] as Map);
    final binding = Map<String, dynamic>.from(
      (opt['binding'] as Map?) ?? {},
    );

    final sameButton = binding['button'] == correctBinding['button'];
    final sameGesture = binding['gesture'] == correctBinding['gesture'];

    if (sameButton && sameGesture) {
      correctIndex = i;
      break;
    }
  }

  final quizResponses = responsesSnap.docs.where((d) {
    final x = d.data();
    return x['quizId'] == quizId;
  }).toList();

  final selectedStudentIdsByIndex = <int, List<String>>{
    for (int i = 0; i < options.length; i++) i: <String>[],
  };

  for (final responseDoc in quizResponses) {
    final x = responseDoc.data();
    final studentId = (x['studentId'] ?? '').toString();
    final selectedIndex = (x['selectedIndex'] as num?)?.toInt();

    if (studentId.isEmpty ||
        selectedIndex == null ||
        selectedIndex < 0 ||
        selectedIndex >= options.length) {
      continue;
    }

    selectedStudentIdsByIndex[selectedIndex]!.add(studentId);
  }

  final answeredCount = quizResponses.length;
  final items = <_ProblemOptionDetail>[];

  for (int i = 0; i < options.length; i++) {
    final opt = Map<String, dynamic>.from(options[i] as Map);
    final title = (opt['title'] ?? '').toString();
    final studentIds = selectedStudentIdsByIndex[i] ?? [];
    final names = studentIds.map((id) => studentNameById[id] ?? id).toList();

    final percent =
        answeredCount == 0 ? 0.0 : (studentIds.length / answeredCount) * 100.0;

    items.add(
      _ProblemOptionDetail(
        optionIndex: i,
        label: title,
        percent: percent,
        names: names,
        count: studentIds.length,
        isCorrect: i == correctIndex,
      ),
    );
  }

  return items;
}

Future<List<_StudentQuestionDetail>> _loadStudentExpandedDetails({
  required String hubPath,
  required String topicId,
  required String studentId,
}) async {
  final fs = FirebaseFirestore.instance;
  final topicSnap = await fs.doc('$hubPath/quizTopics/$topicId').get();
  final topicData = topicSnap.data() ?? {};

  final sessionId = (topicData['sessionId'] as String?)?.trim();
  final runId = (topicData['activeRunId'] as String?)?.trim();

  if (sessionId == null ||
      sessionId.isEmpty ||
      runId == null ||
      runId.isEmpty) {
    return [];
  }

  final hubId = _extractHubId(hubPath);

  final quizzesSnap = await fs
      .collection('$hubPath/quizTopics/$topicId/quizzes')
      .orderBy('createdAt')
      .get();

  final publicQuizDocs = quizzesSnap.docs.where((doc) {
    final data = doc.data();
    final p = data['public'];
    if (p is bool) return p;
    if (p is String) return p.toLowerCase() == 'true';
    return false;
  }).toList();

  final responsesSnap = await fs
      .collection('hubs/$hubId/sessions/$sessionId/quizRuns/$runId/responses')
      .get();

  final responseByQuizId = <String, Map<String, dynamic>>{};
  for (final doc in responsesSnap.docs) {
    final data = doc.data();
    if ((data['studentId'] ?? '').toString() != studentId) continue;
    final quizId = (data['quizId'] ?? '').toString();
    if (quizId.isEmpty) continue;
    responseByQuizId[quizId] = data;
  }

  final items = <_StudentQuestionDetail>[];

  for (int i = 0; i < publicQuizDocs.length; i++) {
    final quizDoc = publicQuizDocs[i];
    final quizData = quizDoc.data();

    final question = (quizData['question'] ?? '').toString();
    final options = (quizData['options'] as List?) ?? const [];
    final correctBinding =
        Map<String, dynamic>.from((quizData['correctBinding'] as Map?) ?? {});

    int correctIndex = -1;
    for (int j = 0; j < options.length; j++) {
      final opt = Map<String, dynamic>.from(options[j] as Map);
      final binding = Map<String, dynamic>.from(
        (opt['binding'] as Map?) ?? {},
      );

      final sameButton = binding['button'] == correctBinding['button'];
      final sameGesture = binding['gesture'] == correctBinding['gesture'];

      if (sameButton && sameGesture) {
        correctIndex = j;
        break;
      }
    }

    final response = responseByQuizId[quizDoc.id];
    final selectedIndex = (response?['selectedIndex'] as num?)?.toInt();
    final isCorrect = selectedIndex != null && selectedIndex == correctIndex;

    items.add(
      _StudentQuestionDetail(
        number: i + 1,
        question: question,
        isCorrect: isCorrect,
      ),
    );
  }

  return items;
}

class _ExpandedOptionRow extends StatelessWidget {
  const _ExpandedOptionRow({
    required this.detail,
  });

  final _ProblemOptionDetail detail;

  @override
  Widget build(BuildContext context) {
    final optionLetter = String.fromCharCode(65 + detail.optionIndex);

    return Padding(
      padding: const EdgeInsets.only(left: 44),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Row(
              children: [
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: Text(
                    '$optionLetter: ${detail.label}',
                    style: TextStyle(
                      color: const Color(0xFF111111),
                      fontSize: 14,
                      fontWeight:
                          detail.isCorrect ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 390,
                  child: Container(
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFD4D4D8),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (detail.percent / 100).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFA8E10C),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 165,
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                '${detail.percent.round()}%',
                style: TextStyle(
                  color: const Color(0xFF111111),
                  fontSize: 14,
                  fontWeight:
                      detail.isCorrect ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Text(
                detail.names.isEmpty ? '-' : detail.names.join(', '),
                style: TextStyle(
                  color: const Color(0xFF111111),
                  fontSize: 14,
                  fontWeight:
                      detail.isCorrect ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 110),
        ],
      ),
    );
  }
}

class _StudentQuestionResultRow extends StatelessWidget {
  const _StudentQuestionResultRow({
    required this.detail,
  });

  final _StudentQuestionDetail detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 214),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Text(
              '${detail.number}. ${detail.question}',
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                detail.isCorrect ? 'O' : 'X',
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 110),
          const SizedBox(width: 110),
        ],
      ),
    );
  }
}

class _TopTabButton extends StatelessWidget {
  const _TopTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Text(
        label,
        style: TextStyle(
          color: selected
              ? const Color(0xFF001A36)
              : const Color(0xFFA3A3A3),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailWaitingBox extends StatelessWidget {
  const _DetailWaitingBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9D9D9)),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

String _extractHubId(String hubPath) {
  final parts = hubPath.split('/');
  return parts.isNotEmpty ? parts.last : hubPath;
}

class _ProblemListBundle {
  final List<_ProblemListItem> items;

  const _ProblemListBundle({
    required this.items,
  });
}

class _ProblemListItem {
  final String quizId;
  final String question;
  final double answerRate;
  final int correctCount;
  final int totalCount;

  const _ProblemListItem({
    required this.quizId,
    required this.question,
    required this.answerRate,
    required this.correctCount,
    required this.totalCount,
  });
}

class _StudentListBundle {
  final List<_StudentListItem> items;

  const _StudentListBundle({
    required this.items,
  });
}

class _StudentListItemTemp {
  final String studentId;
  final String name;
  final double answerRate;
  final int correctCount;
  final int totalCount;

  const _StudentListItemTemp({
    required this.studentId,
    required this.name,
    required this.answerRate,
    required this.correctCount,
    required this.totalCount,
  });
}

class _StudentListItem {
  final String studentId;
  final String name;
  final double answerRate;
  final int rank;
  final int correctCount;
  final int totalCount;

  const _StudentListItem({
    required this.studentId,
    required this.name,
    required this.answerRate,
    required this.rank,
    required this.correctCount,
    required this.totalCount,
  });
}

class _ProblemOptionDetail {
  final int optionIndex;
  final String label;
  final double percent;
  final List<String> names;
  final int count;
  final bool isCorrect;

  const _ProblemOptionDetail({
    required this.optionIndex,
    required this.label,
    required this.percent,
    required this.names,
    required this.count,
    required this.isCorrect,
  });
}

class _StudentQuestionDetail {
  final int number;
  final String question;
  final bool isCorrect;

  const _StudentQuestionDetail({
    required this.number,
    required this.question,
    required this.isCorrect,
  });
}