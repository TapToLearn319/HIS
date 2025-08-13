import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as dev;

import '../../../main.dart';

class RandomGroupingPage extends StatefulWidget {
  const RandomGroupingPage({super.key});

  @override
  State<RandomGroupingPage> createState() => _RandomGroupingPageState();
}

enum GroupingMode { byGroups, bySize }

class _RandomGroupingPageState extends State<RandomGroupingPage>
    with SingleTickerProviderStateMixin {
  // Firestore 히스토리(그룹 기록) 사용 여부
  final bool useFirestoreHistory = false;
  static const int _historyLimit = 20;

  // ----- 학생 목록 (Firestore에서 채움) -----
  final List<String> _allStudents = <String>[];
  final Set<String> _selected = <String>{};
  String _query = '';
  final TextEditingController _addCtrl = TextEditingController();
  final _fs = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _studentsSub;
  bool _firstStudentsLoad = true; // 첫 로드 시 전체 선택

  // 그룹 옵션
  GroupingMode _mode = GroupingMode.byGroups;
  int _groupsCount = 4;
  int _sizePerGroup = 3;

  late final TabController _tab;

  @override
  void initState() {
    super.initState();

    _tab = TabController(length: 2, vsync: this, initialIndex: 0);
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      setState(() {
        _mode = _tab.index == 0 ? GroupingMode.byGroups : GroupingMode.bySize;
      });
    });

    // 학생 화면에 "grouping 모드" 브로드캐스트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      channel.postMessage(jsonEncode({'type': 'tool_mode', 'mode': 'grouping'}));
    });

    _listenStudentsFromFirestore();
  }

  @override
  void dispose() {
    _tab.dispose();
    _addCtrl.dispose();
    _studentsSub?.cancel();
    super.dispose();
  }

  // ===== Firestore에서 학생 목록 리슨 =====
  void _listenStudentsFromFirestore() {
    _studentsSub = _fs
        .collection('students')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
      final names = snap.docs
          .map((d) {
            final data = d.data();
            final n = (data['name'] ?? d.id).toString().trim();
            return n.isEmpty ? d.id : n;
          })
          .where((n) => n.isNotEmpty)
          .toList();

      setState(() {
        _allStudents
          ..clear()
          ..addAll(names);

        if (_firstStudentsLoad) {
          _selected
            ..clear()
            ..addAll(names);
          _firstStudentsLoad = false;
        } else {
          // 기존 선택 유지(없어진 이름만 제거)
          _selected.removeWhere((s) => !names.contains(s));
        }
      });

      dev.log('[Grouping] students loaded: ${names.length}');
    }, onError: (e, st) {
      dev.log('[Grouping] students listener error: $e', stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load students: $e')),
        );
      }
    });
  }

  // ===== 그룹 만들기 =====
  Future<void> _makeGroups() async {
    try {
      final selected = _allStudents.where(_selected.contains).toList();
      if (selected.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택된 학생이 2명 이상이어야 합니다.')),
        );
        return;
      }

      List<List<String>> groups;
      if (useFirestoreHistory) {
        groups = await _makeBestGroupsWithHistory(selected);
      } else {
        groups = _generateOnce(selected);
      }

      // 학생 화면 브로드캐스트
      channel.postMessage(
        jsonEncode({
          'type': 'grouping_result',
          'title': 'Find your Team !',
          'groups': groups,
        }),
      );

      // Firestore에 세션 저장(옵션)
      if (useFirestoreHistory) {
        await _fs.collection('groupingSessions').add({
          'createdAt': FieldValue.serverTimestamp(),
          'mode': _mode == GroupingMode.byGroups ? 'byGroups' : 'bySize',
          'groups': groups,
          'selected': selected,
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('그룹 생성 중 오류: $e')),
      );
    }
  }

  // ===== 히스토리 기반 최적화 =====
  Future<List<List<String>>> _makeBestGroupsWithHistory(
    List<String> selected,
  ) async {
    final penalty = await _buildPairPenalty(selected.toSet());
    const int trials = 120;
    List<List<String>> best = [];
    int bestScore = 1 << 30;

    for (int t = 0; t < trials; t++) {
      final candidate = _generateOnce(selected);
      final s = _scoreGroups(candidate, penalty);
      if (s < bestScore) {
        best = candidate;
        bestScore = s;
      }
    }
    return best;
  }

  Future<Map<String, int>> _buildPairPenalty(Set<String> population) async {
    try {
      final q = await _fs
          .collection('groupingSessions')
          .orderBy('createdAt', descending: true)
          .limit(_historyLimit)
          .get();

      const int maxW = 10;
      const int minW = 1;
      final int steps = q.docs.isEmpty ? 1 : q.docs.length.clamp(1, maxW);
      final int step = ((maxW - minW) ~/ steps);
      final int clampedStep = step.clamp(0, 9);

      final Map<String, int> penalty = <String, int>{};

      int idx = 0;
      for (final doc in q.docs) {
        final data = doc.data();
        final List<dynamic> groupsRaw = (data['groups'] as List?) ?? const [];
        final int weight = (maxW - idx * clampedStep).clamp(minW, maxW) as int;

        for (final g in groupsRaw) {
          if (g is! List) continue;
          final members = g
              .map((e) => e.toString())
              .where((name) => population.contains(name))
              .toList();

          for (int i = 0; i < members.length; i++) {
            for (int j = i + 1; j < members.length; j++) {
              final k = _pairKey(members[i], members[j]);
              final prev = penalty[k] ?? 0;
              penalty[k] = prev + weight;
            }
          }
        }
        idx++;
      }
      return penalty;
    } catch (e, st) {
      dev.log('[Grouping] buildPairPenalty failed: $e', stackTrace: st);
      return <String, int>{};
    }
  }

  String _pairKey(String a, String b) {
    return (a.compareTo(b) <= 0) ? '$a|$b' : '$b|$a';
  }

  int _scoreGroups(List<List<String>> groups, Map<String, int> penalty) {
    int score = 0;
    for (final g in groups) {
      for (int i = 0; i < g.length; i++) {
        for (int j = i + 1; j < g.length; j++) {
          score += penalty[_pairKey(g[i], g[j])] ?? 0;
        }
      }
    }
    return score;
  }

  // 현재 옵션으로 한 번 그룹 생성
  List<List<String>> _generateOnce(List<String> selected) {
    final rnd = Random();
    final names = [...selected]..shuffle(rnd);
    if (_mode == GroupingMode.byGroups) {
      final n = _groupsCount.clamp(1, names.length);
      final groups = List.generate(n, (_) => <String>[]);
      for (int i = 0; i < names.length; i++) {
        groups[i % n].add(names[i]);
      }
      return groups;
    } else {
      final size = _sizePerGroup.clamp(1, names.length);
      final n = (names.length / size).ceil();
      final groups = List.generate(n, (_) => <String>[]);
      int gi = 0;
      for (final name in names) {
        groups[gi].add(name);
        if (groups[gi].length >= size) gi++;
        if (gi >= groups.length) gi = groups.length - 1;
      }
      return groups;
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final filtered =
        _allStudents.where((s) => s.toLowerCase().contains(_query.toLowerCase())).toList();

    final totalSelected = _selected.length;
    final groupsPreview = List.generate(9, (i) => i + 2); // 2~10
    final sizePreview = List.generate(9, (i) => i + 2);   // 2~10

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF4F8FD),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 제목
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                  child: Text(
                    'Choose List',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0B1324),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 왼쪽 카드: 리스트
                    Expanded(flex: 5, child: _buildChooseListCard(filtered)),
                    const SizedBox(width: 24),

                    // 오른쪽 카드: How to
                    Expanded(
                      flex: 5,
                      child: _buildHowToCard(
                        totalSelected: totalSelected,
                        groupsPreview: groupsPreview,
                        sizePreview: sizePreview,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // 오른쪽 하단 MAKE 버튼
          Positioned(
            right: 24,
            bottom: 40,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _makeGroups,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset('assets/logo_bird.png', height: 160),
                    const Positioned(
                      left: 50,
                      bottom: 50,
                      child: Text(
                        'MAKE',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- 왼쪽 카드 -----
  Widget _buildChooseListCard(List<String> filtered) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFD2D2D2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: SizedBox(
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  Text(
                    'TOTAL ${_selected.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  // search
                  SizedBox(
                    width: 240,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search name',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // add name (로컬 리스트에만 추가)
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _addCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Add name',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final t = _addCtrl.text.trim();
                        if (t.isEmpty) return;
                        setState(() {
                          _allStudents.add(t);
                          _selected.add(t);
                          _addCtrl.clear();
                        });
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // select all
              Row(
                children: [
                  Checkbox(
                    value: _selected.length == _allStudents.length &&
                        _allStudents.isNotEmpty,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected
                            ..clear()
                            ..addAll(_allStudents);
                        } else {
                          _selected.clear();
                        }
                      });
                    },
                  ),
                  const Text('Select All'),
                ],
              ),
              const Divider(height: 16),

              // list
              Expanded(
                child: Scrollbar(
                  child: GridView.builder(
                    itemCount: filtered.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 6,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 2,
                    ),
                    itemBuilder: (_, i) {
                      final name = filtered[i];
                      final selected = _selected.contains(name);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selected.remove(name);
                            } else {
                              _selected.add(name);
                            }
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: selected
                                  ? const Color(0xFF46A5FF)
                                  : const Color(0xFF9AA6B2),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (selected)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: CircleAvatar(
                                  radius: 5,
                                  backgroundColor: Color(0xFF46A5FF),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- 오른쪽 카드 -----
  Widget _buildHowToCard({
    required int totalSelected,
    required List<int> groupsPreview,
    required List<int> sizePreview,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFD2D2D2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: SizedBox(
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'How to',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              TabBar(
                controller: _tab,
                isScrollable: true,
                indicatorWeight: 3,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                indicatorColor: const Color(0xFF111827),
                labelColor: const Color(0xFF111827),
                unselectedLabelColor: const Color(0xFF9AA6B2),
                tabs: const [
                  Tab(text: 'Number of groups'),
                  Tab(text: 'Participants per group'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    // 그룹 수
                    _radioList(
                      items: groupsPreview,
                      isGroupsMode: true,
                      totalSelected: totalSelected,
                      value: _groupsCount,
                      onChange: (v) => setState(() => _groupsCount = v),
                    ),
                    // 그룹 인원
                    _radioList(
                      items: sizePreview,
                      isGroupsMode: false,
                      totalSelected: totalSelected,
                      value: _sizePerGroup,
                      onChange: (v) => setState(() => _sizePerGroup = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioList({
    required List<int> items,
    required bool isGroupsMode,
    required int totalSelected,
    required int value,
    required ValueChanged<int> onChange,
  }) {
    return Scrollbar(
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          final n = items[i];
          late final String label;
          if (isGroupsMode) {
            final participants =
                totalSelected == 0 ? 0 : (totalSelected / n).ceil();
            label = '$n groups - $participants participants';
          } else {
            final groups = n == 0 ? 0 : (totalSelected / n).ceil();
            label = '$n participants - $groups groups';
          }

          return RadioListTile<int>(
            value: n,
            groupValue: value,
            onChanged: (v) => onChange(v ?? value),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(label),
            activeColor: const Color(0xFF46A5FF),
          );
        },
      ),
    );
  }

  Widget _teamCard(int index, List<String> members) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6ECF5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Team $index',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) => Center(
                child: Text(
                  members[i],
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
