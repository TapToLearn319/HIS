// lib/pages/tools/display_vote_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';

import '../../../provider/session_provider.dart';
import '../../../provider/hub_provider.dart';
import '../../display_standby.dart';

class DisplayVotePage extends StatefulWidget {
  const DisplayVotePage({super.key, this.enableTapVote = false, this.voteId});

  final bool enableTapVote;
  final String? voteId;

  @override
  State<DisplayVotePage> createState() => _DisplayVotePageState();
}

class _DisplayVotePageState extends State<DisplayVotePage> {
  String? _hubId;
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
  int? _startedAtMs;

  String _showMode = 'realtime';
  String _status = 'draft';
  bool _anonymous = true;
  bool _multi = false;
  bool _revealNow = false;

  IconData _iconForGesture(String gesture) {
    switch (gesture) {
      case 'hold':
        return Icons.touch_app;
      case 'single':
      default:
        return Icons.pan_tool_alt;
    }
  }

  void dlog(Object? msg) {
    print('[Display] $msg');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hubId = context.read<HubProvider>().hubId;
      final sid = context.read<SessionProvider>().sessionId;
      if (hubId != null) _bindHub(hubId);
      if (sid != null) _rebindSession(sid);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hubId = context.watch<HubProvider>().hubId;
    if (_hubId != hubId && hubId != null) _bindHub(hubId);
    final sid = context.watch<SessionProvider>().sessionId;
    if (_sid != sid && sid != null) _rebindSession(sid);
  }

  Color _colorForBinding(int button, String gesture) {
    if (button == 1) {
      return const Color(0xff70D71C);
    } else {
      return const Color(0xff9A6EFF);
    }
  }

  String _labelForBinding(int button, String gesture) {
  // click(=single)일 때는 빈 문자열, hold일 때만 'hold'
  return (gesture == 'hold') ? 'hold' : '';
}

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }

  void _cancelAll() {
    _hubSub?.cancel();
    _voteDocSub?.cancel();
    _votesColSub?.cancel();
    _evSub?.cancel();
  }

  void _resetState({bool keepVoteId = false}) {
    setState(() {
      if (!keepVoteId) _voteId = null;
      _title = '';
      _opts = [];
      _total = 0;
      _startedAt = null;
      _startedAtMs = null;
    });
  }

  String _anonKeyOf(String studentId) {
    final salt = (_startedAtMs?.toString() ?? _voteId ?? 'no-vote');
    return sha1.convert(utf8.encode('$salt|$studentId')).toString();
  }

  void _bindHub(String hubId) {
    _hubId = hubId;
    _hubSub?.cancel();

    _hubSub = FirebaseFirestore.instance.doc('hubs/$hubId').snapshots().listen(
      (doc) {
        final data = doc.data();
        if (data == null) return;

        final hubSid = (data['currentSessionId'] ?? '').toString().trim();
        final hubVoteId = (data['currentVoteId'] ?? '').toString().trim();

        if (data['revealNow'] == true && !_revealNow) {
          setState(() => _revealNow = true);
        }

        if (hubSid.isNotEmpty) {
          final sp = context.read<SessionProvider>();
          if (sp.sessionId != hubSid) {
            sp.setSession(hubSid);
            _rebindSession(hubSid);
          } else if (_sid != hubSid) {
            _rebindSession(hubSid);
          }
        }

        if (hubSid.isNotEmpty && hubVoteId.isNotEmpty) {
          if (_sid != hubSid || _voteId != hubVoteId) {
            _attachVoteDoc(hubSid, hubVoteId);
          }
        } else if (hubSid.isNotEmpty && widget.voteId == null) {
          _attachActiveWatcher(hubId);
        }
      },
    );
  }

  Future<void> _rebindSession(String? sid) async {
    _voteDocSub?.cancel();
    _votesColSub?.cancel();
    _evSub?.cancel();
    _sid = sid;
    _resetState();
    if (sid == null) return;
    if (widget.voteId != null && _hubId != null) {
      _attachVoteDoc(sid, widget.voteId!);
    }
  }

  void _attachActiveWatcher(String hubId) {
  _votesColSub?.cancel();
  _votesColSub = FirebaseFirestore.instance
      .collection('hubs/$hubId/votes')
      .where('status', isEqualTo: 'active') // ✅ stopped 제외
      .snapshots()
      .listen((qs) {
    if (qs.docs.isEmpty) {
      _evSub?.cancel();
      // ✅ active 없을 때는 초기화 X (stopped 투표 유지 위해)
      return;
    }

    final docs = qs.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
    final latest = docs.reduce((a, b) {
      final ta = _tsScore(a.data());
      final tb = _tsScore(b.data());
      return ta > tb ? a : b;
    });

    if (_voteId != latest.id) {
      final sid = _sid;
      if (sid != null) _attachVoteDoc(sid, latest.id);
    }
  });
}


  int _tsScore(Map<String, dynamic> d) {
    final updated = d['updatedAt'] as Timestamp?;
    final started = d['startedAt'] as Timestamp?;
    return (updated ?? started ?? Timestamp(0, 0)).millisecondsSinceEpoch;
  }

  // ✅ 핵심 변경 부분: 상태 기반 전환 로직 추가
  // ✅ 핵심 변경된 _attachVoteDoc 버전
