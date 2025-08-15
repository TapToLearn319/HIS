import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/session_provider.dart';

const String kHubId = 'hub-001';        // 허브 지정해둠

class DisplayVotePage extends StatefulWidget {
  const DisplayVotePage({
    super.key,
    this.enableTapVote = false,
    this.voteId,
  });

  final bool enableTapVote;
  final String? voteId;

  @override
  State<DisplayVotePage> createState() => _DisplayVotePageState();
}

class _DisplayVotePageState extends State<DisplayVotePage> {
  String? _sid;
  String? _voteId;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _hubSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _voteDocSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _votesColSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _evSub;

  String _title = '';
  List<_Opt> _opts = [];
  int _total = 0;
  Timestamp? _startedAt;

  @override
  void initState() {
    super.initState();
    _bindSessionFromHub();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sid = context.read<SessionProvider>().sessionId;
      if (sid != null) _rebindSession(sid);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sid = context.watch<SessionProvider>().sessionId;
    if (sid != _sid && sid != null) _rebindSession(sid);
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }


  void _bindSessionFromHub() {
    _hubSub?.cancel();
    _hubSub = FirebaseFirestore.instance.doc('hubs/$kHubId').snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;
      final hubSid = (data['currentSessionId'] ?? '').toString().trim();
      if (hubSid.isEmpty) return;

      final sp = context.read<SessionProvider>();
      if (sp.sessionId != hubSid) {
        sp.setSession(hubSid);
        _showSnack('세션 연결: $hubSid');
        _rebindSession(hubSid);
      }
    }, onError: (e) {
      debugPrint('[DisplayVote] hub watcher error: $e');
      _showSnack('허브 세션 구독 실패: $e');
    });
  }

  void _cancelAll() {
    _hubSub?.cancel();
    _voteDocSub?.cancel();
    _votesColSub?.cancel();
    _evSub?.cancel();
    _hubSub = null;
    _voteDocSub = null;
    _votesColSub = null;
    _evSub = null;
  }

  void _resetState({bool keepVoteId = false}) {
    setState(() {
      if (!keepVoteId) _voteId = null;
      _title = '';
      _opts = [];
      _total = 0;
      _startedAt = null;
    });
  }

  Future<void> _rebindSession(String? sid) async {
    _voteDocSub?.cancel();
    _votesColSub?.cancel();
    _evSub?.cancel();

    _sid = sid;
    _resetState();

    if (sid == null) return;

    if (widget.voteId != null) {
      _attachVoteDoc(sid, widget.voteId!);
    } else {
      _attachActiveWatcher(sid);
    }
  }


  void _attachActiveWatcher(String sid) {
    _votesColSub = FirebaseFirestore.instance
        .collection('sessions/$sid/votes')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((qs) {
      if (qs.docs.isEmpty) {
        _evSub?.cancel();
        _resetState();
        return;
      }

      QueryDocumentSnapshot<Map<String, dynamic>> latest = qs.docs.first;
      int best = _tsScore(latest.data());
      for (final d in qs.docs.skip(1)) {
        final sc = _tsScore(d.data());
        if (sc > best) {
          latest = d;
          best = sc;
        }
      }
      if (_voteId != latest.id) {
        _attachVoteDoc(sid, latest.id);
      }
    }, onError: (e) {
      debugPrint('[DisplayVote] votes watcher error: $e');
      _showSnack('투표 목록 구독 실패: $e');
    });
  }

  int _tsScore(Map<String, dynamic> d) {
    final started = d['startedAt'] as Timestamp?;
    final updated = d['updatedAt'] as Timestamp?;
    return (started ?? updated ?? Timestamp(0, 0)).millisecondsSinceEpoch;
  }

  void _attachVoteDoc(String sid, String voteId) {
    _voteDocSub?.cancel();
    _evSub?.cancel();

    _voteId = voteId;
    _title = '';
    _opts = [];
    _total = 0;
    _startedAt = null;
    setState(() {});

    _voteDocSub = FirebaseFirestore.instance
        .doc('sessions/$sid/votes/$voteId')
        .snapshots()
        .listen((doc) {
      final d = doc.data();
      if (d == null) {
        _resetState();
        return;
      }

      final title = (d['title'] ?? '').toString();
      final startedAt = d['startedAt'] as Timestamp?;
      final raw = (d['options'] as List?) ?? const [];

      final opts = <_Opt>[];
      for (final it in raw) {
        if (it is Map) {
          final label = (it['title'] ?? '').toString();
          final b = (it['binding'] as Map?) ?? const {};
          // 버튼 매핑: devices 로그는 slotIndex '1'|'2', clickType 'hold'|'single'
          final btn = (b['button'] is num) ? (b['button'] as num).toInt() : 1;
          final ges = (b['gesture'] ?? 'single').toString();
          opts.add(_Opt(label: label, button: btn, gesture: ges));
        } else if (it is String) {
          opts.add(_Opt(label: it, button: 1, gesture: 'single'));
        }
      }

      setState(() {
        _title = title;
        _opts = opts;
        _startedAt = startedAt ?? d['updatedAt'] as Timestamp?;
      });

      _attachEvents();
    }, onError: (e) {
      debugPrint('[DisplayVote] vote doc error: $e');
      _showSnack('투표 문서 구독 실패: $e');
    });
  }

  void _attachEvents() {
    final sid = _sid;
    final startedAt = _startedAt;
    if (sid == null || startedAt == null) {
      _evSub?.cancel();
      setState(() {
        _total = 0;
        _opts = _opts.map((o) => o.copyWith(votes: 0)).toList();
      });
      return;
    }

    _evSub?.cancel();
    final q = FirebaseFirestore.instance
        .collection('sessions/$sid/events')
        .where('ts', isGreaterThanOrEqualTo: startedAt);

    _evSub = q.snapshots().listen((snap) {
      final Map<String, _Ev> last = {};
      for (final d in snap.docs) {
        final x = d.data();
        final studentId = (x['studentId'] ?? '') as String;
        if (studentId.isEmpty) continue;

        final slot = x['slotIndex']?.toString();
        if (slot != '1' && slot != '2') continue;

        final clickType = (x['clickType'] ?? x['lastClickType'] ?? 'click').toString();
        final score = (x['hubTs'] is num)
            ? (x['hubTs'] as num).toInt()
            : ((x['ts'] is Timestamp) ? (x['ts'] as Timestamp).millisecondsSinceEpoch : 0);

        final cur = last[studentId];
        if (cur == null || score >= cur.score) {
          last[studentId] = _Ev(
            score: score,
            button: slot == '1' ? 1 : 2,
            gesture: clickType == 'hold' ? 'hold' : 'single',
          );
        }
      }

      final counts = List<int>.filled(_opts.length, 0);
      for (final ev in last.values) {
        final idx = _opts.indexWhere(
          (o) => o.button == ev.button && o.gesture == ev.gesture,
        );
        if (idx >= 0) counts[idx] += 1;
      }

      final total = counts.fold<int>(0, (a, b) => a + b);
      setState(() {
        for (int i = 0; i < _opts.length; i++) {
          _opts[i] = _opts[i].copyWith(votes: counts[i]);
        }
        _total = total;
      });
    }, onError: (e) {
      debugPrint('[DisplayVote] events error: $e');
      _showSnack('이벤트 구독 실패: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final sid = context.watch<SessionProvider>().sessionId;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text('Vote (Student)${sid == null ? '' : ' • $sid'}'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: (_voteId == null)
                ? const _Idle()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _title.isEmpty ? 'Untitled question' : _title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_total} VOTERS',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12.withOpacity(0.08)),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Column(
                          children: [
                            for (var i = 0; i < _opts.length; i++) ...[
                              _barRow(
                                label: _opts[i].label,
                                votes: _opts[i].votes,
                                total: _total,
                                badge: '${_opts[i].button} ${_opts[i].gesture}',
                                onTap: () => _tapVoteDebug,
                              ),
                              if (i != _opts.length - 1) const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _barRow({
  required String label,
  required int votes,
  required int total,
  required String badge,
  required VoidCallback onTap,
}) {
  const yellow = Color(0xFFFFE483);
  final ratio = total == 0 ? 0.0 : (votes / total);

  return InkWell(
    onTap: widget.enableTapVote ? onTap : null,
    borderRadius: BorderRadius.circular(28),
    child: Row(
      children: [
        // ▶ 바(라벨/배지 포함)
        Expanded(
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.black12.withOpacity(0.12)),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                // 채워질 너비 (좌우 패딩 + 원 영역을 약간 제외해 시각적으로 예쁜 값)
                final maxW = c.maxWidth;
                final fillW = (maxW * ratio).clamp(0.0, maxW);

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // 채워진 노란 영역 (완전 둥근)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: fillW,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: yellow,
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),

                    // 왼쪽 노란 원
                    const Positioned(
                      left: 12,
                      child: _YellowBubble(),
                    ),

                    // 내용(라벨, 배지)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          const SizedBox(width: 34), // 노란 원 공간 띄우기
                          // 라벨
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 배지 (예: "1 single")
                          _badge(badge),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(width: 12),

        // ▶ 퍼센트 (바 오른쪽 바깥)
        SizedBox(
          width: 48,
          child: Text(
            total == 0 ? '0%' : '${(ratio * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _badge(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.black12.withOpacity(0.25), width: 1),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  );
}

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Idle extends StatelessWidget {
  const _Idle();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text('대기 중… 활성 투표가 시작되면 표시됩니다', style: TextStyle(color: Colors.black54)),
      ),
    );
  }
}

class _Opt {
  final String label;
  final int button;     // 1 | 2
  final String gesture; // 'single' | 'hold'
  final int votes;
  _Opt({required this.label, required this.button, required this.gesture, this.votes = 0});
  _Opt copyWith({int? votes}) =>
      _Opt(label: label, button: button, gesture: gesture, votes: votes ?? this.votes);
}

class _Ev {
  final int score;
  final int button;
  final String gesture;
  _Ev({required this.score, required this.button, required this.gesture});
}

class _YellowBubble extends StatelessWidget {
  const _YellowBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFFFE483),
        shape: BoxShape.circle,
      ),
    );
  }
}


void _tapVoteDebug() {
  print('✅ Debug: vote tapped!');
}