import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../provider/hub_provider.dart';

class EditQuestionPage extends StatefulWidget {
  final String hubId;
  final String topicId;
  final String quizId;

  const EditQuestionPage({
    super.key,
    required this.hubId,
    required this.topicId,
    required this.quizId,
  });

  @override
  State<EditQuestionPage> createState() => _EditQuestionPageState();
}

class _EditQuestionPageState extends State<EditQuestionPage> {
  final _titleCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [];
  final List<_Binding> _bindings = [];
  final _newOptionCtrl = TextEditingController();
  final Set<int> _selectedAnswers = {};

  static const int _maxOptions = 4;
  bool _multi = false;
  bool _hovering = false;
  bool _saving = false;

  static const List<_Binding> _allBindings = [
    _Binding(button: 1, gesture: 'single'),
    _Binding(button: 1, gesture: 'hold'),
    _Binding(button: 2, gesture: 'single'),
    _Binding(button: 2, gesture: 'hold'),
  ];

  static const List<_MenuOpt> _menuOpts = [
    _MenuOpt(1, '1 - single', '1-single'),
    _MenuOpt(2, '1 - hold', '1-hold'),
    _MenuOpt(3, '2 - single', '2-single'),
    _MenuOpt(4, '2 - hold', '2-hold'),
  ];

  @override
  void initState() {
    super.initState();
    _loadQuestionData();
  }

  @override
void dispose() {
  _titleCtrl.dispose();
  _newOptionCtrl.dispose();
  for (final c in _optionCtrls) {
    c.dispose();
  }
  super.dispose();
}

  // ───────────── 기존 문항 불러오기 ─────────────
  Future<void> _loadQuestionData() async {
    try {
      final hub = context.read<HubProvider>().hubDocPath;
      final quizDoc = FirebaseFirestore.instance.doc(
        '$hub/quizTopics/${widget.topicId}/quizzes/${widget.quizId}',
      );

      final quizSnap = await quizDoc.get();
      final quizData = quizSnap.data();
      if (quizData == null) return;

      _titleCtrl.text = quizData['question'] ?? '';
      _multi = quizData['multi'] ?? false;
      
final List options = (quizData['options'] as List?) ?? [];
final correctBinding = (quizData['correctBinding'] as Map?) ?? {};

_optionCtrls.clear();
_bindings.clear();
_selectedAnswers.clear();

for (int i = 0; i < options.length; i++) {
  final opt = options[i] as Map<String, dynamic>;
  _optionCtrls.add(TextEditingController(text: opt['title'] ?? ''));
  final binding = (opt['binding'] as Map?) ?? {};
  final b = _Binding(
    button: binding['button'] ?? 1,
    gesture: binding['gesture'] ?? 'single',
  );
  _bindings.add(b);
}

// ✅ 정답 표시
if (correctBinding.isNotEmpty) {
  for (int i = 0; i < _bindings.length; i++) {
    if (_bindings[i].button == correctBinding['button'] &&
        _bindings[i].gesture == correctBinding['gesture']) {
      _selectedAnswers.add(i);
    }
  }
}

      setState(() {});
    } catch (e) {
      debugPrint('Failed to load question data: $e');
    }
  }

  _Binding _parseTrigger(String t) {
  if (t == 'S1_CLICK') return const _Binding(button: 1, gesture: 'single');
  if (t == 'S1_HOLD') return const _Binding(button: 1, gesture: 'hold');
  if (t == 'S2_CLICK') return const _Binding(button: 2, gesture: 'single');
  return const _Binding(button: 2, gesture: 'hold');
}

  // ───────────── 수정 저장 ─────────────
  Future<void> _updateQuestion() async {
    final hub = context.read<HubProvider>().hubDocPath;
    final quizDoc = FirebaseFirestore.instance.doc(
      '$hub/quizTopics/${widget.topicId}/quizzes/${widget.quizId}',
    );

    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a question.')),
      );
      return;
    }

    final titles =
        _optionCtrls
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .take(_maxOptions)
            .toList();

    if (titles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 choices required.')),
      );
      return;
    }

    final choices = _optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
final triggers = _bindings.take(choices.length).map((b) {
  if (b.button == 1 && b.gesture == 'single') return 'S1_CLICK';
  if (b.button == 1 && b.gesture == 'hold') return 'S1_HOLD';
  if (b.button == 2 && b.gesture == 'single') return 'S2_CLICK';
  return 'S2_HOLD';
}).toList();