void _attachVoteDoc(String sid, String voteId) {
  _voteDocSub?.cancel();
  _evSub?.cancel();

  final hubId = _hubId;
  if (hubId == null) return;

  _voteId = voteId;
  _title = '';
  _opts = [];
  _total = 0;
  _startedAt = null;
  setState(() {});

  _voteDocSub = FirebaseFirestore.instance
      .doc('hubs/$hubId/votes/$voteId')
      .snapshots()
      .listen((doc) {
    final d = doc.data();
    if (d == null) {
      _resetState();
      return;
    }

    final title = (d['title'] ?? '').toString();
    final startedAt = d['startedAt'] as Timestamp?;
    final startedAtMs =
        (d['startedAtMs'] is num) ? (d['startedAtMs'] as num).toInt() : null;

    final settings = (d['settings'] as Map?) ?? const {};
    final showMode = (settings['show'] ?? 'realtime').toString();
    final status = (d['status'] ?? 'draft').toString();
    final anonymous = (settings['anonymous'] == true);
    final multi = (settings['multi'] == true);
     final revealNow = (d['revealNow'] == true);
    _revealNow = revealNow;
    _status = status;

    final rawOpts = (d['options'] as List?) ?? const [];
    final newOpts = rawOpts.map<_Opt>((it) {
      if (it is Map) {
        final b = (it['binding'] as Map?) ?? {};
        final label = (it['title'] ?? '').toString();
        final btn = (b['button'] is num) ? (b['button'] as num).toInt() : 1;
        final ges = (b['gesture'] ?? 'single').toString();
        return _Opt(label: label, button: btn, gesture: ges);
      } else {
        return _Opt(label: it.toString(), button: 1, gesture: 'single');
      }
    }).toList();

    setState(() {
      // ✅ stopped일 때는 기존 _opts의 votes를 유지
      if (status == 'stopped' && _opts.isNotEmpty) {
        _opts = _opts; // 유지 (덮지 않음)
      } else {
        _opts = newOpts;
      }

      _status = status;
      _showMode = showMode;
      _revealNow = revealNow;
    });

    // ✅ 상태별 동작
    if (status == 'active') {
  // ✅ Firestore 비동기 반영 시점 보정
  if (startedAtMs == null) {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _status == 'active' && _startedAtMs != null) {
        _attachEvents();
      }
    });
  } else {
    _attachEvents();
  }
} else if (status == 'stopped') {
  _evSub?.cancel();

  // ✅ 집계 중단 후 그래프 유지
  if (showMode == 'after') {
    setState(() => _revealNow = true); // 결과 공개
  }
} else if (status == 'closed') {
  // ✅ Done일 때 대기화면 가지 않도록 예외 처리
  if (_status == 'done') return;
  Future.delayed(const Duration(seconds: 2), () {
    if (!mounted) return;
    if (_status == 'closed') {
      _evSub?.cancel();
      _resetState();
    }
  });
}
  });
}


  void _attachEvents() {
  final hubId = _hubId, sid = _sid, startedMs = _startedAtMs;
  if (hubId == null || sid == null) return;

  final effectiveStart = (startedMs ?? DateTime.now().millisecondsSinceEpoch - 3000);
  // ✅ 3초 정도 여유 줘서 집계 누락 방지

  _evSub?.cancel();
  final q = FirebaseFirestore.instance
      .collection('hubs/$hubId/liveByDevice')
      .where('lastHubTs', isGreaterThanOrEqualTo: effectiveStart)
      .where('sessionId', isEqualTo: sid);

  _evSub = q.snapshots().listen((snap) {
    if (_status != 'active') return;

    final Map<String, _Ev> last = {};
    for (final d in snap.docs) {
      final x = d.data();
      final id = (x['studentId'] ?? '').toString();
      if (id.isEmpty) continue;
      final key = _anonymous ? _anonKeyOf(id) : id;
      final slot = x['slotIndex']?.toString();
      final click = (x['clickType'] ?? 'click').toString();
      final score = (x['lastHubTs'] is num) ? (x['lastHubTs'] as num).toInt() : 0;
      if (slot != '1' && slot != '2') continue;
      final cur = last[key];
      if (cur == null || score > cur.score) {
        last[key] = _Ev(
          score: score,
          button: slot == '1' ? 1 : 2,
          gesture: click == 'hold' ? 'hold' : 'single',
        );
      }
    }

    final counts = List<int>.filled(_opts.length, 0);
    for (final ev in last.values) {
      final idx = _opts.indexWhere(
          (o) => o.button == ev.button && o.gesture == ev.gesture);
      if (idx >= 0) counts[idx]++;
    }

    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _opts.length; i++) {
        _opts[i] = _opts[i].copyWith(votes: counts[i]);
      }
      _total = last.length;
    });
  });
}


  @override
  Widget build(BuildContext context) {
    final hubId = context.watch<HubProvider>().hubId;
    if (hubId == null || _voteId == null || _status == 'closed') {
      return const Scaffold(body: Center(child: DisplayStandByPage()));
    }

    final bool hide =
    (_status == 'active') && (_showMode == 'after' && !_revealNow);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _title.isEmpty ? 'Untitled question' : _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 41,
                      fontWeight: FontWeight.w500,
                      color: Colors.black),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_total} VOTERS',
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                        color: Colors.black),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.black12.withOpacity(0.08))),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(children: [
                    if (hide)
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Results will be shown after voting ends',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    for (var i = 0; i < _opts.length; i++) ...[
                      _barRow(
                        label: _opts[i].label,
                        votes: _opts[i].votes,
                        total: _total,
                        button: _opts[i].button,
                        gesture: _opts[i].gesture,
                        onTap: _tapVoteDebug,
                        hideResults: hide,
                        alwaysShowMapping: (_showMode == 'after'),
                      ),
                      if (i != _opts.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ]),
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
    required int button,
    required String gesture,
    required VoidCallback onTap,
    bool hideResults = false,
    bool alwaysShowMapping = false,
  }) {
    const yellow = Color(0xFFFFE483);
    final double ratio = hideResults
    ? 0.5 // 👈 숨김 모드에서는 절반만 채운 막대 유지
    : (total > 0 ? (votes / total) : 0.0);
    final String percentText =
        hideResults ? '—' : (total == 0 ? '0%' : '${(ratio * 100).round()}%');

    return InkWell(
      onTap: widget.enableTapVote ? onTap : null,
      child: Row(children: [
        Expanded(
          child: Container(
            height: 64,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.black12.withOpacity(0.12)),
            ),
            child: LayoutBuilder(builder: (context, c) {
              final fillW = c.maxWidth * ratio;
              return Stack(alignment: Alignment.centerLeft, children: [
                AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: fillW,
                    height: double.infinity,
                    color: yellow),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(children: [
                    const SizedBox(width: 34),
                    Expanded(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.black))),
                    const SizedBox(width: 12),
                    if (alwaysShowMapping || !hideResults)
                      Builder(builder: (context) {
                        final mapColor = _colorForBinding(button, gesture);
                        final isHold = (gesture == 'hold');

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isHold ? 80 : 36, // ✅ hold면 가로로 늘림
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: mapColor,
                            borderRadius: BorderRadius.circular(999), // ✅ 원형 유지
                            border: Border.all(color: mapColor.withOpacity(0.7)),
                          ),
                          child: isHold
                              ? const Text(
                                  'hold',
                                  style: TextStyle(
                                    color: Colors.white, // ✅ 흰색 텍스트
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                )
                              : null, // ✅ single일 때는 텍스트 없음
                        );
                      })
                    else
                      const Text('Hidden',
                          style: TextStyle(
                              fontSize: 12, color: Colors.black54)),
                  ]),
                )
              ]);
            }),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
            width: 48,
            child: Text(percentText,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16))),
      ]),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Opt {
  final String label;
  final int button;
  final String gesture;
  final int votes;
  _Opt(
      {required this.label,
      required this.button,
      required this.gesture,
      this.votes = 0});
  _Opt copyWith({int? votes}) =>
      _Opt(label: label, button: button, gesture: gesture, votes: votes ?? this.votes);
}

class _Ev {
  final int score;
  final int button;
  final String gesture;
  _Ev({
    required this.score,
    required this.button,
    required this.gesture,
  });
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
  debugPrint('✅ Debug: vote tapped!');
}
