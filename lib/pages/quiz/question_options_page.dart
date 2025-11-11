// lib/pages/quiz/question_options_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';

/// Answer options 편집 페이지
/// - 질문 문구 수정
/// - 보기 추가/삭제/수정 (2~4개)
/// - 각 보기별 Flic 트리거 매핑 (투표 페이지와 동일한 라벨/룰)
/// - (옵션) 정답 지정 on/off: 단일정답/복수정답 모두 지원
class QuestionOptionsPage extends StatefulWidget {
  const QuestionOptionsPage({
    super.key,
    required this.topicId,
    required this.quizId,
  });

  final String topicId;
  final String quizId;

  @override
  State<QuestionOptionsPage> createState() => _QuestionOptionsPageState();
}

class _QuestionOptionsPageState extends State<QuestionOptionsPage> {
  final _qCtrl = TextEditingController();

  final List<TextEditingController> _choiceCtrls = [];
  final List<String?> _triggers = []; // 길이 == choices
  bool _allowMultiple = false;

  // 단일정답용 / 복수정답용
  int _correctIndex = 0;
  final Set<int> _correctSet = {0};

  bool _loading = true;
  bool _saving = false;

  static const _kTriggerLabel = <String, String>{
    'S1_CLICK': 'Button 1 • Click',
    'S1_HOLD':  'Button 1 • Hold',
    'S2_CLICK': 'Button 2 • Click',
    'S2_HOLD':  'Button 2 • Hold',
  };

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    for (final c in _choiceCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitial() async {
  try {
    final hubPath = context.read<HubProvider>().hubDocPath; // hubs/{hubId}
    if (hubPath == null) throw Exception('허브를 먼저 선택하세요.');

    final fs = FirebaseFirestore.instance;
    final doc = await fs
        .doc('$hubPath/quizTopics/${widget.topicId}/quizzes/${widget.quizId}')
        .get();
    final x = doc.data() ?? {};

    _qCtrl.text = (x['question'] as String?) ?? '';

    // ✅ 새 구조(options[{title,binding}]) 우선
    final List optList = (x['options'] as List?) ?? const [];
    List<String> choices = [];
    List<String?> triggers = [];

    if (optList.isNotEmpty) {
      for (final it in optList) {
        if (it is Map) {
          final title = (it['title'] ?? '').toString();
          final b = (it['binding'] as Map?) ?? {};
          final btn = (b['button'] is num) ? (b['button'] as num).toInt() : 1;
          final ges = (b['gesture'] ?? 'single').toString();
          final trig =
              (btn == 1 ? 'S1_' : 'S2_') + (ges == 'hold' ? 'HOLD' : 'CLICK');
          choices.add(title);
          triggers.add(trig);
        }
      }
    }

    // ✅ 구 구조(choices + triggers) 호환
    if (choices.isEmpty) {
      final List rawChoices = (x['choices'] as List?) ?? const ['A', 'B'];
      final List rawTriggers =
          (x['triggers'] as List?) ?? const ['S1_CLICK', 'S2_CLICK'];
      for (int i = 0; i < rawChoices.length; i++) {
        choices.add(rawChoices[i].toString());
        triggers.add(i < rawTriggers.length ? rawTriggers[i]?.toString() : null);
      }
    }

    // ✅ 컨트롤러 초기화
    _choiceCtrls
      ..clear()
      ..addAll(choices.map((t) => TextEditingController(text: t)));
    while (_choiceCtrls.length < 2) _choiceCtrls.add(TextEditingController());
    while (_choiceCtrls.length > 4) _choiceCtrls.removeLast().dispose();

    _triggers
      ..clear()
      ..addAll(triggers.take(_choiceCtrls.length));
    while (_triggers.length < _choiceCtrls.length) _triggers.add(null);

    // ✅ 정답 복원 (단일/복수 선택)
    final List correctIndicesRaw = (x['correctIndices'] as List?) ?? const [];
    _allowMultiple = correctIndicesRaw.isNotEmpty;
    if (_allowMultiple) {
      _correctSet
        ..clear()
        ..addAll(correctIndicesRaw
            .map((e) => (e as num).toInt())
            .where((i) => i < _choiceCtrls.length));
      if (_correctSet.isEmpty) _correctSet.add(0);
    } else {
      _correctIndex = (x['correctIndex'] as num?)?.toInt() ?? 0;
      if (_correctIndex >= _choiceCtrls.length) _correctIndex = 0;
    }
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<String> _availableForIndex(int idx) {
    // 같은 페이지 내에서 트리거 중복 불가 → 다른 인덱스에 선택된 값 제외
    final used = _triggers.toList()..removeAt(idx);
    return _kTriggerLabel.keys.where((k) => !used.contains(k)).toList();
  }

  void _ensureTriggerLen() {
    while (_triggers.length < _choiceCtrls.length) _triggers.add(null);
    while (_triggers.length > _choiceCtrls.length) _triggers.removeLast();
  }

  void _addChoice() {
    if (_choiceCtrls.length >= 4) return;
    setState(() {
      _choiceCtrls.add(TextEditingController());
      _ensureTriggerLen();
      if (!_allowMultiple && _correctIndex >= _choiceCtrls.length) {
        _correctIndex = _choiceCtrls.length - 1;
      }
    });
  }

  void _removeChoice(int idx) {
    if (_choiceCtrls.length <= 2) return;
    setState(() {
      final c = _choiceCtrls.removeAt(idx);
      c.dispose();
      _ensureTriggerLen();

      if (_allowMultiple) {
        _correctSet.remove(idx);
        // reindex
        final newSet = <int>{};
        for (final v in _correctSet) {
          newSet.add(v > idx ? v - 1 : v);
        }
        _correctSet
          ..clear()
          ..addAll(newSet.isEmpty ? {0} : newSet);
      } else {
        if (_correctIndex >= _choiceCtrls.length) {
          _correctIndex = _choiceCtrls.length - 1;
        }
      }
    });
  }

  Future<void> _save() async {
  if (_saving) return;
  setState(() => _saving = true);
  try {
    final hubPath = context.read<HubProvider>().hubDocPath;
    if (hubPath == null) {
      _snack('허브를 먼저 선택하세요.');
      return;
    }
    final fs = FirebaseFirestore.instance;

    final q = _qCtrl.text.trim();

    // ✅ 텍스트와 트리거 필터링
    final pairs = <MapEntry<String, String?>>[];
    for (int i = 0; i < _choiceCtrls.length; i++) {
      final text = _choiceCtrls[i].text.trim();
      if (text.isNotEmpty) pairs.add(MapEntry(text, _triggers[i]));
    }

    if (q.isEmpty || pairs.length < 2) {
      _snack('질문과 최소 2개의 보기 내용을 입력하세요.');
      return;
    }

    if (pairs.any((e) => e.value == null)) {
      _snack('모든 보기에 버튼 매핑을 지정하세요.');
      return;
    }

    final used = <String>{};
    for (final e in pairs) {
      if (!used.add(e.value!)) {
        _snack('버튼 매핑이 중복되었습니다: ${e.value}');
        return;
      }
    }

    // ✅ vote-style options 생성
    final options = <Map<String, dynamic>>[];
    for (final e in pairs) {
      final trig = e.value!;
      final isS1 = trig.startsWith('S1');
      final isHold = trig.endsWith('HOLD');
      options.add({
        'title': e.key,
        'binding': {
          'button': isS1 ? 1 : 2,
          'gesture': isHold ? 'hold' : 'single',
        },
      });
    }

    // ✅ 정답 바인딩 계산
    Map<String, dynamic>? correctBinding;
    if (_allowMultiple) {
      final firstIdx = _correctSet.isNotEmpty ? _correctSet.first : 0;
      final b = options[firstIdx]['binding'] as Map<String, dynamic>;
      correctBinding = {'button': b['button'], 'gesture': b['gesture']};
    } else {
      final b = options[_correctIndex]['binding'] as Map<String, dynamic>;
      correctBinding = {'button': b['button'], 'gesture': b['gesture']};
    }

    // ✅ Firestore 데이터
    final data = <String, dynamic>{
      'question': q,
      'options': options, // 🔥 핵심 변경
      'allowMultiple': _allowMultiple,
      'correctBinding': correctBinding, // ✅ 새 필드
      'updatedAt': FieldValue.serverTimestamp(),
      // 구형 필드 제거
      'choices': FieldValue.delete(),
      'triggers': FieldValue.delete(),
      'correctIndex': FieldValue.delete(),
      'correctIndices': FieldValue.delete(),
    };

    await fs
        .doc('$hubPath/quizTopics/${widget.topicId}/quizzes/${widget.quizId}')
        .set(data, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.pop(context, true);
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6FAFF),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF6FAFF),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Edit question'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_alt, size: 18),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Center(
        child: FractionallySizedBox(
          widthFactor: 0.8,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionCard(
                  title: 'Question',
                  child: TextField(
                    controller: _qCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Type your question',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Answer options   ·  up to 4',
                  trailing: IconButton(
                    tooltip: 'Add option',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _choiceCtrls.length >= 4 ? null : _addChoice,
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _choiceCtrls.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == _choiceCtrls.length - 1 ? 0 : 10,
                          ),
                          child: _OptionRow(
                            index: i,
                            controller: _choiceCtrls[i],
                            triggerValue: _triggers[i],
                            triggerLabelMap: _kTriggerLabel,
                            availableValues: _availableForIndex(i),
                            allowMultiple: _allowMultiple,
                            selectedInMulti: _correctSet.contains(i),
                            singleSelectedIndex: _correctIndex,
                            onTriggerTap: () => _openTriggerPicker(i),
                            onRemove: _choiceCtrls.length <= 2 ? null : () => _removeChoice(i),
                            onMarkCorrectSingle: () => setState(() => _correctIndex = i),
                            onToggleCorrectMulti: () => setState(() {
                              if (_correctSet.contains(i)) {
                                if (_correctSet.length == 1) return;
                                _correctSet.remove(i);
                              } else {
                                _correctSet.add(i);
                              }
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Correctness & Mode',
                  child: Row(
                    children: [
                      Switch.adaptive(
                        value: _allowMultiple,
                        onChanged: (v) {
                          setState(() {
                            _allowMultiple = v;
                            if (v) {
                              _correctSet
                                ..clear()
                                ..add(_correctIndex);
                            } else {
                              _correctIndex =
                                  _correctSet.isEmpty ? 0 : _correctSet.first;
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _allowMultiple ? 'Multiple correct answers' : 'Single correct answer',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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

  Future<void> _openTriggerPicker(int idx) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final candidates = _availableForIndex(idx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Map a button', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final key in _kTriggerLabel.keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: _triggerIcon(key),
                    title: Text(_kTriggerLabel[key] ?? key),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: candidates.contains(key)
                            ? const Color(0xFFDAE2EE)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    onTap: candidates.contains(key) ? () => Navigator.pop(context, key) : null,
                    enabled: candidates.contains(key),
                  ),
                ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() => _triggers[idx] = selected);
    }
  }

  Widget _triggerIcon(String key) {
    final base = Icons.touch_app;
    switch (key) {
      case 'S1_CLICK':
        return const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0x332566EB),
          child: Icon(Icons.looks_one, color: Color(0xFF2566EB)),
        );
      case 'S1_HOLD':
        return const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0x332566EB),
          child: Icon(Icons.front_hand, color: Color(0xFF2566EB)),
        );
      case 'S2_CLICK':
        return const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0x33A855F7),
          child: Icon(Icons.looks_two, color: Color(0xFFA855F7)),
        );
      case 'S2_HOLD':
        return const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0x33A855F7),
          child: Icon(Icons.front_hand, color: Color(0xFFA855F7)),
        );
      default:
        return Icon(base, color: Colors.indigo.shade300);
    }
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    (m ?? ScaffoldMessenger.of(context))
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

/* ───────────── 작은 공용 카드 ───────────── */

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDAE2EE)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B1324),
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.index,
    required this.controller,
    required this.triggerValue,
    required this.triggerLabelMap,
    required this.availableValues,
    required this.allowMultiple,
    required this.selectedInMulti,
    required this.singleSelectedIndex,
    required this.onTriggerTap,
    required this.onRemove,
    required this.onMarkCorrectSingle,
    required this.onToggleCorrectMulti,
  });

  final int index;
  final TextEditingController controller;
  final String? triggerValue;
  final Map<String, String> triggerLabelMap;
  final List<String> availableValues;

  final bool allowMultiple;
  final bool selectedInMulti;
  final int singleSelectedIndex;

  final VoidCallback onTriggerTap;
  final VoidCallback? onRemove;
  final VoidCallback onMarkCorrectSingle;
  final VoidCallback onToggleCorrectMulti;

  @override
  Widget build(BuildContext context) {
    final isCorrect = allowMultiple ? selectedInMulti : (singleSelectedIndex == index);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDAE2EE)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          allowMultiple
              ? Checkbox(
                  value: selectedInMulti,
                  onChanged: (_) => onToggleCorrectMulti(),
                )
              : Radio<int>(
                  value: index,
                  groupValue: singleSelectedIndex,
                  onChanged: (_) => onMarkCorrectSingle(),
                ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Option',
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 트리거 선택 버튼 (투표 페이지 톤 앤 매너)
          OutlinedButton.icon(
            onPressed: onTriggerTap,
            icon: const Icon(Icons.touch_app, size: 18),
            label: Text(
              triggerValue == null ? 'Map button' : (triggerLabelMap[triggerValue] ?? triggerValue!),
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(140, 40),
              side: const BorderSide(color: Color(0xFFDAE2EE)),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0B1324),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onRemove,
          ),
          if (isCorrect)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.check_circle, color: Colors.green, size: 18),
            ),
        ],
      ),
    );
  }
}