int? correctIndex;
List<int> correctIndices = [];

if (_multi) {
  correctIndices = _selectedAnswers.toList()..sort();
  correctIndex = correctIndices.isNotEmpty ? correctIndices.first : null;
} else {
  correctIndex = _selectedAnswers.isNotEmpty ? _selectedAnswers.first : null;
}

final options = <Map<String, dynamic>>[];
for (int i = 0; i < _optionCtrls.length; i++) {
  final title = _optionCtrls[i].text.trim();
  if (title.isEmpty) continue;
  options.add({
    'title': title,
    'binding': {
      'button': _bindings[i].button,
      'gesture': _bindings[i].gesture,
    },
  });
}

// ✅ 정답 바인딩 선택 (단일 선택 기준)
_Binding? correct;
if (_selectedAnswers.isNotEmpty) {
  final idx = _selectedAnswers.first;
  if (idx >= 0 && idx < _bindings.length) correct = _bindings[idx];
}

await quizDoc.update({
  'question': _titleCtrl.text.trim(),
  'options': options,
  if (correct != null)
    'correctBinding': {
      'button': correct.button,
      'gesture': correct.gesture,
    }
  else
    'correctBinding': FieldValue.delete(),
  'updatedAt': FieldValue.serverTimestamp(),
});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Question updated!')),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.pop(context);
  }

  // ───────────── 중복 방지 유틸 동일 ─────────────
  _Binding _firstUnusedBinding({_Binding? fallback}) {
    final used = _bindings.map((b) => '${b.button}-${b.gesture}').toSet();
    for (final b in _allBindings) {
      if (!used.contains('${b.button}-${b.gesture}')) return b;
    }
    return fallback ?? const _Binding(button: 1, gesture: 'single');
  }

  void _ensureUniqueAll() {
    final seen = <String>{};
    for (int i = 0; i < _bindings.length; i++) {
      final key = '${_bindings[i].button}-${_bindings[i].gesture}';
      if (seen.contains(key)) {
        _bindings[i] = _firstUnusedBinding(fallback: _bindings[i]);
      }
      seen.add(key);
    }
  }

  void _removeChoice(int i) {
  if (_optionCtrls.length <= 2) return;
  setState(() {
    _optionCtrls.removeAt(i).dispose();
    _bindings.removeAt(i);
  });
}

