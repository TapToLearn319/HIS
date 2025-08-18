import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import '../../../provider/session_provider.dart';
import '../../display_standby.dart';

const String kHubId = 'hub-001'; // 허브 지정해둠

class DisplayVotePage extends StatefulWidget {
  const DisplayVotePage({super.key, this.enableTapVote = false, this.voteId});

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

  int? _startedAtMs;

  String _showMode = 'realtime';
  String _status = 'draft';

  bool _anonymous = true;

  bool _multi = false;

  void dlog(Object? msg) {
    // 웹/릴리즈에서도 보이도록 print로 직접 출력
    // 긴 메시지도 잘 보이게 prefix 추가
    // ignore: avoid_print
    print('[Display] $msg');
  }

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
    _hubSub = FirebaseFirestore.instance
        .doc('hubs/$kHubId')
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

            // ▼ 추가: 허브가 현재 투표를 직접 알려주면 곧장 그걸로 붙는다
            if (hubSid.isNotEmpty && hubVoteId.isNotEmpty) {
              if (_sid != hubSid || _voteId != hubVoteId) {
                _attachVoteDoc(hubSid, hubVoteId);
              }
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
        .listen(
          (qs) {
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
        .listen(
          (doc) {
            final d = doc.data();
            if (d == null) {
              if (!mounted) return;
              _resetState();
              return;
            }

            // ⬇︎ 로그로 현재 문서 상태 확인
            dlog('[Display] vote doc ${doc.id} -> ${d}');

            // 제목
            final title = (d['title'] ?? '').toString();

            // startedAt(Timestamp) 파싱
            Timestamp? startedAt;
            final sa = d['startedAt'];
            if (sa is Timestamp) {
              startedAt = sa;
            } else {
              final ua = d['updatedAt'];
              if (ua is Timestamp) startedAt = ua;
            }

            // startedAtMs(int) 파싱
            final startedAtMs =
                (d['startedAtMs'] is num)
                    ? (d['startedAtMs'] as num).toInt()
                    : null;

            // 옵션 파싱
            final raw = (d['options'] as List?) ?? const [];
            final opts = <_Opt>[];
            for (final it in raw) {
              if (it is Map) {
                final label = (it['title'] ?? '').toString();
                final b = (it['binding'] as Map?) ?? const {};
                final btn =
                    (b['button'] is num) ? (b['button'] as num).toInt() : 1;
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
            });

            // ⬇︎ build 중 setState 충돌 방지: 다음 microtask에서 이벤트 구독
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
    final ts = _startedAt;
    final ms = _startedAtMs;

    // 이전 구독 해제
    _evSub?.cancel();
    _evSub = null;

    try {
      if (sid == null) {
        dlog('[Display] attachEvents skipped: sid=null');
        return;
      }
      if (ms == null && ts == null) {
        dlog('[Display] attachEvents skipped: no startedAt nor startedAtMs');
        if (mounted) {
          setState(() {
            _total = 0;
            _opts = _opts.map((o) => o.copyWith(votes: 0)).toList();
          });
        }
        return;
      }

      // 🔐 쿼리 구성 (hubTs 우선, 없으면 ts로 폴백)
      Query<Map<String, dynamic>> q;
      if (ms != null) {
        q = FirebaseFirestore.instance
            .collection('sessions/$sid/events')
            .where('hubTs', isGreaterThanOrEqualTo: ms);
        dlog('[Display] events query by hubTs >= $ms');
      } else {
        q = FirebaseFirestore.instance
            .collection('sessions/$sid/events')
            .where('ts', isGreaterThanOrEqualTo: ts);
        dlog('[Display] events query by ts >= $ts');
      }

      _evSub = q.snapshots().listen(
        (snap) {
          dlog('[Display] events snap: ${snap.docs.length} docs');

          if (_multi) {
            // ============ 다중 선택 모드 ============
            // 학생별로 여러 바인딩을 동시에 가질 수 있게 Map으로 추적
            final Map<String, Map<String, _Ev>> byUser = {};

            for (final d in snap.docs) {
              final x = d.data();
              final rawStudentId = (x['studentId'] ?? '').toString();
              if (rawStudentId.isEmpty) continue;

              final userKey =
                  _anonymous ? _anonKeyOf(rawStudentId) : rawStudentId;

              final slot = x['slotIndex']?.toString();
              if (slot != '1' && slot != '2') continue;

              final clickType =
                  (x['clickType'] ?? x['lastClickType'] ?? 'click').toString();

              // 최신 판정 점수
              final score =
                  (x['hubTs'] is num)
                      ? (x['hubTs'] as num).toInt()
                      : ((x['ts'] is Timestamp)
                          ? (x['ts'] as Timestamp).millisecondsSinceEpoch
                          : 0);

              final button = (slot == '1') ? 1 : 2;
              final gesture = (clickType == 'hold') ? 'hold' : 'single';
              final bindKey = '$button-$gesture';

              final map = byUser[userKey] ?? <String, _Ev>{};
              final cur = map[bindKey];
              if (cur == null || score >= cur.score) {
                map[bindKey] = _Ev(
                  score: score,
                  button: button,
                  gesture: gesture,
                );
                byUser[userKey] = map;
              }
            }

            // 옵션 카운트
            final counts = List<int>.filled(_opts.length, 0);

            for (final selMap in byUser.values) {
              for (final ev in selMap.values) {
                final idx = _opts.indexWhere(
                  (o) => o.button == ev.button && o.gesture == ev.gesture,
                );
                if (idx >= 0) counts[idx] += 1;
              }
            }

            // 총 유권자 수 = 한 개 이상 선택한 고유 학생 수
            final totalVoters = byUser.length;

            if (!mounted) return;
            setState(() {
              for (int i = 0; i < _opts.length; i++) {
                _opts[i] = _opts[i].copyWith(votes: counts[i]);
              }
              _total = totalVoters; // ★ 여기서 _total은 "고유 학생 수"
            });
          } else {
            // ============ 단일 선택 모드(기존 로직) ============
            final Map<String, _Ev> last = {};
            for (final d in snap.docs) {
              final x = d.data();

              final rawStudentId = (x['studentId'] ?? '').toString();
              if (rawStudentId.isEmpty) continue;

              final userKey =
                  _anonymous ? _anonKeyOf(rawStudentId) : rawStudentId;

              final slot = x['slotIndex']?.toString();
              if (slot != '1' && slot != '2') continue;

              final clickType =
                  (x['clickType'] ?? x['lastClickType'] ?? 'click').toString();

              final score =
                  (x['hubTs'] is num)
                      ? (x['hubTs'] as num).toInt()
                      : ((x['ts'] is Timestamp)
                          ? (x['ts'] as Timestamp).millisecondsSinceEpoch
                          : 0);

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

            final total = last.length; // 학생 수 == 총 유권자 수
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
          dlog('[Display] events error: $e\n$st');
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
    final sid = context.watch<SessionProvider>().sessionId;
    final bool hide = (_showMode == 'after' && _status != 'closed');

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child:
                (_voteId == null)
                    ? const DisplayStandByPage()
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
                            hide ? '-' : '${_total} VOTERS',
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
                                  badge:
                                      '${_opts[i].button} ${_opts[i].gesture}',
                                  onTap: _tapVoteDebug, // ← 이걸로
                                  // 또는 onTap: () => _tapVoteDebug(),
                                  hideResults: hide,
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
    );
  }

  Widget _barRow({
    required String label,
    required int votes,
    required int total,
    required String badge,
    required VoidCallback onTap,
    bool hideResults = false, // ★ 추가
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
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _badge(hideResults ? 'Hidden' : badge), // ★ 숨김 표시
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
              percentText, // ★  퍼센트도 가림
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
