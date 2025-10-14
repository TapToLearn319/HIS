// lib/pages/tools/vote/presenter_vote.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:project/widgets/help_badge.dart';
import 'package:provider/provider.dart';
import '../../../provider/session_provider.dart';
import '../../../main.dart';
import '../../../sidebar_menu.dart';
// ★ 추가
import '../../../provider/hub_provider.dart';

class PresenterVotePage extends StatefulWidget {
  const PresenterVotePage({super.key, this.voteId});
  final String? voteId;

  @override
  State<PresenterVotePage> createState() => _PresenterVotePageState();
}

class _PresenterVotePageState extends State<PresenterVotePage>
    with WidgetsBindingObserver {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activeSub;
  String? _activeVoteId;
  bool _isRunning = false;
  bool _busy = false;

  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();

  final List<TextEditingController> _optionCtrls = [];
  final List<_Binding> _bindings = [];

  final _newOptionCtrl = TextEditingController();

  static const int _maxOptions = 4;

  // Poll Settings
  String _show = 'realtime'; // 'realtime' | 'after'
  bool _anonymous = true;
  bool _multi = true;

  bool _loading = false;

  void plog(Object? msg) {
    // ignore: avoid_print
    print('[Presenter] $msg');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _autoCloseIfRunning();
    }
  }

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);

  // ✨ 텍스트를 채우지 않는다(placeholder만 보이게)
  _optionCtrls.add(TextEditingController());
  _bindings.add(const _Binding(button: 1, gesture: 'single')); // 1 - click

  _optionCtrls.add(TextEditingController());
  _bindings.add(const _Binding(button: 2, gesture: 'single')); // 2 - click

  _ensureUniqueAll();
  setState(() => _loading = false);

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;

    // ✅ 1) 입장하자마자 강제 리셋
    await _forceResetOnEnter(hubId);

    // 2) 특정 voteId로 열어야 하면 로드
    if (widget.voteId != null) {
      await _load(hubId, widget.voteId!);
    }

    // 3) (선택) 이후부터는 active 감시(다른 기기에서 시작하면 따라가게)
    _watchActive(hubId);
  });
}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeSub?.cancel();
    _titleCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }

    _autoCloseIfRunning();
    _newOptionCtrl.dispose();

    super.dispose();
  }

  Future<void> _autoCloseIfRunning() async {
    if (!_isRunning) return;
    _isRunning = false;

    final id = _activeVoteId ?? widget.voteId;
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null || id == null) return;

    try {
      final doc = FirebaseFirestore.instance.doc('hubs/$hubId/votes/$id');
      await doc.set({
        'status': 'closed',
        'endedAt': FieldValue.serverTimestamp(),
        'endedAtMs': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _updateHub(sid: null, voteId: null); // sid는 안씀

      if (mounted) setState(() => _isRunning = false);
    } catch (e) {
      debugPrint('[PresenterVote] autoCloseIfRunning error: $e');
    }
  }

  // 시그니처는 유지, 내부에서 HubProvider로 hubId 사용
  Future<void> _updateHub({required String? sid, String? voteId}) async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null) return;
    final ref = FirebaseFirestore.instance.doc('hubs/$hubId');
    await ref.set({
      'currentSessionId': sid, // 그대로 유지 (표시용이면 사용)
      'currentVoteId': voteId, // 시작 시 voteId, 종료 시 null
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _load(String sid /* hubId */, String id) async {
    setState(() => _loading = true);
    final doc =
        await FirebaseFirestore.instance.doc('hubs/$sid/votes/$id').get();
    final d = doc.data();
    if (d != null) {
      _titleCtrl.text = (d['title'] ?? '').toString();

      final raw = (d['options'] as List?) ?? const [];
      _optionCtrls.clear();
      _bindings.clear();
      for (var i = 0; i < raw.length && i < _maxOptions; i++) {
        final it = raw[i];
        String title = 'Option ${i + 1}';
        int btn = 1;
        String ges = 'hold';
        if (it is Map) {
          title = (it['title'] ?? title).toString();
          final b = (it['binding'] as Map?) ?? {};
          btn = (b['button'] is num) ? (b['button'] as num).toInt() : 1;
          ges = (b['gesture'] ?? 'hold').toString();
        } else if (it is String) {
          title = it;
        }
        _optionCtrls.add(TextEditingController(text: title));
        _bindings.add(_Binding(button: btn, gesture: ges));
      }
      while (_optionCtrls.length < 2) {
        _optionCtrls.add(TextEditingController());
        _bindings.add(const _Binding(button: 1, gesture: 'hold'));
      }

      // 설정
      final s = (d['settings'] as Map?) ?? {};
      _show = (s['show'] ?? _show).toString();
      _anonymous = (s['anonymous'] == true);
      _multi = (s['multi'] == true);

      final status = (d['status'] ?? '').toString();
      _activeVoteId = doc.id;
      _isRunning = status == 'active';
    }
    if (mounted) setState(() => _loading = false);
  }

  // 가능한 모든 매핑 (총 4개)
  static const List<_Binding> _allBindings = [
    _Binding(button: 1, gesture: 'single'),
    _Binding(button: 1, gesture: 'hold'),
    _Binding(button: 2, gesture: 'single'),
    _Binding(button: 2, gesture: 'hold'),
  ];

  // i번 문항을 next로 설정하고, 나머지에서 중복을 해소한다.
  void _setUniqueBinding(int i, _Binding next) {
    setState(() {
      // 1) 우선 적용
      _bindings[i] = next;

      // 2) 중복 정리
      final used = <String>{};
      for (int k = 0; k < _bindings.length; k++) {
        if (k == i) continue;
        used.add('${_bindings[k].button}-${_bindings[k].gesture}');
      }
      used.add('${next.button}-${next.gesture}');

      final free =
          _allBindings
              .where((b) => !used.contains('${b.button}-${b.gesture}'))
              .toList();

      for (int k = 0; k < _bindings.length; k++) {
        if (k == i) continue;
        final key = '${_bindings[k].button}-${_bindings[k].gesture}';
        if (key == '${next.button}-${next.gesture}') {
          if (free.isNotEmpty) {
            _bindings[k] = free.removeAt(0);
          }
        }
      }
    });
  }

  _Binding _firstUnusedBinding({
    _Binding fallback = const _Binding(button: 1, gesture: 'hold'),
  }) {
    final used = _bindings.map((b) => '${b.button}-${b.gesture}').toSet();
    for (final b in _allBindings) {
      if (!used.contains('${b.button}-${b.gesture}')) return b;
    }
    return fallback;
  }

  void _ensureUniqueAll() {
    final seen = <String>{};
    for (int i = 0; i < _bindings.length; i++) {
      final key = '${_bindings[i].button}-${_bindings[i].gesture}';
      if (seen.contains(key)) {
        _bindings[i] = _firstUnusedBinding(fallback: _bindings[i]);
      }
      seen.add('${_bindings[i].button}-${_bindings[i].gesture}');
    }
  }

  void _watchActive(String sid /* hubId */) {
    _activeSub?.cancel();
    _activeSub = FirebaseFirestore.instance
        .collection('hubs/$sid/votes')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(
          (qs) {
            if (qs.docs.isEmpty) {
              if (mounted) {
                setState(() {
                  _isRunning = false;
                  _activeVoteId = null;
                });
              }
              return;
            }

            int _scoreOf(Map<String, dynamic> d) {
              final updated = d['updatedAt'];
              final started = d['startedAt'];
              if (updated is Timestamp) return updated.millisecondsSinceEpoch;
              if (started is Timestamp) return started.millisecondsSinceEpoch;
              return 0;
            }

            final docs = qs.docs.toList();
            docs.sort((a, b) {
              final ta = _scoreOf(a.data());
              final tb = _scoreOf(b.data());
              return tb.compareTo(ta); // 최신이 앞
            });
            final latest = docs.first;

            if (mounted) {
              setState(() {
                _isRunning = true;
                _activeVoteId = latest.id;
              });
            }
          },
          onError: (e) {
            debugPrint('[PresenterVote] active watcher error: $e');
          },
        );
  }

  void _addFromScratch() {
  if (_optionCtrls.length >= _maxOptions) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('문항은 최대 4개까지 추가할 수 있습니다.'), duration: Duration(seconds: 2)),
    );
    return;
  }

  // 입력이 비어 있어도 생성 (원하면 기본 라벨로 대체 가능)
  final raw = _newOptionCtrl.text.trim();
  // final t = _newOptionCtrl.text.trim().isEmpty
  //     ? 'Option ${_optionCtrls.length + 1}'
  //     : _newOptionCtrl.text.trim();

  setState(() {
    _optionCtrls.add(TextEditingController(text: raw.isEmpty ? '' : raw)); // 빈 문자열 OK
    _bindings.add(_firstUnusedBinding());
    _newOptionCtrl.clear();
  });
}

