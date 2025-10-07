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

class _RandomSeatCreatePageState extends State<RandomSeatCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController(text: '');
  final _colsCtrl  = TextEditingController(text: '7');
  final _rowsCtrl  = TextEditingController(text: '3');
  final _separateCtrl = TextEditingController(); // ex) 1-2, 5-7
  final _pairCtrl     = TextEditingController(); // ex) 1-2, 5-7

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
    super.dispose();
  }

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

      final ref = FirebaseFirestore.instance
          .collection('hubs/$hubId/randomSeatFiles')
          .doc();

      await ref.set({
        'title': (_titleCtrl.text.trim().isEmpty)
            ? 'Untitled'
            : _titleCtrl.text.trim(),
        'type': _type,                        // 'individual' | 'group'
        'genderEquity': _genderEquity,        // bool
        'cols': cols,
        'rows': rows,
        'total': computedTotal,               // cols*rows 기준 저장
        'constraints': {
          'separation': _separateCtrl.text.trim(),
          'pairing': _pairCtrl.text.trim(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('랜덤 시팅 파일이 생성되었습니다.')),
      );

      // 생성 후: 파일 선택 페이지로 이동
      Navigator.pushReplacementNamed(context, '/random-seat/files');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      selectedIndex: 1,
      body: Scaffold(
        backgroundColor: _kAppBg,
        appBar: AppBar(
          backgroundColor: _kAppBg,
          elevation: 0.5,
          automaticallyImplyLeading: false,
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

                  // 전체 폼 래퍼(빛청색 배경 느낌)
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
                          const SizedBox(height: 20),

                          _sectionLabel(
                            'Seperation   *Write student’s number to not pair together',
                          ),
                          const SizedBox(height: 6),
                          _pillInput(_separateCtrl, hint: 'ex) Mark-Anna'),
                          const SizedBox(height: 20),

                          _sectionLabel(
                            'Pairing   *Write student’s number to pair together',
                          ),
                          const SizedBox(height: 6),
                          _pillInput(_pairCtrl, hint: 'ex) 1-2, 5-7'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 우상단 NEXT(피그마 새 캐릭터 버튼)
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

  /* ===================== Widgets ===================== */

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
                colorDot: null,
                value: 'individual',
                group: _type,
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(width: 22),
              _radioWithLabel(
                label: 'group',
                colorDot: null,
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
    Color? colorDot,
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
          if (colorDot != null)
            Container(
              width: 10, height: 10,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: colorDot, shape: BoxShape.circle,
              ),
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
        items: items
            .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
            .toList(),
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

  Widget _pillInput(TextEditingController ctrl, {String? hint}) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint ?? 'ex) Mark-Anna',
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kCardBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kCardBorder, width: 1),
          ),
        ),
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
class _NextFabImage extends StatelessWidget {
  final VoidCallback onTap;
  final bool enabled;
  const _NextFabImage({Key? key, required this.onTap, this.enabled = true}) : super(key: key);

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
                    // 👉 네가 쓰는 NEXT 자산 경로로 맞춰줘
                    'assets/test/logo_bird_next.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.arrow_forward, size: 64),
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