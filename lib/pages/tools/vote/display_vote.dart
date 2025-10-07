import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';

import '../../../provider/session_provider.dart';
import '../../../provider/hub_provider.dart'; // ⬅️ 허브 구독 추가
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
    // ignore: avoid_print
    print('[Display] $msg');
  }

  @override
  void initState() {
    super.initState();
    // 최초 바인딩: HubProvider에서 hubId 받아서 허브 문서 구독
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
    if (_hubId != hubId && hubId != null) {
      _bindHub(hubId);
    }
    final sid = context.watch<SessionProvider>().sessionId;
    if (sid != _sid && sid != null) {
      _rebindSession(sid);
    }
  }

  // 버튼(1/2)과 제스처(single/hold)에 따른 대표 색
Color _colorForBinding(int button, String gesture) {
  // 1: Red 계열, 2: Blue 계열
  if (button == 1) {
    return (gesture == 'hold')
        ? const Color(0xFFF87171) // Red - hold
        : const Color(0xFFF87171); // Red - click
  } else {
    return (gesture == 'hold')
        ? const Color(0xFF60A5FA) // Blue - hold
        : const Color(0xFF60A5FA); // Blue - click
  }
}

// 버튼 숫자 대신 표시할 라벨
String _labelForBinding(int button, String gesture) {
  final b = (button == 1) ? 'red' : 'blue';
  final g = (gesture == 'hold') ? 'hold' : 'click';
  return '$b-$g';
}


  @override
  void dispose() {
    _cancelAll();
    super.dispose();
  }

  void _bindHub(String hubId) {
    _hubId = hubId;
    _hubSub?.cancel();

    _hubSub = FirebaseFirestore.instance
        .doc('hubs/$hubId')
        .snapshots()
        .listen(
          (doc) {
            final data = doc.data();
            if (data == null) return;

            final hubSid = (data['currentSessionId'] ?? '').toString().trim();
            final hubVoteId = (data['currentVoteId'] ?? '').toString().trim();

            if (hubSid.isNotEmpty) {
              final sp = context.read<SessionProvider>();
              if (sp.sessionId != hubSid) {
                sp.setSession(hubSid);
                _rebindSession(hubSid);
              } else if (_sid != hubSid) {
                _rebindSession(hubSid);
              }
            }

            // 허브가 현재 투표를 알려주면 그걸로 즉시 붙음
            if (hubSid.isNotEmpty && hubVoteId.isNotEmpty) {
              if (_sid != hubSid || _voteId != hubVoteId) {
                _attachVoteDoc(hubSid, hubVoteId);
              }
            } else if (hubSid.isNotEmpty && widget.voteId == null) {
              // currentVoteId가 없을 때는 active fallback 감시(허브 스코프)
              _attachActiveWatcher(hubId);
            }
          },
          onError: (e) {
            dlog('[DisplayVote] hub watcher error: $e');
            _showSnack('허브 세션 구독 실패: $e');
          },
        );
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
      _startedAtMs = null;
    });
  }

  String _anonKeyOf(String studentId) {
    final salt = (_startedAtMs?.toString() ?? _voteId ?? 'no-vote');
    final raw = '$salt|$studentId';
    return sha1.convert(utf8.encode(raw)).toString();
  }

  Future<void> _rebindSession(String? sid) async {
    _voteDocSub?.cancel();
    _votesColSub?.cancel();
    _evSub?.cancel();

    _sid = sid;
    _resetState();

    if (sid == null) return;

    // 명시적인 voteId가 있으면 그걸로 붙고, 없으면 허브 currentVoteId/active fallback에 의존
    if (widget.voteId != null) {
      final hubId = _hubId;
      if (hubId != null) {
        _attachVoteDoc(sid, widget.voteId!);
      }
    }
  }

  // 🔁 허브 스코프에서 active 투표를 감시 (sessions → hubs 로 변경)
  void _attachActiveWatcher(String hubId) {
    _votesColSub?.cancel();
    _votesColSub = FirebaseFirestore.instance
        .collection('hubs/$hubId/votes')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(
          (qs) {
            if (qs.docs.isEmpty) {
              _evSub?.cancel();
              _resetState();   // ★ 바로 StandBy로
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
              // 세션은 허브 문서의 currentSessionId 기준으로 이미 바인딩되어 있다고 가정
              final sid = _sid;
              if (sid != null) {
                _attachVoteDoc(sid, latest.id);
              }
            }
          },
          onError: (e) {
            dlog('[DisplayVote] votes watcher error: $e');
            _showSnack('투표 목록 구독 실패: $e');
          },
        );
  }

  int _tsScore(Map<String, dynamic> d) {
    final updated = d['updatedAt'] as Timestamp?;
    final started = d['startedAt'] as Timestamp?;
    return (updated ?? started ?? Timestamp(0, 0)).millisecondsSinceEpoch;
  }

  // 🔗 투표 문서도 허브 스코프에서 읽음 (sessions → hubs 로 변경)
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
        .listen(
          (doc) {
            final d = doc.data();
            if (d == null) {
              if (!mounted) return;
              _resetState();
              return;
            }

            dlog('[Display] vote doc ${doc.id} -> $d');

            final title = (d['title'] ?? '').toString();

            Timestamp? startedAt;
            final sa = d['startedAt'];
            if (sa is Timestamp) {
              startedAt = sa;
            } else {
              final ua = d['updatedAt'];
              if (ua is Timestamp) startedAt = ua;
            }

            final startedAtMs =
                (d['startedAtMs'] is num) ? (d['startedAtMs'] as num).toInt() : null;

            final raw = (d['options'] as List?) ?? const [];
            final opts = <_Opt>[];
            for (final it in raw) {
              if (it is Map) {
                final label = (it['title'] ?? '').toString();
                final b = (it['binding'] as Map?) ?? const {};
                final btn = (b['button'] is num) ? (b['button'] as num).toInt() : 1;
                final ges = (b['gesture'] ?? 'single').toString();
                opts.add(_Opt(label: label, button: btn, gesture: ges));
              } else if (it is String) {
                opts.add(_Opt(label: it, button: 1, gesture: 'single'));
              }
            }

            final settings = (d['settings'] as Map?) ?? const {};
            final showMode = (settings['show'] ?? 'realtime').toString();
            final status = (d['status'] ?? 'draft').toString();
            final anonymous = (settings['anonymous'] == true);
            final multi = (settings['multi'] == true);

            if (!mounted) return;
            setState(() {
              _voteId = doc.id;
              _title = title;
              _opts = opts;
              _startedAt = startedAt;
              _startedAtMs = startedAtMs;

              _showMode = showMode;
              _status = status;
              _anonymous = anonymous;

              _multi = multi;
              _revealNow = false;
            });

            // 다음 microtask에서 이벤트(허브의 liveByDevice)를 구독
            Future.microtask(_attachEvents);
          },
          onError: (e, st) {
            dlog('[Display] vote doc error: $e\n$st');
            _showSnack('투표 문서 구독 실패: $e');
          },
        );
  }

  void _attachEvents() {
    if (!mounted) return;

    final sid = _sid;
    final hubId = _hubId;
    final ts = _startedAt;
    final startedMs = _startedAtMs ?? ts?.millisecondsSinceEpoch;

    _evSub?.cancel();
    _evSub = null;

    try {
      if (sid == null || hubId == null) {
        dlog('[Display] attachEvents skipped: sid or hubId is null');
        return;
      }
      if (startedMs == null) {
        dlog('[Display] attachEvents skipped: no startedAtMs');
        if (mounted) {
          setState(() {
            _total = 0;
            _opts = _opts.map((o) => o.copyWith(votes: 0)).toList();
          });
        }
        return;
      }

      // ✅ 허브 스코프 실시간 상태 구독: hubs/$hubId/liveByDevice
      // 조건: lastHubTs >= startedMs && sessionId == sid
      final q = FirebaseFirestore.instance
          .collection('hubs/$hubId/liveByDevice')
          .where('lastHubTs', isGreaterThanOrEqualTo: startedMs)
          .where('sessionId', isEqualTo: sid);

      dlog('[Display] liveByDevice query: lastHubTs >= $startedMs, sessionId=$sid');

      _evSub = q.snapshots().listen(
        (snap) {
          dlog('[Display] liveByDevice snap: ${snap.docs.length} docs');

          if (_multi) {
            // ============ 다중 선택 모드 ============
            final Map<String, Map<String, _Ev>> byUser = {};

            for (final d in snap.docs) {
              final x = d.data();
              final rawStudentId = (x['studentId'] ?? '').toString();
              if (rawStudentId.isEmpty) continue;

              final userKey = _anonymous ? _anonKeyOf(rawStudentId) : rawStudentId;

              final slot = x['slotIndex']?.toString();
              if (slot != '1' && slot != '2') continue;

              final clickType = (x['clickType'] ?? 'click').toString();

              // 최신 판정 점수: lastHubTs 사용
              final score = (x['lastHubTs'] is num) ? (x['lastHubTs'] as num).toInt() : 0;

              final button = (slot == '1') ? 1 : 2;
              final gesture = (clickType == 'hold') ? 'hold' : 'single';
              final bindKey = '$button-$gesture';

              final map = byUser[userKey] ?? <String, _Ev>{};
              final cur = map[bindKey];
              if (cur == null || score >= cur.score) {
                map[bindKey] = _Ev(score: score, button: button, gesture: gesture);
                byUser[userKey] = map;
              }
            }

            final counts = List<int>.filled(_opts.length, 0);

            for (final selMap in byUser.values) {
              for (final ev in selMap.values) {
                final idx = _opts.indexWhere(
                  (o) => o.button == ev.button && o.gesture == ev.gesture,
                );
                if (idx >= 0) counts[idx] += 1;
              }
            }

            final totalVoters = byUser.length;

            if (!mounted) return;
            setState(() {
              for (int i = 0; i < _opts.length; i++) {
                _opts[i] = _opts[i].copyWith(votes: counts[i]);
              }
              _total = totalVoters; // 고유 학생 수
            });
          } else {
            // ============ 단일 선택 모드 ============
            final Map<String, _Ev> last = {};
            for (final d in snap.docs) {
              final x = d.data();

              final rawStudentId = (x['studentId'] ?? '').toString();
              if (rawStudentId.isEmpty) continue;

              final userKey = _anonymous ? _anonKeyOf(rawStudentId) : rawStudentId;

              final slot = x['slotIndex']?.toString();
              if (slot != '1' && slot != '2') continue;

              final clickType = (x['clickType'] ?? 'click').toString();

              final score = (x['lastHubTs'] is num) ? (x['lastHubTs'] as num).toInt() : 0;

              final cur = last[userKey];
              if (cur == null || score >= cur.score) {
                last[userKey] = _Ev(
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

            final total = last.length; // 학생 수
            if (!mounted) return;
            setState(() {
              for (int i = 0; i < _opts.length; i++) {
                _opts[i] = _opts[i].copyWith(votes: counts[i]);
              }
              _total = total;
            });
          }
        },
        onError: (e, st) {
          dlog('[Display] liveByDevice error: $e\n$st');
          _showSnack('이벤트 구독 실패: $e');
        },
      );
    } catch (e, st) {
      dlog('[Display] attachEvents exception: $e\n$st');
      _showSnack('이벤트 구독 준비 중 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // hubId가 아직 없으면 대기 화면
    final hubId = context.watch<HubProvider>().hubId;
    if (hubId == null) {
      return const Scaffold(body: Center(child: DisplayStandByPage()));
    }

    if (_voteId == null || _status == 'closed') {
    return const Scaffold(body: Center(child: DisplayStandByPage()));
    }

    final sid = context.watch<SessionProvider>().sessionId;
    final bool hide = (_showMode == 'after' && !_revealNow);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      body: Stack(
        children: [
          Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: (_voteId == null)
                  ? const DisplayStandByPage()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _title.isEmpty ? 'Untitled question' : _title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 41,
                            fontWeight: FontWeight.w500,
                            color: Colors.black, 
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${_total} VOTERS',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w500,
                              color:Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black12.withOpacity(0.08),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Column(
                            children: [
                              if (hide)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 6),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Results will be shown after voting ends',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          ),
        if (_voteId != null && _showMode == 'after' && _status == 'active' && !_revealNow)
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: 160,
              height: 160,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _revealNow = true),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Image.asset(
                      'assets/logo_bird_start.png', // 없으면 아이콘으로 폴백
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.bar_chart,
                        size: 72,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
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

    final double ratio = (!hideResults && total > 0) ? (votes / total) : 0.0;
    final String percentText =
        hideResults ? '—' : (total == 0 ? '0%' : '${(ratio * 100).round()}%');

    return InkWell(
      onTap: widget.enableTapVote ? onTap : null,
      borderRadius: BorderRadius.circular(28),
      child: Row(
        children: [
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
                  final maxW = c.maxWidth;
                  final fillW = (maxW * ratio).clamp(0.0, maxW);

                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: fillW,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: yellow,
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      const Positioned(left: 12, child: _YellowBubble()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          children: [
                            const SizedBox(width: 34),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.1,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (alwaysShowMapping || !hideResults)
                              Builder(builder: (context) {
                                final mapColor = _colorForBinding(button, gesture); // ← 버튼+제스처 조합 색상
                                final label = _labelForBinding(button, gesture);    // ← red-click 등 라벨
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: mapColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: mapColor.withOpacity(0.7)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _iconForGesture(gesture), // click/hold 모양
                                        size: 20,
                                        color: mapColor,          // ← 색 입힘
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        label,                    // ← red-click / blue-hold ...
                                        style: TextStyle(
                                          color: mapColor,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                            else
                              const Text(
                                'Hidden',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),

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
          SizedBox(
            width: 48,
            child: Text(
              percentText,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Opt {
  final String label;
  final int button; // 1 | 2
  final String gesture; // 'single' | 'hold'
  final int votes;
  _Opt({
    required this.label,
    required this.button,
    required this.gesture,
    this.votes = 0,
  });
  _Opt copyWith({int? votes}) => _Opt(
        label: label,
        button: button,
        gesture: gesture,
        votes: votes ?? this.votes,
      );
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