Future<void> _forceResetOnEnter(String hubId) async {
  try {
    // 1) 이 허브에서 active인 투표 모두 종료
    await _stopAllActive(hubId);

    // 2) 허브 currentVoteId 정리 (표시용 sid도 같이 넣어둠)
    final sid = context.read<SessionProvider>().sessionId;
    await _updateHub(sid: sid, voteId: null);

    // 3) 로컬 상태도 확실히 Stop으로
    if (mounted) {
      setState(() {
        _isRunning = false;
        _activeVoteId = null;
      });
    }
  } catch (e) {
    debugPrint('[PresenterVote] forceResetOnEnter error: $e');
  }
}


  Future<void> _handleStartStop() async {
    if (_busy) return;
    _busy = true;
    try {
      print('[VOTE] handleStartStop 실행됨. 현재 상태: _isRunning=$_isRunning');

      final hubId = context.read<HubProvider>().hubId;
      final sid = context.read<SessionProvider>().sessionId; // 필요시 허브 문서에 표시용
      print('[VOTE] hubId=$hubId, 세션ID=$sid');

      if (hubId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('허브가 설정되지 않았습니다.')));
        }
        return;
      }

      if (!_isRunning) {
        // ▶ START
        print('[VOTE] START 시도');
        final voteId = await _persistVote(hubId);
        print('[VOTE] persistVote 결과 voteId=$voteId');

        if (voteId == null) return;

        await _stopAllActive(hubId); // 다른 active 모두 종료
        print('[VOTE] 기존 active 투표 모두 종료 완료');

        final doc = FirebaseFirestore.instance.doc(
          'hubs/$hubId/votes/$voteId',
        );
        print('[VOTE] Firestore doc path = hubs/$hubId/votes/$voteId');

        // ▶ START 직후
        await doc.set({
          'status': 'active',
          'startedAt': FieldValue.serverTimestamp(),
          'startedAtMs': DateTime.now().millisecondsSinceEpoch,
          'endedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // ★ 허브에 현재 투표 반영 (sid는 표시용으로 넣어둠)
        await _updateHub(sid: sid, voteId: voteId);

        if (!mounted) return;
        setState(() {
          _isRunning = true;
          _activeVoteId = voteId;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Vote started!')));
      } else {
        // ▶ STOP
        print('[VOTE] STOP 시도');
        final id = widget.voteId ?? _activeVoteId;
        print('[VOTE] 중지할 투표ID=$id');

        if (id == null) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('중지할 투표를 찾지 못했습니다.')));
          }
          return;
        }

        final doc = FirebaseFirestore.instance.doc('hubs/$hubId/votes/$id');
        print('[VOTE] Firestore doc path = hubs/$hubId/votes/$id');

        // ▶ STOP 직후
        await doc.set({
          'status': 'closed',
          'endedAt': FieldValue.serverTimestamp(),
          'endedAtMs': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // ★ 허브에서 현재 투표 해제
        await _updateHub(sid: sid, voteId: null);

        if (!mounted) return;
        setState(() => _isRunning = false);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Vote stopped.')));
      }
    } catch (e, st) {
      print('[VOTE][toggle] 에러 발생: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('처리 실패: $e')));
      }
    } finally {
      if (mounted) setState(() {}); // UI 갱신
      _busy = false;
      print('[VOTE] handleStartStop 종료됨. 최종 상태: _isRunning=$_isRunning');
    }
  }

  int _tsFrom(dynamic v) {
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    return 0;
  }

  int _rowScore(Map<String, dynamic> d) {
    final ua = _tsFrom(d['updatedAt']);
    if (ua > 0) return ua;
    return _tsFrom(d['startedAt']);
  }

  @override
  Widget build(BuildContext context) {
    final sid = context.watch<SessionProvider>().sessionId;

    return AppScaffold(
      selectedIndex: 0,
      body: WillPopScope(
        onWillPop: () async {
          await _autoCloseIfRunning();
          return true;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF6FAFF),
          appBar: AppBar(
                  elevation: 0,
                  backgroundColor: const Color(0xFFF6FAFF),
                  leading: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
          body: Stack(
            children: [
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
                    children: [
                      _sectionTitle('Poll Question'),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(
                            width: 948,
                            height: 65,
                          ),
                          child: TextFormField(
                            controller: _titleCtrl,
                            decoration: InputDecoration(
                              hintText: 'Did you understand today’s lesson?',
                              hintStyle: const TextStyle(
                                color: Color(0xFF001A36),
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 0,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD2D2D2),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD2D2D2),
                                  width: 1,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF001A36),
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            ),
                            validator:
                                (v) =>
                                    (v ?? '').trim().isEmpty
                                        ? 'Enter the Question.'
                                        : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Center(
                        child: Container(
                          width: 948,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              Text(
                                'Poll Options',
                                style: TextStyle(
                                  color: Color(0xFF001A36),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '*Up to 4',
                                style: TextStyle(
                                  color: Color(0xFF001A36),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                ),
                                
                              ),
                              const HelpBadge(
                                tooltip: 'Set up the items for voting.',
                                placement: HelpPlacement.right, // 말풍선이 왼쪽으로 펼쳐지게
                                // gap: 2, // 네가 쓰는 HelpBadge가 gap 지원하면 켜줘서 더 가깝게
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _optionsCard(),

                      const SizedBox(height: 18),
                      _sectionTitle('Poll Settings'),
                      const SizedBox(height: 8),
                      _settingsCard(),
                    ],
                  ),
                ),

              Positioned(
                right: 16,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: _MakeButton(
                    scale: 0.8, // 🔹 버튼 크기 비율 (1.0이면 원본)
                    imageAsset: _isRunning
                        ? 'assets/logo_bird_stop.png'
                        : 'assets/logo_bird_start.png',
                    onTap: _handleStartStop,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionsCard() {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 948),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFD2D2D2)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              for (var i = 0; i < _optionCtrls.length; i++) ...[
                _optionRow(i),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints.tightFor(height: 60),
                      child: TextField(
                        controller: _newOptionCtrl,
                        onSubmitted: (_) => _addFromScratch(),
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Enter...',
                          
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32.5),
                            borderSide: const BorderSide(
                              color: Color(0xFFD2D2D2),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32.5),
                            borderSide: const BorderSide(
                              color: Color(0xFFD2D2D2),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  GestureDetector(
                    onTap:
                        (_optionCtrls.length >= _maxOptions)
                            ? null
                            : _addFromScratch,
                    child: Opacity(
                      opacity: (_optionCtrls.length >= _maxOptions) ? 0.4 : 1.0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFD2D2D2),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add,
                            size: 20,
                            color: Color(0xFFBDBDBD),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionRow(int i) {
    final ctrl = _optionCtrls[i];
    final bind = _bindings[i];

    List<PopupMenuEntry<int>> _menuItems() => const [
      PopupMenuItem(
        enabled: false,
        child: Text(
          '— Button mapping —',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      PopupMenuDivider(),
      PopupMenuItem(value: 1, child: Text('1 - single')),
      PopupMenuItem(value: 2, child: Text('1 - hold')),
      PopupMenuItem(value: 3, child: Text('2 - single')),
      PopupMenuItem(value: 4, child: Text('2 - hold')),
      PopupMenuDivider(),
      PopupMenuItem(value: 9, child: Text('문항 삭제')),
    ];

    void _onMenuSelected(int v) {
      if (i < 0 || i >= _optionCtrls.length || i >= _bindings.length) return;

      if (v == 9) {
        if (_optionCtrls.length <= 2) return;
        setState(() {
          _bindings.removeAt(i);
          _optionCtrls.removeAt(i).dispose();
        });
        return;
      }

      _Binding next;
      switch (v) {
        case 1:
          next = const _Binding(button: 1, gesture: 'single');
          break;
        case 2:
          next = const _Binding(button: 1, gesture: 'hold');
          break;
        case 3:
          next = const _Binding(button: 2, gesture: 'single');
          break;
        case 4:
          next = const _Binding(button: 2, gesture: 'hold');
          break;
        default:
          return;
      }
      _setUniqueBinding(i, next);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints.tightFor(height: 60),
            child: TextFormField(
              controller: ctrl,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Enter a poll option',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 0,
                ),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32.5),
                  borderSide: const BorderSide(
                    color: Color(0xFFD2D2D2),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32.5),
                  borderSide: const BorderSide(
                    color: Color(0xFFD2D2D2),
                    width: 1,
                  ),
                ),
                suffixIcon: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 150,
                    maxWidth: 200, // ✅ suffixIcon 전체 폭 제한
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // ✅ 내부 요소 크기에만 맞춤
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (i == 0) ...[
                        const HelpBadge(
                          tooltip: 'You can customize how students select the correct answer.',
                          placement: HelpPlacement.left,
                          size: 26,
                        ),
                        const SizedBox(width: 6),
                      ],

                      // ✅ 텍스트 영역 유연하게 줄임
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${bind.button} - ${bind.gesture}',
                            textAlign: TextAlign.left,
                            overflow: TextOverflow.ellipsis, // ✅ 넘치면 자동 줄임
                            style: const TextStyle(
                              color: Color(0xFF8D8D8D),
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 4),

                      // ✅ 메뉴 버튼
                      Theme(
                        data: Theme.of(context).copyWith(
                          popupMenuTheme: PopupMenuThemeData(
                            color: const Color(0xFFF6F6F6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              color: Color(0xFF8D8D8D),
                              fontSize: 21,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        child: PopupMenuButton<int>(
                          tooltip: 'More',
                          icon: const Icon(
                            Icons.more_vert,
                            color: Color(0xFF8D8D8D),
                          ),
                          elevation: 0,
                          itemBuilder: (_) {
                            final usedExceptMe = _bindings
                                .asMap()
                                .entries
                                .where((e) => e.key != i)
                                .map((e) => '${e.value.button}-${e.value.gesture}')
                                .toSet();

                            final currentKey = '${bind.button}-${bind.gesture}';

                            const opts = [
                              _MenuOpt(1, '1 - single', '1-single'),
                              _MenuOpt(2, '1 - hold', '1-hold'),
                              _MenuOpt(3, '2 - single', '2-single'),
                              _MenuOpt(4, '2 - hold', '2-hold'),
                            ];

                            return opts.map((o) {
                              final disabled = usedExceptMe.contains(o.key);
                              final selected = (o.key == currentKey);

                              return PopupMenuItem<int>(
                                value: o.value,
                                enabled: !disabled,
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      child: selected
                                          ? const Icon(
                                              Icons.check,
                                              size: 18,
                                              color: Colors.black87,
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        o.label,
                                        style: TextStyle(
                                          decoration: disabled
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList();
                          },
                          onSelected: _onMenuSelected,
                        ),
                      ),
                    ],
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 170,
                  maxWidth: 170,
                ),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '문항을 입력하세요.' : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Center(
      child: Container(
        width: 948,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF001A36),
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _settingsCard() {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 948, height: 123),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFD2D2D2), width: 1),
          ),
          padding: const EdgeInsets.all(13),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _settingRow(
                title: 'Show results',
                left: _choice<bool>('in real time', _show == 'realtime', () {
                  setState(() => _show = 'realtime');
                }),
                right: _choice<bool>('After voting ends', _show == 'after', () {
                  setState(() => _show = 'after');
                }),
              ),
              // _settingRow(
              //   title: 'Anonymous',
              //   left: _choice<bool>('yes', _anonymous, () {
              //     setState(() => _anonymous = true);
              //   }),
              //   right: _choice<bool>('no', !_anonymous, () {
              //     setState(() => _anonymous = false);
              //   }),
              // ),
              _settingRow(
                title: 'Multiple selections',
                left: _choice<bool>('yes', _multi, () {
                  setState(() => _multi = true);
                }),
                right: _choice<bool>('no', !_multi, () {
                  setState(() => _multi = false);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _persistVote(String sid /* hubId */) async {
    if (_titleCtrl.text.trim().isEmpty) {
      _titleCtrl.text = 'Untitled question';
    }
    if (!_formKey.currentState!.validate()) return null;

    final titles =
        _optionCtrls
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .take(_maxOptions)
            .toList();

    if (titles.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('문항은 2개 이상이어야 합니다.')));
      return null;
    }

    final options = <Map<String, dynamic>>[];
    for (var i = 0; i < titles.length; i++) {
      final b = _bindings[i];
      options.add({
        'id': 'opt_$i',
        'title': titles[i],
        'votes': 0,
        'binding': {'button': b.button, 'gesture': b.gesture},
      });
    }

    final ref =
        (widget.voteId == null)
            ? FirebaseFirestore.instance.collection('hubs/$sid/votes').doc()
            : FirebaseFirestore.instance.doc('hubs/$sid/votes/${widget.voteId}');

    await ref.set({
      'title': _titleCtrl.text.trim(),
      'type': 'multiple',
      if (widget.voteId == null) 'status': 'draft',
      'options': options,
      'settings': {'show': _show, 'anonymous': _anonymous, 'multi': _multi},
      if (widget.voteId == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return ref.id;
  }

  Future<void> _stopAllActive(String sid /* hubId */) async {
    final fs = FirebaseFirestore.instance;
    final running =
        await fs
            .collection('hubs/$sid/votes')
            .where('status', isEqualTo: 'active')
            .get();
    if (running.docs.isEmpty) return;

    final now = FieldValue.serverTimestamp();
    final batch = fs.batch();
    for (final d in running.docs) {
      batch.set(d.reference, {
        'status': 'closed',
        'endedAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Widget _radioPill<T>(
    String label,
    T value,
    T group,
    ValueChanged<T?> onChanged,
  ) {
    final selected = value == group;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<T>(value: value, groupValue: group, onChanged: onChanged),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color:
                  selected ? const Color(0xFFFFE483) : const Color(0xFFFFF3B8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

Widget _settingRow({
  required String title,
  required Widget left,
  required Widget right,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      // 왼쪽 제목 + 배지
      ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 404),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF001A36),
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            if (title == 'Show results') ...[
              const HelpBadge(
                tooltip:
                    '결과를 실시간으로 보여줄지, 투표 종료 후 공개할지를 설정합니다.',
                placement: HelpPlacement.right,
                size: 24,
              ),
            ] else if (title == 'Multiple selections') ...[
              const HelpBadge(
                tooltip:
                    '참가자가 여러 항목을 동시에 선택할 수 있게 할지 여부를 설정합니다.',
                placement: HelpPlacement.right,
                size: 24,
              ),
            ],
          ],
        ),
      ),

      // 오른쪽 yes/no 선택부
      SizedBox(
        width: 420,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ✅ 왼쪽 선택지: 폭 고정, 중앙 정렬
            SizedBox(
              width: 200, // 두 줄 모두 동일한 폭 확보
              child: Align(
                alignment: Alignment.centerLeft,
                child: left,
              ),
            ),
            // ✅ 오른쪽 선택지: 폭 고정, 중앙 정렬
            SizedBox(
              width: 200,
              child: Align(
                alignment: Alignment.centerLeft,
                child: right,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}


  Widget _dot(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFFFFE483) : Colors.transparent,
        border: Border.all(
          color: selected ? const Color(0xFFFFE483) : const Color(0xFFCCCCCC),
          width: 2,
        ),
      ),
    );
  }

  Widget _choice<T>(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(selected),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF001A36),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rounded({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    );
  }
}

class _Binding {
  final int button; // 1 | 2
  final String gesture; // 'single' | 'hold'
  const _Binding({required this.button, required this.gesture});
  @override
  bool operator ==(Object other) =>
      other is _Binding && other.button == button && other.gesture == gesture;
  @override
  int get hashCode => Object.hash(button, gesture);
}

class _MenuOpt {
  final int value;
  final String label;
  final String key;
  const _MenuOpt(this.value, this.label, this.key);
}
class _MakeButton extends StatefulWidget {
  const _MakeButton({
    required this.scale,
    required this.onTap,
    required this.imageAsset,
  });

  final double scale;
  final VoidCallback onTap;
  final String imageAsset;

  @override
  State<_MakeButton> createState() => _MakeButtonState();
}

class _MakeButtonState extends State<_MakeButton> {
  bool _hover = false;
  bool _down = false;

  static const _baseW = 195.0;
  static const _baseH = 172.0;

  @override
  Widget build(BuildContext context) {
    final w = _baseW * widget.scale;
    final h = _baseH * widget.scale;
    final scaleAnim = _down ? 0.96 : (_hover ? 1.04 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: scaleAnim,
          child: SizedBox(
            width: w,
            height: h,
            child: Image.asset(
              widget.imageAsset,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
