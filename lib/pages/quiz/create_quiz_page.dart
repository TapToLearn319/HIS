// lib/pages/quiz/create_quiz_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/hub_provider.dart';

class CreateQuizPage extends StatefulWidget {
  const CreateQuizPage({super.key, required this.topicId, required this.fs});
  final String topicId;
  final FirebaseFirestore fs;

  @override
  State<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends State<CreateQuizPage> {
  final TextEditingController _qCtrl = TextEditingController();
  final List<TextEditingController> _choiceCtrls = <TextEditingController>[
    TextEditingController(),
    TextEditingController()
  ];
  final List<String?> _triggerKeys = <String?>['S1_CLICK', 'S2_CLICK'];

  bool _allowMultiple = false;
  bool _anonymous = false;
  String _showMode = 'realtime'; // 'realtime' | 'after'

  int _correctIndex = 0; // 단일정답
  final Set<int> _correctSet = {0}; // 복수정답

  static const Map<String, String> _kTriggerOptions = <String, String>{
    'S1_CLICK': '1 • click',
    'S1_HOLD': '1 • hold',
    'S2_CLICK': '2 • click',
    'S2_HOLD': '2 • hold',
  };

  @override
  void dispose() {
    _qCtrl.dispose();
    for (final c in _choiceCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureTriggerLength() {
    while (_triggerKeys.length < _choiceCtrls.length) {
      final opts = _kTriggerOptions.keys.toList();
      final used = _triggerKeys.whereType<String>().toSet();
      final firstFree =
          opts.firstWhere((k) => !used.contains(k), orElse: () => opts.first);
      _triggerKeys.add(firstFree);
    }
    while (_triggerKeys.length > _choiceCtrls.length) {
      _triggerKeys.removeLast();
    }
  }

  List<String> _availableForIndex(int idx) {
    final used = _triggerKeys.toList()..removeAt(idx);
    return _kTriggerOptions.keys.where((k) => !used.contains(k)).toList();
  }

  void _addChoice() {
    if (_choiceCtrls.length >= 4) return;
    setState(() {
      _choiceCtrls.add(TextEditingController());
      _ensureTriggerLength();
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
      _ensureTriggerLength();
      if (_allowMultiple) {
        _correctSet.remove(idx);
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
    final q = _qCtrl.text.trim();
    final choices =
        _choiceCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (q.isEmpty || choices.length < 2) {
      _snack(context, '문제와 최소 2개의 선택지를 입력하세요.');
      return;
    }
    if (_triggerKeys.length != choices.length || _triggerKeys.any((k) => k == null)) {
      _snack(context, '모든 선택지에 트리거를 지정하세요.');
      return;
    }
    final used = <String>{};
    for (final k in _triggerKeys.whereType<String>()) {
      if (!used.add(k)) {
        _snack(context, '트리거가 중복되었습니다: $k');
        return;
      }
    }

    List<int> correctIndices = const [];
    int? correctIndex;

    if (_allowMultiple) {
      correctIndices =
          _correctSet.where((i) => i >= 0 && i < choices.length).toList()..sort();
      if (correctIndices.isEmpty) {
        _snack(context, '복수정답 모드에서는 최소 1개 이상 정답을 선택하세요.');
        return;
      }
      correctIndex = correctIndices.first; // 보기용 대표 인덱스
    } else {
      if (_correctIndex < 0 || _correctIndex >= choices.length) {
        _snack(context, '정답 인덱스가 올바르지 않습니다.');
        return;
      }
      correctIndex = _correctIndex;
    }

    // 허브 경로 확인
    final hubPath = context.read<HubProvider>().hubDocPath; // hubs/{hubId}
    if (hubPath == null) {
      _snack(context, '허브를 먼저 선택하세요.');
      return;
    }

    // ✅ add()에서는 FieldValue.delete() 사용하지 않음
    final data = <String, dynamic>{
      'question': q,
      'choices': choices,
      'triggers': _triggerKeys.whereType<String>().toList(),
      'anonymous': _anonymous,
      'allowMultiple': _allowMultiple,
      'showMode': _showMode, // 'realtime' | 'after'
      'correctIndex': correctIndex,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (_allowMultiple) {
      data['correctIndices'] = correctIndices;
    }

    await widget.fs
        .collection('$hubPath/quizTopics/${widget.topicId}/quizzes')
        .add(data);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    _ensureTriggerLength();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 246, 250, 255),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text('Create quiz'),
      ),
      body: Stack(
        children: [
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.8,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionCard(
                      title: 'Quiz question',
                      child: TextField(
                        controller: _qCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Did you understand today’s lesson?',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Answer Options   ·  up to 4',
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
                                  bottom: i == _choiceCtrls.length - 1 ? 0 : 10),
                              child: _OptionRow(
                                index: i,
                                controller: _choiceCtrls[i],
                                triggerValue: _triggerKeys[i],
                                triggerLabelMap: _kTriggerOptions,
                                availableValues: _availableForIndex(i),
                                allowMultiple: _allowMultiple,
                                selectedInMulti: _correctSet.contains(i),
                                singleSelectedIndex: _correctIndex,
                                onTriggerChanged: (v) =>
                                    setState(() => _triggerKeys[i] = v),
                                onRemove: _choiceCtrls.length <= 2
                                    ? null
                                    : () => _removeChoice(i),
                                onMarkCorrectSingle: () =>
                                    setState(() => _correctIndex = i),
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
                      title: 'Quiz Settings',
                      child: Column(
                        children: [
                          _SettingRow(
                            label: 'Show results',
                            leading: const Text('in real time'),
                            trailing: const Text('After voting ends'),
                            valueLeft: _showMode == 'realtime',
                            onChanged: (left) =>
                                setState(() => _showMode = left ? 'realtime' : 'after'),
                          ),
                          const SizedBox(height: 8),
                          _SettingRow(
                            label: 'Anonymous',
                            leading: const Text('yes'),
                            trailing: const Text('no'),
                            valueLeft: _anonymous,
                            onChanged: (left) => setState(() => _anonymous = left),
                          ),
                          const SizedBox(height: 8),
                          _SettingRow(
                            label: 'Multiple selections',
                            leading: const Text('yes'),
                            trailing: const Text('no'),
                            valueLeft: _allowMultiple,
                            onChanged: (left) {
                              setState(() {
                                _allowMultiple = left;
                                if (_allowMultiple) {
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 둥둥 저장 버튼
          _SaveQuizFabImage(onTap: _save),
        ],
      ),
    );
  }
}

// ───────────────────────── Floating Save FAB (image) ─────────────────────────

class _SaveQuizFabImage extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveQuizFabImage({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: 200,
          height: 200,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              hoverColor: Colors.black.withOpacity(0.05),
              splashColor: Colors.black.withOpacity(0.1),
              onTap: onTap,
              child: Tooltip(
                message: 'Save quiz',
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Image.asset(
                    'assets/logo_bird_save.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.save_alt,
                      size: 64,
                      color: Colors.indigo,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Pretty sections / rows ─────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

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
    required this.onTriggerChanged,
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

  final ValueChanged<String?> onTriggerChanged;
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
              ? Checkbox(value: selectedInMulti, onChanged: (_) => onToggleCorrectMulti())
              : Radio<int>(value: index, groupValue: singleSelectedIndex, onChanged: (_) => onMarkCorrectSingle()),
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
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120, maxWidth: 150),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: triggerValue,
                items: availableValues
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(triggerLabelMap[k] ?? k),
                      ),
                    )
                    .toList()
                  ..sort((a, b) => (a.child as Text).data!.compareTo((b.child as Text).data!)),
                onChanged: onTriggerChanged,
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.more_vert, color: Colors.grey),
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.leading,
    required this.trailing,
    required this.valueLeft,
    required this.onChanged,
  });

  final String label;
  final Widget leading;
  final Widget trailing;
  final bool valueLeft; // true면 왼쪽 옵션
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDAE2EE)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Row(
            children: [
              _DotRadio(
                selected: valueLeft,
                onTap: () => onChanged(true),
                child: leading,
              ),
              const SizedBox(width: 14),
              _DotRadio(
                selected: !valueLeft,
                onTap: () => onChanged(false),
                child: trailing,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DotRadio extends StatelessWidget {
  const _DotRadio({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
      ),
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 8),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2563EB),
              ),
            )
          : const SizedBox.shrink(),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Row(
        children: [
          dot,
          DefaultTextStyle.merge(
            style: TextStyle(color: selected ? const Color(0xFF0B1324) : const Color(0xFF6B7280)),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Local utils ─────────────────────────

void _snack(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  (m ?? ScaffoldMessenger.of(context))
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
