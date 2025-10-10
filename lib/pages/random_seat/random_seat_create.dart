import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../sidebar_menu.dart';
import '../../provider/hub_provider.dart';

const _kAppBg = Color(0xFFF6FAFF);
const _kCardBorder = Color(0xFFD2D2D2);

class RandomSeatCreatePage extends StatefulWidget {
  const RandomSeatCreatePage({super.key});

  @override
  State<RandomSeatCreatePage> createState() => _RandomSeatCreatePageState();
}

// ─────────────────────────────────────────────────────────────────────────────
// 규칙 그룹 모델
// ─────────────────────────────────────────────────────────────────────────────
class _RuleGroup {
  _RuleGroup({required this.type}) : addCtrl = TextEditingController();
  final String type; // 'pair'(같이) | 'separate'(떼기)
  final TextEditingController addCtrl;
  final List<String> members = [];
  void dispose() => addCtrl.dispose();
}

class _RandomSeatCreatePageState extends State<RandomSeatCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController(text: '');
  final _colsCtrl  = TextEditingController(text: '7');
  final _rowsCtrl  = TextEditingController(text: '3');

  // (하위호환용 컨트롤러는 유지만 하고 UI엔 노출하지 않음)
  final _separateCtrl = TextEditingController(); // ex) 1-2, 5-7
  final _pairCtrl     = TextEditingController(); // ex) 1-2, 5-7

  // 새 규칙 그룹 UI용 상태 (페이지 수명에 종속)
  final List<_RuleGroup> _pairGroups = [];      // 같이 앉히기 그룹들
  final List<_RuleGroup> _separateGroups = [];  // 떨어뜨리기 그룹들

  String _type = 'group';       // 'individual' | 'group'
  bool _genderEquity = true;    // 체크박스
  int _total = 12;              // 드롭다운 표시값(피그마)

  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _colsCtrl.dispose();
    _rowsCtrl.dispose();
    _separateCtrl.dispose();
    _pairCtrl.dispose();
    for (final g in _pairGroups) g.dispose();
    for (final g in _separateGroups) g.dispose();
    super.dispose();
  }

  // ── 규칙 그룹 조작 ─────────────────────────────────────────────────────────
  void _addRuleGroup({required bool together}) {
    setState(() {
      (together ? _pairGroups : _separateGroups)
          .add(_RuleGroup(type: together ? 'pair' : 'separate'));
    });
  }

  void _addMember(_RuleGroup g, String name) {
    final t = name.trim();
    if (t.isEmpty) return;
    if (!g.members.contains(t)) {
      setState(() => g.members.add(t));
    }
    g.addCtrl.clear();
  }

  void _removeMember(_RuleGroup g, String name) {
    setState(() => g.members.remove(name));
  }

  void _deleteGroup(_RuleGroup g) {
    setState(() {
      g.dispose();
      (g.type == 'pair' ? _pairGroups : _separateGroups).remove(g);
    });
  }

  List<Map<String, dynamic>> _serializeGroups(List<_RuleGroup> src) {
    return src
        .map((g) {
          final members = g.members
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          return {'members': members};
        })
        // 2명 이상만 저장(1명이면 규칙 의미 없음)
        .where((e) => (e['members'] as List).length >= 2)
        .toList();
  }

  // 학생 팝업 열기 → 선택된 이름들 반환 받아 그룹에 반영
  Future<void> _pickStudentsForGroup(_RuleGroup group) async {
    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null || hubId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('허브가 설정되지 않았습니다.')),
      );
      return;
    }

    final picked = await showDialog<List<String>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54, // 배경 흐리게
      builder: (_) => _StudentMultiPickerDialog(hubId: hubId, initiallySelected: group.members.toSet()),
    );

    if (picked == null) return; // 취소/닫기
    if (picked.isEmpty) return;

    setState(() {
      // 기존 + 신규(중복 제거)
      final setAll = {...group.members, ...picked};
      group.members
        ..clear()
        ..addAll(setAll);
    });
  }

  // ── 저장 ───────────────────────────────────────────────────────────────────
  Future<void> _create() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    final hubId = context.read<HubProvider>().hubId;
    if (hubId == null || hubId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('허브가 설정되지 않았습니다.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final cols = int.tryParse(_colsCtrl.text.trim()) ?? 0;
      final rows = int.tryParse(_rowsCtrl.text.trim()) ?? 0;
      final computedTotal = (cols > 0 && rows > 0) ? cols * rows : _total;

      // 규칙 그룹 직렬화 (빈 값/1명 그룹 제외)
      final pairingGroups = _serializeGroups(_pairGroups);
      final separationGroups = _serializeGroups(_separateGroups);

      final ref = FirebaseFirestore.instance
          .collection('hubs/$hubId/randomSeatFiles')
          .doc();

      await ref.set({
        'title': (_titleCtrl.text.trim().isEmpty)
            ? 'Untitled'
            : _titleCtrl.text.trim(),
        'type': _type,
        'genderEquity': _genderEquity,
        'cols': cols,
        'rows': rows,
        'total': computedTotal,
        'constraints': {
          // ✅ 배열 안에 Map 구조로 저장 (Firestore OK)
          'pairingGroups': pairingGroups,         // [{members: ['A','B']}, ...]
          'separationGroups': separationGroups,   // [{members: ['X','Y','Z']}, ...]

          // (선택) 하위호환용 문자열도 유지
          'pairing': _pairCtrl.text.trim(),
          'separation': _separateCtrl.text.trim(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

       await FirebaseFirestore.instance
        .doc('hubs/$hubId')
        .set({'randomSeat': {'activeFileId': ref.id}}, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('랜덤 시팅 파일이 생성되었습니다.')),
      );

      // 생성 후: 파일 선택 페이지로 이동
      Navigator.pushReplacementNamed(
      context,
      '/tools/random_seat/detail',   // 앱에 등록된 라우트 키와 동일하게
      arguments: {'fileId': ref.id},
    );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      selectedIndex: 1,
      body: Scaffold(
        backgroundColor: _kAppBg,
        appBar: AppBar(
          backgroundColor: _kAppBg,
          elevation: 0.5,
          automaticallyImplyLeading: false, // 기본 leading 막고 커스텀 버튼 사용
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 160),
                children: [
                  // 페이지 타이틀
                  _pageTitle('Seating Settings'),
                  const SizedBox(height: 16),

                  // 전체 폼 래퍼
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Title'),
                          const SizedBox(height: 6),
                          _titleField(),
                          const SizedBox(height: 20),

                          _sectionLabel('Type'),
                          const SizedBox(height: 6),
                          _typeCard(),
                          const SizedBox(height: 20),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Total
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sectionLabel('Total'),
                                    const SizedBox(height: 6),
                                    _totalDropdown(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Column / Row
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sectionLabel('Column / Row'),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(child: _numberField(_colsCtrl)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _numberField(_rowsCtrl)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ── 새 규칙 섹션: 같이 앉히기 ─────────────────────────
                          _ruleGroupsSection(
                            title: 'Pairing groups (sit together)',
                            help: 'Add group → Add students 에서 학생을 선택하세요.',
                            groups: _pairGroups,
                            together: true,
                          ),
                          const SizedBox(height: 20),

                          // ── 새 규칙 섹션: 떨어뜨리기 ────────────────────────
                          _ruleGroupsSection(
                            title: 'Separation groups (do not sit together)',
                            help: '같은 그룹의 학생들은 서로 인접하지 않게 배치됩니다.',
                            groups: _separateGroups,
                            together: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 우하단 NEXT 캐릭터 버튼
            _NextFabImage(
              onTap: _create,
              enabled: !_busy,
            ),

            if (_busy)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 섹션/카드 빌더들 ─────────────────────────────────────────────────────────
  Widget _ruleGroupsSection({
    required String title,
    required String help,
    required List<_RuleGroup> groups,
    required bool together,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kCardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF001A36),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _addRuleGroup(together: together),
                icon: const Icon(Icons.group_add, size: 18),
                label: const Text('Add group'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: _kCardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            help,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // 그룹 카드들
          if (groups.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                '아직 생성된 그룹이 없어요.  오른쪽 위 [Add group]을 눌러 그룹을 추가하세요.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                const gap = 12.0;
                const cols = 3; // 한 줄에 3개
                final maxW = box.maxWidth;
                final cardW = (maxW - gap * (cols - 1)) / cols; // 3등분한 카드 폭

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (int i = 0; i < groups.length; i++)
                      SizedBox(
                        width: cardW, // ← 카드 폭 고정
                        child: _ruleGroupCard(groups[i], index: i + 1),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _ruleGroupCard(_RuleGroup g, {required int index}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 440),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 (타입/인덱스 + 삭제)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: g.type == 'pair'
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${g.type == "pair" ? "Pair" : "Separate"} $index',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: g.type == 'pair'
                          ? const Color(0xFF1F2937)
                          : const Color(0xFF991B1B),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete group',
                  onPressed: () => _deleteGroup(g),
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ✨ 텍스트 입력 대신 "Add students" 버튼만 노출 → 팝업에서 선택
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickStudentsForGroup(g),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Add students'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: _kCardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 현재 구성원
            if (g.members.isEmpty)
              const Text(
                'No students yet.',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in g.members)
                    _memberChip(
                      name: name,
                      onDelete: () => _removeMember(g, name),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _memberChip({required String name, required VoidCallback onDelete}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  // ── 공통 폼 위젯들 ───────────────────────────────────────────────────────────
  Widget _pageTitle(String text) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF001A36),
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF001A36),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _titleField() {
    return TextFormField(
      controller: _titleCtrl,
      decoration: _inputDecoration(
        hint: 'Enter a Title',
        radius: 10,
      ),
      style: const TextStyle(
        color: Color(0xFF001A36),
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      validator: (v) =>
          (v ?? '').trim().isEmpty ? 'Please enter a title.' : null,
    );
  }

  Widget _typeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kCardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Column(
        children: [
          // individual / group
          Row(
            children: [
              _radioWithLabel(
                label: 'indivisual',
                value: 'individual',
                group: _type,
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(width: 22),
              _radioWithLabel(
                label: 'group',
                value: 'group',
                group: _type,
                onChanged: (v) => setState(() => _type = v!),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // gender equity
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _genderEquity = !_genderEquity),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _genderEquity,
                    onChanged: (v) => setState(() => _genderEquity = v ?? false),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: const BorderSide(color: Color(0xFFD2D2D2)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'gender equity',
                    style: TextStyle(
                      color: Color(0xFF001A36),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _radioWithLabel({
    required String label,
    required String value,
    required String group,
    required ValueChanged<String?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: group,
            onChanged: onChanged,
            activeColor: Colors.black,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF001A36),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalDropdown() {
    const items = <int>[8, 10, 12, 14, 16, 20, 24, 28, 30, 32];
    return SizedBox(
      height: 48,
      child: DropdownButtonFormField<int>(
        value: _total,
        items: items.map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
        onChanged: (v) => setState(() => _total = v ?? _total),
        decoration: _inputDecoration(radius: 8),
      ),
    );
  }

  Widget _numberField(TextEditingController ctrl) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: _inputDecoration(radius: 8),
        validator: (v) {
          final n = int.tryParse((v ?? '').trim());
          if (n == null || n <= 0) return 'Enter number';
          if (n > 24) return 'Too large';
          return null;
        },
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, double radius = 10}) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: _kCardBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: _kCardBorder, width: 1),
      ),
    );
  }
}

// 우하단 NEXT 캐릭터 버튼 (Start와 동일 사이즈/스타일)
class _NextFabImage extends StatelessWidget {
  final VoidCallback onTap;
  final bool enabled;
  const _NextFabImage({Key? key, required this.onTap, this.enabled = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: SafeArea(
        top: false,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: SizedBox(
            width: 200,
            height: 200,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                hoverColor: Colors.black.withOpacity(0.05),
                splashColor: Colors.black.withOpacity(0.1),
                onTap: enabled ? onTap : null,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Image.asset(
                    'assets/test/logo_bird_next.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.arrow_forward, size: 64),
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

/// ─────────────────────────────────────────────────────────────────────────
/// 학생 다중 선택 팝업
/// ─────────────────────────────────────────────────────────────────────────
class _StudentMultiPickerDialog extends StatefulWidget {
  const _StudentMultiPickerDialog({
    required this.hubId,
    this.initiallySelected = const {},
  });

  final String hubId;
  final Set<String> initiallySelected;

  @override
  State<_StudentMultiPickerDialog> createState() => _StudentMultiPickerDialogState();
}

class _StudentMultiPickerDialogState extends State<_StudentMultiPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late Set<String> _selected;

  static const _kText = TextStyle(color: Colors.black);
  static const _kTextBold = TextStyle(color: Colors.black, fontWeight: FontWeight.w800);
  static const _kMuteds = TextStyle(color: Colors.black, fontWeight: FontWeight.w600);

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initiallySelected};
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final stream = fs
        .collection('hubs/${widget.hubId}/students')
        .orderBy('name')
        .snapshots();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const Text('Select students', style: _kTextBold),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.black),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // 검색창
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                style: _kText,
                decoration: InputDecoration(
                  hintText: 'Search name',
                  hintStyle: _kText.copyWith(color: Colors.black54),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, color: Colors.black),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kCardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kCardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kCardBorder),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  fillColor: const Color(0xFFF9FAFB),
                  filled: true,
                ),
              ),
            ),

            // 리스트
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? const [];
                  final names = <String>[
                    for (final d in docs) ((d.data()['name'] ?? d.id).toString().trim())
                  ].where((n) => n.isNotEmpty).toList();

                  final q = _searchCtrl.text.trim().toLowerCase();
                  final filtered = q.isEmpty
                      ? names
                      : names.where((n) => n.toLowerCase().contains(q)).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('검색 결과가 없습니다.', style: _kText),
                    );
                  }

                  // 내부 setState용(검색창 입력시 전체 리빌드 방지)
                  return StatefulBuilder(
                    builder: (context, setSB) => Column(
                      children: [
                        // 전체 선택/해제
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  setSB(() => _selected.addAll(filtered));
                                },
                                icon: const Icon(Icons.done_all, color: Colors.black),
                                label: const Text('Select all on this page', style: _kText),
                                style: TextButton.styleFrom(foregroundColor: Colors.black),
                              ),
                              const SizedBox(width: 10),
                              TextButton.icon(
                                onPressed: () {
                                  setSB(() => _selected.removeWhere((e) => filtered.contains(e)));
                                },
                                icon: const Icon(Icons.remove_done, color: Colors.black),
                                label: const Text('Clear all on this page', style: _kText),
                                style: TextButton.styleFrom(foregroundColor: Colors.black),
                              ),
                              const Spacer(),
                              Text('${_selected.length} selected', style: _kMuteds),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                        // ✅ 2열 그리드
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 10,
                              mainAxisExtent: 44, // 한 셀의 세로 높이
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final name = filtered[i];
                              final checked = _selected.contains(name);

                              return _NameCheckTile(
                                name: name,
                                checked: checked,
                                onChanged: (v) {
                                  setSB(() {
                                    if (v) {
                                      _selected.add(name);
                                    } else {
                                      _selected.remove(name);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 하단 버튼
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: _kText),
                    style: TextButton.styleFrom(foregroundColor: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, _selected.toList()),
                    icon: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.white),
                    label: const Text('Add', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF46A5FF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2열 그리드용 체크 타일(검정 폰트)
class _NameCheckTile extends StatelessWidget {
  const _NameCheckTile({
    required this.name,
    required this.checked,
    required this.onChanged,
  });

  final String name;
  final bool checked;
  final ValueChanged<bool> onChanged;

  static const _kText = TextStyle(color: Colors.black, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: Colors.black,
              checkColor: Colors.white,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _kText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}