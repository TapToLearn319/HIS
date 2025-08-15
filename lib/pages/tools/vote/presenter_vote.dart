import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/session_provider.dart';
import '../../../main.dart';

class PresenterVotePage extends StatefulWidget {
  const PresenterVotePage({super.key, this.voteId});
  final String? voteId;

  @override
  State<PresenterVotePage> createState() => _PresenterVotePageState();
}

class _PresenterVotePageState extends State<PresenterVotePage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();

  final List<TextEditingController> _optionCtrls = [];
  final List<_Binding> _bindings = [];

  static const int _maxOptions = 4;

  // Poll Settings
  String _show = 'realtime'; // 'realtime' | 'after'
  bool _anonymous = true;
  bool _multi = true;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    for (final t in const ['Great', "Its too difficult"]) {
      _optionCtrls.add(TextEditingController(text: t));
      _bindings.add(const _Binding(button: 1, gesture: 'hold'));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sid = context.read<SessionProvider>().sessionId;
      if (sid != null && widget.voteId != null) {
        _load(sid, widget.voteId!);
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load(String sid, String id) async {
    setState(() => _loading = true);
    final doc =
        await FirebaseFirestore.instance.doc('sessions/$sid/votes/$id').get();
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
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final sid = context.watch<SessionProvider>().sessionId;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Vote'),
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
                            fontFamily: 'FONTSPRING DEMO - Lufga Medium',
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
                          fontFamily: 'FONTSPRING DEMO - Lufga Medium',
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Poll Options',
                            style: TextStyle(
                              color: Color(0xFF001A36),
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Lufga',
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '*Up to 4',
                            style: TextStyle(
                              color: Color(0xFF001A36),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Pretendard',
                            ),
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
              child: SizedBox(
                width: 160,
                height: 160,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _startVote,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Image.asset(
                        'assets/logo_bird_start.png',
                        fit: BoxFit.contain,
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

  // Poll Options 카드
  Widget _optionsCard() {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(
          width: 948,
        ), // Poll Settings와 맞춤
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
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed:
                      (_optionCtrls.length >= _maxOptions)
                          ? null
                          : () {
                            setState(() {
                              _optionCtrls.add(TextEditingController());
                              _bindings.add(
                                const _Binding(button: 1, gesture: 'hold'),
                              );
                            });
                          },
                  icon: const Icon(Icons.add),
                  label: const Text('문항 추가'),
                ),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 입력창: 높이 60, pill 라운드, 내부 오른쪽에 매핑 텍스트
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints.tightFor(height: 60),
            child: TextFormField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'Option',
                // 내부 여백
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 0,
                ),
                // 배경
                filled: true,
                fillColor: Colors.white,
                // 테두리
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

                // ▶ 오른쪽 안쪽 매핑 표시 (예: "1 - hold")
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${bind.button} - ${bind.gesture}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF8D8D8D),
                        fontSize: 21,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                // suffix 영역이 너무 좁아 잘리는 것 방지
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 100,
                  maxWidth: 140,
                ),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '문항을 입력하세요.' : null,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // … 메뉴 (매핑 변경/삭제)
        PopupMenuButton<int>(
          tooltip: 'More',
          itemBuilder:
              (_) => const [
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
              ],
          onSelected: (v) {
            if (i < 0 || i >= _optionCtrls.length || i >= _bindings.length)
              return;

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
            setState(() => _bindings[i] = next);
          },
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.more_horiz),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Center(
      child: Container(
        width: 948, // 블럭 너비
        alignment: Alignment.centerLeft, // 내부 텍스트는 왼쪽 정렬
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF001A36),
            fontSize: 24,
            fontWeight: FontWeight.w500,
            fontFamily: 'Lufga',
          ),
        ),
      ),
    );
  }

  // Poll Settings 카드
  Widget _settingsCard() {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 948, height: 184),
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
              _settingRow(
                title: 'Anonymous',
                left: _choice<bool>('yes', _anonymous, () {
                  setState(() => _anonymous = true);
                }),
                right: _choice<bool>('no', !_anonymous, () {
                  setState(() => _anonymous = false);
                }),
              ),
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

  Future<String?> _persistVote(String sid) async {
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
            ? FirebaseFirestore.instance.collection('sessions/$sid/votes').doc()
            : FirebaseFirestore.instance.doc(
              'sessions/$sid/votes/${widget.voteId}',
            );

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

  Future<void> _stopAllActive(String sid) async {
    final fs = FirebaseFirestore.instance;
    final running =
        await fs
            .collection('sessions/$sid/votes')
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

  Future<void> _startVote() async {
    final sid = context.read<SessionProvider>().sessionId;
    if (sid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('세션이 설정되지 않았습니다. (SessionProvider.sessionId=null)'),
        ),
      );
      return;
    }

    try {
      final voteId = await _persistVote(sid);
      if (voteId == null) return;

      await _stopAllActive(sid);

      final doc = FirebaseFirestore.instance.doc('sessions/$sid/votes/$voteId');
      await doc.set({
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vote started!')));
    } catch (e, st) {
      debugPrint('[VOTE][start] $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('시작 실패: $e')));
    }
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
        // 왼쪽 라벨 — width: 404px, 글씨 스타일 (#001A36, 24px, w500)
        ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: 404),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF001A36),
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // 선택지 2개
        Row(children: [left, const SizedBox(width: 28), right]),
      ],
    );
  }

  // 노란 원형 인디케이터
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

  // "● label" 형태 선택지
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
