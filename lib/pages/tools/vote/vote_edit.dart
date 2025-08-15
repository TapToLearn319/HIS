import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'vote_models.dart';

class VoteEditPage extends StatefulWidget {
  final Vote? initial;
  const VoteEditPage({super.key, this.initial});

  @override
  State<VoteEditPage> createState() => _VoteEditPageState();
}

class _VoteEditPageState extends State<VoteEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  VoteType _type = VoteType.binary;

  final List<TextEditingController> _optionCtrls = [];

  _ShowResultMode _showResult = _ShowResultMode.realtime;
  _YesNo _anonymous = _YesNo.yes;
  _YesNo _multiSelect = _YesNo.no;

  static const int _maxOptions = 4;

  @override
  void initState() {
    super.initState();

    _titleCtrl = TextEditingController(text: widget.initial?.title ?? '');
    _type = widget.initial?.type ?? VoteType.binary;

    final options = widget.initial?.options ?? const ['보기 1', '보기 2'];
    for (final o in options) {
      _optionCtrls.add(TextEditingController(text: o));
    }

    if (_type == VoteType.binary) {
      _ensureBinaryOptions();
    } else if (_optionCtrls.length < 2) {
      _optionCtrls
        ..clear()
        ..addAll([
          TextEditingController(text: '보기 1'),
          TextEditingController(text: '보기 2'),
        ]);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureBinaryOptions() {
    for (final c in _optionCtrls) {
      c.dispose();
    }
    _optionCtrls
      ..clear()
      ..addAll([
        TextEditingController(text: '찬성'),
        TextEditingController(text: '반대'),
      ]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<VoteType>(
                segments: const [
                  ButtonSegment(value: VoteType.binary, label: Text('찬반')),
                  ButtonSegment(value: VoteType.multiple, label: Text('문항 선택')),
                ],
                selected: {_type},
                onSelectionChanged: (s) {
                  final selected = s.first;
                  setState(() {
                    _type = selected;
                    if (_type == VoteType.binary) {
                      _ensureBinaryOptions();
                      _multiSelect = _YesNo.no;
                    } else if (_optionCtrls.length < 2) {
                      _optionCtrls
                        ..clear()
                        ..addAll([
                          TextEditingController(text: '보기 1'),
                          TextEditingController(text: '보기 2'),
                        ]);
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            _SectionTitle('Poll Question'),
            const SizedBox(height: 8),
            _roundedField(
              child: TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'Did you understand todays lesson?',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return '질문을 입력하세요.';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 18),

            // Poll Options
            Row(
              children: const [
                _SectionTitle('Poll Options'),
                SizedBox(width: 6),
                Text('*Up to 4', style: TextStyle(color: Colors.black45, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            _OptionsCard(
              optionCtrls: _optionCtrls,
              enabled: _type == VoteType.multiple,
              maxOptions: _maxOptions,
              onAdd: () {
                if (_optionCtrls.length >= _maxOptions) return;
                setState(() {
                  _optionCtrls.add(TextEditingController(text: ''));
                });
              },
              onRemove: (i) {
                if (_optionCtrls.length <= 2) return;
                setState(() {
                  _optionCtrls.removeAt(i).dispose();
                });
              },
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                setState(() {
                  final moved = _optionCtrls.removeAt(oldIndex);
                  _optionCtrls.insert(newIndex, moved);
                });
              },
            ),
            const SizedBox(height: 18),

            // Poll Settings
            _SectionTitle('Poll Settings'),
            const SizedBox(height: 10),
            _SettingsCard(
              showResult: _showResult,
              anonymous: _anonymous,
              multiSelect: _multiSelect,
              isBinary: _type == VoteType.binary,
              onChangeShow: (v) => setState(() => _showResult = v),
              onChangeAnon: (v) => setState(() => _anonymous = v),
              onChangeMulti: (v) => setState(() => _multiSelect = v),
            ),

            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _onSavePressed,
                child: Text(isEdit ? '저장' : '생성'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSavePressed() {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleCtrl.text.trim();

    List<String> options =
        _type == VoteType.binary
            ? const ['찬성', '반대']
            : _optionCtrls
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList();

    final seen = <String>{};
    options = [
      for (final o in options)
        if (seen.add(o)) o,
    ];

    if (_type == VoteType.multiple && options.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('문항은 2개 이상이어야 합니다.')));
      return;
    }
    if (_type == VoteType.multiple && options.length > _maxOptions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('문항은 최대 $_maxOptions개까지 가능합니다.')),
      );
      return;
    }

    Navigator.pop(
      context,
      Vote(
        id:
            widget.initial?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        type: _type,
        options: options,
        status: widget.initial?.status ?? VoteStatus.draft,
      ),
    );
  }

  Widget _roundedField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _TopInfoBar extends StatelessWidget {
  const _TopInfoBar({required this.classLabel});
  final String classLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: Text(
              classLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search Tools',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF3F6FC),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black12.withValues(alpha: 0.06)),
                  borderRadius: BorderRadius.circular(20),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black12.withValues(alpha: 0.06)),
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF8CA8FF)),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    );
  }
}

class _OptionsCard extends StatelessWidget {
  const _OptionsCard({
    required this.optionCtrls,
    required this.enabled,
    required this.maxOptions,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  final List<TextEditingController> optionCtrls;
  final bool enabled;
  final int maxOptions;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFdBE6FF)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: enabled ? onReorder : (_, __) {},
            itemCount: optionCtrls.length,
            itemBuilder: (context, i) {
              final ctrl = optionCtrls[i];
              return Container(
                key: ValueKey(ctrl),
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.drag_indicator, color: Colors.black38),
                    ),

                    Expanded(
                      child: Container(
                        height: 44,
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black12.withValues(alpha: 0.08)),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextFormField(
                          controller: ctrl,
                          enabled: enabled,
                          decoration: InputDecoration(
                            hintText: 'Option ${i + 1}',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) {
                            if (!enabled) return null;
                            if ((v ?? '').trim().isEmpty) return '문항을 입력하세요.';
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MoreMenu(
                      enabled: enabled,
                      onRemove: optionCtrls.length <= 2 ? null : () => onRemove(i),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: (!enabled || optionCtrls.length >= maxOptions) ? null : onAdd,
              icon: const Icon(Icons.add),
              label: const Text('문항 추가'),
            ),
          ),
        ],
      ),
    );

    return card;
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.enabled, this.onRemove});
  final bool enabled;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'More',
      enabled: enabled,
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          value: 1,
          enabled: onRemove != null,
          child: const Text('문항 삭제'),
          onTap: () => Future.microtask(() => onRemove?.call()),
        ),
      ],
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Icon(Icons.more_horiz),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.showResult,
    required this.anonymous,
    required this.multiSelect,
    required this.isBinary,
    required this.onChangeShow,
    required this.onChangeAnon,
    required this.onChangeMulti,
  });

  final _ShowResultMode showResult;
  final _YesNo anonymous;
  final _YesNo multiSelect;
  final bool isBinary;
  final ValueChanged<_ShowResultMode> onChangeShow;
  final ValueChanged<_YesNo> onChangeAnon;
  final ValueChanged<_YesNo> onChangeMulti;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBE6FF)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          _settingRow(
            title: 'Show results',
            left: _RadioPill<_ShowResultMode>(
              group: showResult,
              value: _ShowResultMode.realtime,
              label: 'in real time',
              onChanged: (v) => onChangeShow(v!),
            ),
            right: _RadioPill<_ShowResultMode>(
              group: showResult,
              value: _ShowResultMode.afterEnd,
              label: 'After voting ends',
              onChanged: (v) => onChangeShow(v!),
            ),
          ),
          const SizedBox(height: 10),
          _settingRow(
            title: 'Anonymous',
            left: _RadioPill<_YesNo>(
              group: anonymous,
              value: _YesNo.yes,
              label: 'yes',
              onChanged: (v) => onChangeAnon(v!),
            ),
            right: _RadioPill<_YesNo>(
              group: anonymous,
              value: _YesNo.no,
              label: 'no',
              onChanged: (v) => onChangeAnon(v!),
            ),
          ),
          const SizedBox(height: 10),
          _settingRow(
            title: 'Multiple selections',
            left: _RadioPill<_YesNo>(
              group: isBinary ? _YesNo.no : multiSelect,
              value: _YesNo.yes,
              label: 'yes',
              onChanged: isBinary ? null : (v) => onChangeMulti(v!),
            ),
            right: _RadioPill<_YesNo>(
              group: isBinary ? _YesNo.no : multiSelect,
              value: _YesNo.no,
              label: 'no',
              onChanged: isBinary ? null : (v) => onChangeMulti(v!),
            ),
          ),
          if (isBinary)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('※ 찬반 투표에서는 다중 선택을 사용할 수 없습니다.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ),
        ],
      ),
    );
    return card;
  }

  Widget _settingRow({
    required String title,
    required Widget left,
    required Widget right,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Row(children: [left, const SizedBox(width: 16), right]),
      ],
    );
  }
}

class _RadioPill<T> extends StatelessWidget {
  const _RadioPill({
    required this.group,
    required this.value,
    required this.label,
    this.onChanged,
  });

  final T group;
  final T value;
  final String label;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = group == value;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onChanged == null ? null : () => onChanged!(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<T>(value: value, groupValue: group, onChanged: onChanged),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFE483) : const Color(0xFFFFF3B8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

enum _ShowResultMode { realtime, afterEnd }
enum _YesNo { yes, no }