void _setUniqueBinding(int i, _Binding next) {
  setState(() {
    // ✅ 이미 그 조합을 쓰고 있는 항목이 있는지 찾기
    final dupIndex = _bindings.indexWhere(
      (b) => b.button == next.button && b.gesture == next.gesture,
    );

    if (dupIndex != -1 && dupIndex != i) {
      // ✅ 이미 누군가 쓰고 있다면 swap (서로 교체)
      final tmp = _bindings[i];
      _bindings[i] = next;
      _bindings[dupIndex] = tmp;
    } else {
      // ✅ 중복 아니면 그냥 바꿈
      _bindings[i] = next;
    }
  });
}

  // ───────────── UI 동일 ─────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 950).clamp(0.6, 1.0);
    _ensureUniqueAll();

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF6FAFF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
          color: Colors.black,),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16 * scale, 14 * scale, 16 * scale, 120 * scale),
        children: [
          _sectionTitle('Edit Question', scale),
          SizedBox(height: 8 * scale),
          _questionField(scale),
          SizedBox(height: 24 * scale),
          _sectionTitle('Answer Options', scale),
          SizedBox(height: 8 * scale),
          _optionsCard(scale),
          SizedBox(height: 24 * scale),
          _sectionTitle('Quiz Settings', scale),
          SizedBox(height: 8 * scale),
          _settingsCard(scale),
        ],
      ),
      floatingActionButton: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(right: 24 * scale, bottom: 24 * scale),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: GestureDetector(
              onTap: _saving ? null : _handleSavePressed,
              child: AnimatedScale(
                scale: _hovering ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Opacity(
                  opacity: _saving ? 0.4 : 1.0,
                  child: SizedBox(
                    width: 160 * scale,
                    height: 160 * scale,
                    child: Image.asset(
                      'assets/logo_bird_save.png',
                      fit: BoxFit.contain,
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

  Future<void> _handleSavePressed() async {
    setState(() => _saving = true);
    try {
      await _updateQuestion();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  Widget _questionField(double scale) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(
          width: 948 * scale,
          height: 65 * scale,
        ),
        child: TextField(
          controller: _titleCtrl,
          style: TextStyle(
            color: Color(0xFF001A36),
            fontSize: 24 * scale,
            fontWeight: FontWeight.w500,
            height: 34 / 24,
          ),
          decoration: InputDecoration(
            hintText: 'Please enter your content.',
            hintStyle: TextStyle(
              color: Color(0xFFA2A2A2),
              fontSize: 24 * scale,
              fontWeight: FontWeight.w500,
              height: 34 / 24,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 0,
            ),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD2D2D2), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD2D2D2), width: 1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionsCard(double scale) {
  return Align(
    alignment: Alignment.center,
    child: Container( // ✅ ConstrainedBox 제거
      width: 944 * scale, // ✅ width만 남기고
      // height: 279 * scale,  ❌ 삭제 (고정 높이 제거)
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Color(0xFFD2D2D2), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(32 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // ✅ 추가
          children: [
            for (var i = 0; i < _optionCtrls.length; i++) ...[
              _optionRow(i, scale),
              SizedBox(height: 10 * scale),
            ],
            Padding(
              padding: EdgeInsets.only(top: 8.0 * scale),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 46 * scale),
                  Expanded( // ✅ 고정폭 대신 Expanded로 자동맞춤
                    child: SizedBox(
                      height: 60 * scale,
                      child: TextField(
                        controller: _newOptionCtrl,
                        style: TextStyle(
                          color: Color(0xFFA2A2A2),
                          fontSize: 24 * scale,
                          fontWeight: FontWeight.w500,
                          height: 34 / 24,
                        ),
                        decoration: InputDecoration(
                          // hintText: 'Add a new answer option',
                          // hintStyle: TextStyle(
                          //   color: Color(0xFFA2A2A2),
                          //   fontSize: 24 * scale,
                          //   fontWeight: FontWeight.w500,
                          //   height: 34 / 24,
                          // ),
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
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(32.5),
                            borderSide: const BorderSide(
                              color: Color(0xFFD2D2D2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12 * scale),
                  InkWell(
                    onTap: () {
                      final text = _newOptionCtrl.text.trim();
                      if (text.isNotEmpty &&
                          _optionCtrls.length < _maxOptions) {
                        setState(() {
                          _optionCtrls.add(TextEditingController(text: text));
                          _bindings.add(_firstUnusedBinding());
                          _ensureUniqueAll();
                          _newOptionCtrl.clear();
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(50),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD2D2D2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Color(0xFFBDBDBD),
                        size: 28 * scale,
                      ),
                    ),
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

Widget _optionRow(int i, double scale) {
    final ctrl = _optionCtrls[i];
    final bind = _bindings[i];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (_selectedAnswers.contains(i)) {
                  _selectedAnswers.remove(i);
                } else {
                  if (_multi) {
                    _selectedAnswers.add(i);
                  } else {
                    _selectedAnswers
                      ..clear()
                      ..add(i);
                  }
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    _selectedAnswers.contains(i)
                        ? const Color(0xFFA9E817)
                        : Colors.white,
                border: Border.all(
                  color:
                      _selectedAnswers.contains(i)
                          ? const Color(0xFFA9E817)
                          : const Color(0xFFA2A2A2),
                  width: 1,
                ),
              ),
            ),
          ),
          SizedBox(width: 16 * scale),

          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(
                width: 839 * scale,
                height: 60 * scale,
              ),
              child: TextField(
                controller: ctrl,
                style: TextStyle(
                  color: Color(0xFF001A36),
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.w500,
                  height: 34 / 24,
                ),
                decoration: InputDecoration(
                  hintText: 'Please enter your content.',
                  hintStyle: TextStyle(
                    color: Color(0xFFA2A2A2),
                    fontSize: 24 * scale,
                    fontWeight: FontWeight.w500,
                    height: 34 / 24,
                  ),
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
                  suffixIcon: SizedBox(
                    width: 210 * scale,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${bind.button} - ${bind.gesture}',
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF8D8D8D),
                              fontSize: 21 * scale,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        SizedBox(width: 6 * scale),
                        Theme(
                          data: Theme.of(context).copyWith(
                            popupMenuTheme: PopupMenuThemeData(
                              color: const Color(0xFFF6F6F6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: TextStyle(
                                color: Color(0xFF8D8D8D),
                                fontSize: 21 * scale,
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
                            itemBuilder:
                                (_) => _buildMappingMenuItems(i, bind, scale),
                            onSelected: (v) => _onMappingSelected(v, i),
                          ),
                        ),
                      ],
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 210,
                    maxWidth: 210,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<int>> _buildMappingMenuItems(
    int i,
    _Binding bind,
    double scale,
  ) {
    final usedExceptMe =
        _bindings
            .asMap()
            .entries
            .where((e) => e.key != i)
            .map((e) => '${e.value.button}-${e.value.gesture}')
            .toSet();

    final currentKey = '${bind.button}-${bind.gesture}';
    final items = <PopupMenuEntry<int>>[];

    items.add(
      const PopupMenuItem<int>(
        enabled: false,
        child: Text(
          '— Button mapping —',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF001A36),
          ),
        ),
      ),
    );
    items.add(const PopupMenuDivider());

    for (final o in _menuOpts) {
      final disabled = usedExceptMe.contains(o.key) && o.key != currentKey;
      final selected = (o.key == currentKey);

      items.add(
        PopupMenuItem<int>(
          value: o.value,
          enabled: !disabled,
          height: 44,
          padding: EdgeInsets.symmetric(
            horizontal: 12 * scale,
            vertical: 6 * scale,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F6),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 10 * scale,
              vertical: 8 * scale,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24 * scale,
                  child:
                      selected
                          ? Icon(
                            Icons.check,
                            size: 18 * scale,
                            color: Colors.black87,
                          )
                          : const SizedBox.shrink(),
                ),
                SizedBox(width: 6 * scale),
                Expanded(
                  child: Text(
                    o.label,
                    style: TextStyle(
                      color:
                          disabled
                              ? Colors.grey.shade400
                              : const Color(0xFF8D8D8D),
                      fontSize: 21 * scale,
                      fontWeight: FontWeight.w400,
                      height: 34 / 21,
                      decoration: disabled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    items.add(const PopupMenuDivider());

    final canDelete = _optionCtrls.length > 2;
    items.add(
      PopupMenuItem<int>(
        value: 9,
        enabled: canDelete,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 10 * scale,
            vertical: 8 * scale,
          ),
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 18 * scale,
                color:
                    canDelete ? const Color(0xFF8D8D8D) : Colors.grey.shade400,
              ),
              SizedBox(width: 8 * scale),
              Text(
                '문항 삭제',
                style: TextStyle(
                  color:
                      canDelete
                          ? const Color(0xFF8D8D8D)
                          : Colors.grey.shade400,
                  fontSize: 21 * scale,
                  fontWeight: FontWeight.w400,
                  height: 34 / 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return items;
  }

  void _onMappingSelected(int v, int i) {
    if (v == 9) {
      _removeChoice(i);
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

  Widget _settingsCard(double scale) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(
          width: 945 * scale,
          height: 96 * scale,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFD2D2D2), width: 1),
          ),
          padding: EdgeInsets.symmetric(horizontal: 48 * scale),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Multiple selections',
                style: TextStyle(
                  color: Color(0xFF001A36),
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.w600,
                  height: 46 / 24,
                ),
              ),

              Row(
                children: [
                  _choice('yes', _multi, () {
                    setState(() => _multi = true);
                  }, scale),
                  SizedBox(width: 46 * scale),
                  _choice('no', !_multi, () {
                    setState(() => _multi = false);
                  }, scale),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(
    String label,
    bool selected,
    VoidCallback onTap,
    double scale,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? const Color(0xFFB6F536) : Colors.transparent,
              border: Border.all(
                color:
                    selected
                        ? const Color(0xFFB6F536)
                        : const Color(0xFFCCCCCC),
                width: 2,
              ),
            ),
          ),
          SizedBox(width: 20 * scale),

          Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontSize: 20 * scale,
              fontWeight: FontWeight.w600,
              height: 46 / 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, double scale) {
  return Center(
    child: Container(
      width: 948,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 404 * scale,
        child: Text(
          text, // ✅ 기존 prefix 제거
          style: TextStyle(
            color: Color(0xFF001A36),
            fontSize: 24 * scale,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ),
    ),
  );
}
}

// ───────────── 모델 ─────────────
class _Binding {
  final int button;
  final String gesture;
  const _Binding({required this.button, required this.gesture});
}

class _MenuOpt {
  final int value;
  final String label;
  final String key;
  const _MenuOpt(this.value, this.label, this.key);
}